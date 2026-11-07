# 07. Kiến trúc `notification-service` (`com.animallocket.notification`)

`notification-service` (`:8107`, Stateless — không dùng Database) chịu trách nhiệm:
- Lắng nghe 6 topic Kafka (`user.events`, `friend.events`, `post.events`, `chat.events`, `media.events`, `billing.events`) và khử trùng lặp trong bộ nhớ bằng Caffeine Cache (`NotificationListener`).
- Chuyển đổi từng sự kiện thành danh sách thông báo đẩy có **nội dung ẩn danh hoàn toàn** (không bao giờ chèn biệt danh, tên thú hay nội dung tin nhắn lên màn hình khoá điện thoại) (`NotificationPlanner`).
- Thực thi gửi FCM Push trên Thread Pool riêng biệt (`ExecutorConfig` — Bulkhead cô lập lỗi), tự động thử lại tối đa 3 lần khi lỗi mạng tạm thời (`TRANSIENT_ERROR`) và tự động gọi `user-service` xoá các token thiết bị đã hết hạn/gỡ cài đặt (`INVALID_TOKEN`) (`NotificationDispatcher`, `FcmPushSender`, `UserServiceDeviceDirectory`).

---

## 1. Class Diagram (`notification-service`)

```mermaid
classDiagram
    direction TB

    class Notification {
        <<record>>
        +String recipientPublicId
        +String type
        +String title
        +String body
        +Map~String, String~ data
    }
    note for Notification "Bản ghi thông báo đẩy chuẩn bị gửi.\nNội dung title/body hoàn toàn chung chung để bảo vệ tính ẩn danh trên màn hình khoá."

    class DeviceDirectory {
        <<interface>>
        +tokens(String publicId) List~String~
        +friendIds(String publicId) List~String~
        +removeToken(String token) void
    }
    note for DeviceDirectory "Cổng giao tiếp lấy danh sách FCM token và danh sách bạn bè từ user-service."

    class UserServiceDeviceDirectory {
        <<@Component>>
        -RestClient client
        +tokens(String publicId) List~String~
        +friendIds(String publicId) List~String~
        +removeToken(String token) void
    }

    class PushSender {
        <<interface>>
        +send(String deviceToken, String title, String body, Map~String, String~ data) Result
    }
    note for PushSender "Kết quả gửi (Result):\n- OK\n- INVALID_TOKEN (UNREGISTERED, INVALID_ARGUMENT, SENDER_ID_MISMATCH)\n- TRANSIENT_ERROR."

    class FcmPushSender {
        <<@Component>>
        -FirebaseMessaging messaging
        +send(String deviceToken, String title, String body, Map~String, String~ data) Result
    }
    note for FcmPushSender "Gửi thông báo thật qua Firebase Admin SDK khi có cấu hình FCM_CREDENTIALS_FILE."

    class LoggingPushSender {
        <<@Component>>
        +send(String deviceToken, String title, String body, Map~String, String~ data) Result
    }
    note for LoggingPushSender "Ghi log giả lập (che token) khi chạy dev/test không có khoá Firebase."

    class ExecutorConfig {
        <<@Configuration>>
        +pushExecutor() Executor
    }
    note for ExecutorConfig "ThreadPoolTaskExecutor riêng (core=4, max=16, queue=5000, DiscardPolicy)\nđể việc gọi FCM chậm không làm nghẽn luồng Kafka Consumer."

    class NotificationPlanner {
        <<@Component>>
        -DeviceDirectory directory
        +plan(EventEnvelope e) List~Notification~
    }
    note for NotificationPlanner "Ánh xạ 8 loại sự kiện Kafka sang danh sách người nhận:\nRiêng POST_PUBLISHED sẽ gọi directory.friendIds(author) để fan-out tới mọi người bạn."

    class NotificationDispatcher {
        <<@Component>>
        -DeviceDirectory directory
        -PushSender sender
        -MeterRegistry metrics
        -int maxAttempts
        -long backoffMs
        -LongConsumer sleeper
        +dispatch(Notification n) void
        -sendWithRetry(String token, Notification n) void
    }
    note for NotificationDispatcher "Thực hiện gửi Push kèm retry luỹ tuyến (500ms * attempt),\nđếm metric Micrometer (push.sent, push.dropped, push.invalid_token)\nvà tự động dọn token chết."

    class NotificationListener {
        <<@Component>>
        -NotificationPlanner planner
        -NotificationDispatcher dispatcher
        -Executor executor
        -Cache~String, Boolean~ seen
        +onMessage(String json) void
    }

    DeviceDirectory <|.. UserServiceDeviceDirectory : implements
    PushSender <|.. FcmPushSender : implements
    PushSender <|.. LoggingPushSender : implements
    NotificationListener --> NotificationPlanner : plans notifications
    NotificationListener --> NotificationDispatcher : submits to pushExecutor
    NotificationPlanner --> DeviceDirectory : queries friendIds
    NotificationDispatcher --> DeviceDirectory : fetches & removes tokens
    NotificationDispatcher --> PushSender : sends FCM message
```

---

## 2. Sequence Diagrams theo Từng Class (`notification-service`)

### 2.1 Class `NotificationListener` & `NotificationPlanner` — Nhận sự kiện Kafka & Lập kế hoạch Thông báo (Fan-out)

```mermaid
sequenceDiagram
    autonumber
    participant Kafka as Kafka (6 Topics)
    participant NL as NotificationListener
    participant Cache as Caffeine Seen Cache (200k, 1h)
    participant NP as NotificationPlanner
    participant Dir as UserServiceDeviceDirectory (user-service)
    participant Exec as pushExecutor (ThreadPool)

    Kafka->>NL: onMessage(json)
    NL->>NL: e = EventJson.read(json)
    NL->>Cache: seen.asMap().putIfAbsent(e.eventId(), true)
    alt Đã xử lý eventId này trong vòng 1 giờ qua
        Cache-->>NL: true (Trùng lặp -> Bỏ qua)
    else Sự kiện mới
        Cache-->>NL: null
        NL->>NP: plan(e)
        alt e.type == POST_PUBLISHED
            NP->>Dir: friendIds(authorPublicId) (GET /internal/friends/{author})
            Dir-->>NP: List<String> friendIds
            NP-->>NL: Danh sách Notification("NEW_POST", "Ảnh mới từ bạn bè", ...) cho từng người bạn
        else e.type == FRIEND_ACCEPTED
            NP-->>NL: 2 Notification("FRIEND_ACCEPTED") cho cả userA và userB
        else FRIEND_REQUEST_RECEIVED / POST_LIKED / POST_COMMENTED / MESSAGE_SENT / PHOTO_REJECTED / SUBSCRIPTION_ACTIVATED
            NP-->>NL: 1 Notification cho người nhận tương ứng
        end
        loop Từng Notification n trong danh sách
            NL->>Exec: executor.execute(() -> dispatcher.dispatch(n))
        end
    end
```

---

### 2.2 Class `NotificationDispatcher`, `FcmPushSender` & `UserServiceDeviceDirectory` — Gửi FCM, Retry & Tự động dọn Token chết

```mermaid
sequenceDiagram
    autonumber
    participant Exec as pushExecutor Thread
    participant ND as NotificationDispatcher
    participant Dir as UserServiceDeviceDirectory (user-service)
    participant Sender as FcmPushSender / LoggingPushSender
    participant FCM as Firebase Cloud Messaging
    participant Metrics as MeterRegistry (Micrometer)

    Exec->>ND: dispatch(notification)
    ND->>Dir: tokens(notification.recipientPublicId) (GET /internal/devices/{id})
    alt Lỗi kết nối tới user-service
        Dir-->>ND: RuntimeException
        ND->>Metrics: counter("push.skipped", "reason", "directory_error").increment()
    else Lấy danh sách token thành công
        Dir-->>ND: List<String> deviceTokens
        loop Từng token của người nhận
            ND->>ND: sendWithRetry(token, notification)
            loop attempt = 1 .. maxAttempts (3 lần)
                ND->>Sender: send(token, title, body, data)
                Sender->>FCM: FirebaseMessaging.send(Message)
                alt Gửi thành công (Result.OK)
                    FCM-->>Sender: messageId
                    Sender-->>ND: Result.OK
                    ND->>Metrics: counter("push.sent", "type", n.type).increment()
                    Note over ND: Thoát vòng lặp retry cho token này
                else Token không còn hợp lệ (UNREGISTERED / INVALID_ARGUMENT / SENDER_ID_MISMATCH)
                    FCM-->>Sender: FirebaseMessagingException
                    Sender-->>ND: Result.INVALID_TOKEN
                    ND->>Metrics: counter("push.invalid_token").increment()
                    ND->>Dir: removeToken(token) (DELETE /internal/devices/{token})
                    Note over ND: Thoát vòng lặp retry (không thử lại token chết)
                else Lỗi tạm thời (TRANSIENT_ERROR / 5xx / Timeout)
                    FCM-->>Sender: Exception
                    Sender-->>ND: Result.TRANSIENT_ERROR
                    opt attempt < maxAttempts
                        ND->>ND: sleep(backoffMs * attempt) (500ms, 1000ms)
                    end
                end
            end
            opt Hết 3 lần thử vẫn thất bại
                ND->>Metrics: counter("push.dropped", "type", n.type).increment()
            end
        end
    end
```

