# 06. Kiến trúc `chat-service` (`com.animallocket.chat`)

`chat-service` (`:8105`, MongoDB + Redis Pub/Sub + WebSocket) đảm nhiệm:
- Hội thoại 1-1 giữa bạn bè (`Conversation`) và lưu trữ tin nhắn văn bản/hình ảnh (`Message`) trên MongoDB.
- Xác minh quan hệ bạn bè (`friends && !blocked`) qua `user-service` (cache Redis 30s) và kiểm tra ảnh đính kèm (`context=CHAT && status=READY && cùng chủ`) qua `media-service`.
- Giao tiếp thời gian thực hai chiều qua WebSocket (`/ws/chat`) hỗ trợ nhiều thiết bị và mở rộng ngang nhiều instance nhờ `RedisMessageBus` (`PSUBSCRIBE chat:user:*`) và `SessionRegistry`.
- Chỉ phát sự kiện `MESSAGE_SENT` lên Kafka để gửi thông báo đẩy (FCM Push) khi người nhận **không có phiên WebSocket nào đang mở** (`chat:conn:{recipient}` rỗng).

---

## 1. Class Diagram (`chat-service`)

```mermaid
classDiagram
    direction TB

    %% ==========================================
    %% Domain Documents & Repositories (MongoDB)
    %% ==========================================
    class Conversation {
        <<@Document conversations>>
        -String id
        -String key
        -List~String~ participants
        -Status status
        -String closedReason
        -Instant createdAt
        -Instant lastMessageAt
        -Map~String, Instant~ lastReadAt
        +keyOf(String a, String b)$ String
        +other(String me) String
        +has(String id) boolean
    }
    note for Conversation "Tài liệu hội thoại 1-1.\nKhoá duy nhất key = 'minId:maxId'.\nStatus: ACTIVE | CLOSED (khi BLOCKED, UNFRIENDED, DELETED)."

    class Message {
        <<@Document messages>>
        -String id
        -String conversationId
        -String senderId
        -Type type
        -String text
        -String mediaId
        -Instant createdAt
    }
    note for Message "Tin nhắn thuộc hội thoại (Type: TEXT | IMAGE).\nĐánh compound index {'conversationId': 1, 'createdAt': -1}."

    class ConversationRepository {
        <<interface>>
        +findByKey(String key) Optional~Conversation~
        +findByParticipantsOrderByLastMessageAtDesc(String participant) List~Conversation~
    }

    class MessageRepository {
        <<interface>>
        +findByConversationIdAndCreatedAtLessThanOrderByCreatedAtDesc(String convId, Instant before, Pageable page) List~Message~
        +countByConversationIdAndSenderIdNotAndCreatedAtGreaterThan(String convId, String notSender, Instant after) long
        +deleteByConversationId(String conversationId) void
    }

    %% ==========================================
    %% Pub/Sub Message Bus & WebSocket Layer
    %% ==========================================
    class MessageBus {
        <<interface>>
        +publish(String publicId, String json) void
        +subscribe(BiConsumer~String, String~ deliverLocally) void
    }
    note for MessageBus "Bus phát thông điệp realtime tới mọi instance chat-service."

    class RedisMessageBus {
        -StringRedisTemplate redis
        -RedisMessageListenerContainer container
        +publish(String publicId, String json) void
        +subscribe(BiConsumer~String, String~ deliverLocally) void
    }
    note for RedisMessageBus "PUBLISH lên kênh chat:user:{publicId} và PSUBSCRIBE chat:user:*\nđể chuyển khung JSON tới phiên WebSocket cục bộ."

    class LocalMessageBus {
        -BiConsumer~String, String~ handler
        +publish(String publicId, String json) void
        +subscribe(BiConsumer~String, String~ deliverLocally) void
    }

    class PublicIdHandshakeInterceptor {
        +beforeHandshake(ServerHttpRequest req, ServerHttpResponse res, WebSocketHandler wsHandler, Map attributes) boolean
        +afterHandshake(...) void
    }
    note for PublicIdHandshakeInterceptor "Kiểm tra header X-Public-Id do Gateway gắn ngay lúc bắt tay WebSocket.\nNếu thiếu -> từ chối 403 FORBIDDEN."

    class SessionRegistry {
        -Map~String, Set~WebSocketSession~~ sessions
        -KeyValueStore kv
        +add(String publicId, WebSocketSession raw) WebSocketSession
        +remove(String publicId, WebSocketSession s) void
        +touch(String publicId) void
        +isConnectedAnywhere(String publicId) boolean
        +deliver(String publicId, String json) void
        +localSessionCount() int
    }
    note for SessionRegistry "Quản lý các phiên WebSocket trên instance hiện tại (bọc ConcurrentWebSocketSessionDecorator)\nvà duy trì khoá Redis chat:conn:{publicId} (TTL 90s)."

    class ChatWebSocketHandler {
        -SessionRegistry registry
        -ChatService chat
        +afterConnectionEstablished(WebSocketSession session) void
        #handleTextMessage(WebSocketSession session, TextMessage message) void
        +afterConnectionClosed(WebSocketSession session, CloseStatus status) void
    }
    note for ChatWebSocketHandler "Xử lý các khung lệnh WebSocket từ client: ping, read, send.\nĐóng kết nối nếu khung > 16KB."

    %% ==========================================
    %% Gateways, Service, Listener & Controller
    %% ==========================================
    class UserGateway {
        <<interface Gateways.UserGateway>>
        +relationship(String a, String b) Relationship
    }

    class MediaGateway {
        <<interface Gateways.MediaGateway>>
        +media(String mediaId) MediaInfo
    }

    class EventPublisher {
        <<interface Gateways.EventPublisher>>
        +messageSent(String conversationId, String sender, String recipient) void
    }

    class ChatService {
        <<@Service>>
        -ConversationRepository conversations
        -MessageRepository messages
        -UserGateway users
        -MediaGateway media
        -EventPublisher events
        -MessageBus bus
        -KeyValueStore kv
        -int maxPerWindow
        +open(String me, String other) ConversationView
        +mine(String me) List~ConversationView~
        +send(String me, String conversationId, SendCommand cmd) MessageView
        +history(String me, String conversationId, Instant before, int limit) List~MessageView~
        +markRead(String me, String conversationId) void
        +onBlocked(String a, String b) void
        +onUnfriended(String a, String b) void
        +onFriendshipChanged(String a, String b) void
        +onUserDeleted(String publicId) void
    }

    class ChatEventsListener {
        <<@Component>>
        -ChatService chat
        +onMessage(String json) void
        ~handle(EventEnvelope e) void
    }

    class ChatController {
        <<@RestController /api/v1/chat>>
        -ChatService chat
        +open(String me, OpenRequest req) ConversationView
        +mine(String me) List~ConversationView~
        +history(String me, String id, Instant before, int limit) List~MessageView~
        +send(String me, String id, SendRequest req) MessageView
        +read(String me, String id) void
    }

    MessageBus <|.. RedisMessageBus : implements
    MessageBus <|.. LocalMessageBus : implements
    ChatController --> ChatService : delegates REST
    ChatWebSocketHandler --> ChatService : delegates WS send/read
    ChatWebSocketHandler --> SessionRegistry : manages sessions
    RedisMessageBus ..> SessionRegistry : delivers via callback
    ChatEventsListener --> ChatService : handles Kafka events
    ChatService --> ConversationRepository : persists
    ChatService --> MessageRepository : persists
    ChatService --> UserGateway : checks friendship
    ChatService --> MediaGateway : verifies chat image
    ChatService --> EventPublisher : emits MESSAGE_SENT
    ChatService --> MessageBus : broadcasts frames
```

---

## 2. Sequence Diagrams theo Từng Class (`chat-service`)

### 2.1 Class `ChatController` & `ChatService` — Mở hội thoại, Gửi tin nhắn (Text / Ảnh) & Đồng bộ đa thiết bị

```mermaid
sequenceDiagram
    autonumber
    actor Sender as Sender Client
    participant CC as ChatController / ChatWebSocketHandler
    participant CS as ChatService
    participant KV as KeyValueStore (Redis)
    participant UG as RemoteUserGateway (user-service)
    participant MG as RemoteMediaGateway (media-service)
    participant Mongo as Conversation / Message Repos (MongoDB)
    participant Bus as RedisMessageBus (Pub/Sub)
    participant Kafka as KafkaEventPublisher (chat.events)

    Note over Sender,Mongo: 1. Mở hoặc tạo mới hội thoại 1-1 (POST /api/v1/chat/conversations)
    Sender->>CC: POST /api/v1/chat/conversations ({withPublicId: other})
    CC->>CS: open(me, other)
    CS->>CS: Kiểm tra me != other (400 SELF_CHAT)
    CS->>KV: get("chat:rel:" + me + ":" + other)
    alt Cache Miss
        CS->>UG: relationship(me, other) (GET /internal/relationship)
        UG-->>CS: Relationship(friends, blocked)
        CS->>KV: set("chat:rel:...", friends && !blocked ? "ok" : "no", 30s)
    end
    alt Không phải bạn bè hoặc đã chặn
        CS-->>Sender: 403 Forbidden
    else Là bạn bè hợp lệ
        CS->>Mongo: conversations.findByKey(keyOf(me, other))
        alt Chưa có hội thoại
            CS->>Mongo: save(new Conversation(me, other))
        else Hội thoại đang CLOSED (do từng huỷ kết bạn rồi kết bạn lại)
            CS->>Mongo: Đặt lại status = ACTIVE, closedReason = null & save()
        end
        CS->>Mongo: countByConversationIdAndSenderIdNotAndCreatedAtGreaterThan(...) (Đếm tin chưa đọc)
        CS-->>CC: ConversationView
        CC-->>Sender: 200 OK (ConversationView)
    end

    Note over Sender,Kafka: 2. Gửi tin nhắn Văn bản hoặc Hình ảnh (send)
    Sender->>CC: POST /api/v1/chat/conversations/{id}/messages (hoặc WS frame "send")
    CC->>CS: send(me, conversationId, SendCommand(type, text, mediaId))
    CS->>Mongo: Kiểm tra hội thoại tồn tại, me là thành viên (404), status == ACTIVE (403)
    CS->>CS: requireFriends(me, other)
    CS->>KV: increment("chat:rl:" + me + ":" + window10s, 30s)
    alt Vượt quá 20 tin nhắn / 10 giây
        CS-->>Sender: 429 Too Many Requests (CHAT_RATE_LIMIT)
    else Trong hạn mức
        opt type == IMAGE
            CS->>MG: media(mediaId) (GET /internal/media/{mediaId})
            MG-->>CS: MediaInfo(ownerPublicId, context, status)
            Note over CS: Kiểm tra owner == me && context == "CHAT" (400 INVALID_MEDIA) và status == "READY" (409 MEDIA_NOT_READY)
        end
        CS->>Mongo: messages.save(Message)
        CS->>Mongo: Cập nhật c.lastMessageAt, c.lastReadAt[me] & conversations.save(c)
        CS->>Bus: publish(other, frame("message", MessageView))
        CS->>Bus: publish(me, frame("message", MessageView)) (Đồng bộ các thiết bị khác của người gửi)
        CS->>KV: get("chat:conn:" + other) (Kiểm tra người nhận có đang mở WebSocket không)
        opt Người nhận đang Offline (không có khoá chat:conn:{other})
            CS->>Kafka: messageSent(conversationId, me, other) -> Phát MESSAGE_SENT để bắn FCM Push
        end
        CS-->>CC: MessageView
        CC-->>Sender: 201 Created MessageView (hoặc WS frame "ack")
    end
```

---

### 2.2 Class `PublicIdHandshakeInterceptor`, `ChatWebSocketHandler`, `SessionRegistry` & `RedisMessageBus` — Luồng WebSocket Đa Instance

```mermaid
sequenceDiagram
    autonumber
    actor ClientA as Client A
    participant Int as PublicIdHandshakeInterceptor
    participant WSH as ChatWebSocketHandler (Instance 1)
    participant Reg1 as SessionRegistry (Instance 1)
    participant KV as Redis (chat:conn & Pub/Sub)
    participant Reg2 as SessionRegistry (Instance 2)
    actor ClientB as Client B (đang nối vào Instance 2)

    Note over ClientA,KV: 1. Bắt tay và đăng ký phiên WebSocket
    ClientA->>Int: GET /ws/chat (Upgrade: websocket, Header X-Public-Id từ Gateway)
    Int->>Int: Đọc X-Public-Id -> lưu vào attributes["publicId"] (Thiếu -> 403)
    Int->>WSH: afterConnectionEstablished(rawSession)
    WSH->>Reg1: add(publicIdA, rawSession)
    Reg1->>Reg1: Bọc ConcurrentWebSocketSessionDecorator(10s, 512KB) & lưu vào Map sessions
    Reg1->>KV: set("chat:conn:" + publicIdA, "1", 90s)

    Note over ClientA,ClientB: 2. Gửi tin qua WebSocket và chuyển tiếp liên Instance qua Redis Pub/Sub
    ClientA->>WSH: TextMessage {"type":"send","conversationId":"c1","text":"Xin chào","clientId":"tmp-1"}
    WSH->>WSH: Gọi chatService.send(...) -> Lưu Mongo & gọi RedisMessageBus.publish(publicIdB, frame)
    WSH->>KV: PUBLISH chat:user:{publicIdB} '{"type":"message","data":{...}}'
    KV-->>Reg2: PSUBSCRIBE chat:user:* nhận thông điệp cho publicIdB
    Reg2->>ClientB: session.sendMessage(TextMessage('{"type":"message","data":{...}}'))
    WSH-->>ClientA: TextMessage '{"type":"ack","data":{"clientId":"tmp-1","messageId":"m1"}}'

    Note over ClientA,KV: 3. Nhịp tim duy trì kết nối (ping/pong) & Đóng kết nối
    ClientA->>WSH: TextMessage {"type":"ping"}
    WSH->>Reg1: touch(publicIdA) -> Gia hạn Redis chat:conn:{publicIdA} thêm 90s
    WSH-->>ClientA: TextMessage {"type":"pong","data":{}}
```

---

### 2.3 Class `ChatEventsListener` — Đóng hội thoại khi Chặn / Huỷ kết bạn / Xoá tài khoản

```mermaid
sequenceDiagram
    autonumber
    participant Kafka as Kafka (user.events / friend.events)
    participant Listener as ChatEventsListener
    participant CS as ChatService
    participant KV as KeyValueStore (Redis)
    participant Mongo as Conversation / Message Repos
    participant Bus as MessageBus

    Kafka->>Listener: onMessage(json)
    alt USER_BLOCKED (blocker, blocked)
        Listener->>CS: onBlocked(blocker, blocked)
        CS->>KV: delete("chat:rel:a:b", "chat:rel:b:a")
        CS->>Mongo: findByKey(keyOf(a, b)) -> Đặt status = CLOSED, closedReason = "BLOCKED", save()
        CS->>Bus: publish(a, frame("closed", {conversationId, reason: "BLOCKED"}))
        CS->>Bus: publish(b, frame("closed", {conversationId, reason: "BLOCKED"}))
    else FRIEND_REMOVED (userA, userB)
        Listener->>CS: onUnfriended(userA, userB)
        CS->>KV: delete("chat:rel:a:b", "chat:rel:b:a")
        CS->>Mongo: findByKey(keyOf(a, b)) -> Đặt status = CLOSED, closedReason = "UNFRIENDED", save()
        CS->>Bus: publish(a & b, frame("closed", {conversationId, reason: "UNFRIENDED"}))
    else FRIEND_ACCEPTED (userA, userB)
        Listener->>CS: onFriendshipChanged(userA, userB)
        CS->>KV: delete("chat:rel:a:b", "chat:rel:b:a")
    else USER_DELETED (publicId)
        Listener->>CS: onUserDeleted(publicId)
        CS->>Mongo: Tìm mọi Conversation của publicId -> Xoá toàn bộ Message và Conversation
        CS->>Bus: publish(other, frame("closed", {conversationId, reason: "DELETED"}))
    end
```

