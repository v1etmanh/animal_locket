# 10. Kiến trúc Flutter Frontend — 7 Phân hệ Tính năng (`mobile/lib/features/*`)

Tài liệu này mô tả chi tiết thiết kế lớp (Class Diagram có comment) và sơ đồ tuần tự (Sequence Diagram theo từng class) cho 7 phân hệ tính năng chính của ứng dụng di động Flutter (`mobile/lib/features/`):
1. **Camera & Upload (`features/camera`)**: Chụp ảnh, xoá sạch metadata EXIF/GPS & nén JPEG $\le 10\text{ MB}$ (`ImagePreparationService`), xin vé upload, `PUT` trực tiếp lên S3/R2, xác nhận `complete`, tạo bài đăng và đợi xử lý (`UploadController`, `LiveMediaRepository`).
2. **Bảng tin Bạn bè (`features/feed`)**: Phân trang con trỏ `before`, lưu đệm trang đầu vào SQLite, thả tim lạc quan (optimistic like) tự hoàn tác khi lỗi, bình luận và tải URL ảnh có chữ ký kèm bộ nhớ đệm thời hạn (`FeedController`, `LivePostRepository`, `mediaUrlProvider`).
3. **Khám phá Lân cận / Online (`features/discovery`)**: Xin quyền GPS (`Geolocator`), cập nhật vị trí, duy trì nhịp tim `heartbeat` mỗi 30 giây khi tab hiển thị, quẹt thẻ trái/phải, tự nạp thêm thẻ khi còn $\le 3$ thẻ và kích hoạt `Boost` (`DiscoveryController`, `LiveDiscoveryRepository`).
4. **Bạn bè & An toàn (`features/friends`)**: Quản lý danh sách bạn bè kèm chấm xanh online (`presence`), lời mời đến/đã gửi, chặn và báo cáo vi phạm (`FriendsController`, `LiveFriendsRepository`, `LiveSafetyRepository`).
5. **Trò chuyện Thời gian thực (`features/chat`)**: Kết nối WebSocket (`/ws/chat`) tự động kết nối lại theo hàm mũ + gửi `ping` mỗi 45s (`ChatRealtimeService`), gửi tin nhắn lạc quan có timeout 10s và tự động chuyển sang REST (`_sendRest`) khi WebSocket mất kết nối (`ConversationController`, `LiveChatRepository`).
6. **Hồ sơ & Bộ sưu tập Thú (`features/profile`)**: Xem/sửa biệt danh, quay thưởng Gacha, đổi thú chủ đạo (Pro), xem hồ sơ người khác, cài đặt bật/tắt khám phá, bỏ chặn và xoá tài khoản 2 bước (`ProfileController`, `LiveUserRepository`, `ProfileScreen`, `PublicProfileScreen`, `SettingsScreen`).
7. **Nâng cấp Pro & Mua vật phẩm (`features/billing`)**: Tích hợp `InAppPurchase` (StoreKit / Google Play Billing), ẩn hoàn toàn với nhóm `MINOR`, xác thực biên lai với backend **trước** khi gọi `completePurchase` (`BillingController`, `LiveBillingRepository`, `ProScreen`).

---

## Phần 1: Phân hệ Camera & Upload (`features/camera`) và Bảng tin (`features/feed`)

### 1.1 Class Diagram (`features/camera` & `features/feed`)

```mermaid
classDiagram
    direction TB

    %% ==========================================
    %% Camera & Media Upload (features/camera)
    %% ==========================================
    class ImagePreparationService {
        +int maxBytes = 10485760$
        +int targetDimension = 2048$
        +prepare(File input) Future~PreparedImage~
    }
    note for ImagePreparationService "Nén ảnh về tối đa 2048px JPEG với keepExif: false\nđể xoá sạch toạ độ GPS và thông tin thiết bị ngay trên máy khách.\nThử lần lượt chất lượng [94, 88, 82, 74] cho đến khi <= 10MB."

    class PreparedImage {
        +File file
        +int sizeBytes
        +String contentType
        +cleanup() Future~void~
    }

    class MediaRepository {
        <<interface>>
        +createUpload(MediaContext context, String contentType, int sizeBytes, String? refId) Future~UploadTicket~
        +uploadFile(UploadTicket ticket, File file, void Function(UploadProgress)? onProgress) Future~void~
        +complete(String mediaId) Future~MediaState~
        +status(String mediaId) Future~MediaState~
        +viewUrl(String mediaId) Future~MediaUrlLease~
        +waitUntilProcessed(String mediaId, Duration pollInterval, Duration timeout) Future~MediaState~
    }

    class LiveMediaRepository {
        -ApiClient _client
        -Dio _unsignedDio
        -Map~String, MediaUrlLease~ _urlCache
        +createUpload(...) Future~UploadTicket~
        +uploadFile(...) Future~void~
        +complete(String mediaId) Future~MediaState~
        +status(String mediaId) Future~MediaState~
        +viewUrl(String mediaId) Future~MediaUrlLease~
        +waitUntilProcessed(...) Future~MediaState~
    }
    note for LiveMediaRepository "Dùng _unsignedDio riêng (không gắn Bearer JWT của app)\nkhi PUT file trực tiếp lên URL đã ký của Cloudflare R2 / MinIO.\nLưu đệm URL xem ảnh trong _urlCache cho tới trước khi hết hạn 30 giây."

    class UploadController {
        <<Notifier~UploadFlowState~>>
        +build() UploadFlowState
        +reset() void
        +publish(File input, String? caption) Future~void~
    }
    note for UploadController "Điều phối chuỗi 6 bước đăng ảnh:\npreparing -> uploading -> complete -> create post -> waitUntilProcessed -> cleanup."

    class CameraScreen {
        <<ConsumerStatefulWidget>>
    }

    class PreviewScreen {
        <<ConsumerStatefulWidget>>
        +String imagePath
    }

    %% ==========================================
    %% Feed & Posts (features/feed)
    %% ==========================================
    class PostRepository {
        <<interface>>
        +create(String mediaId, String? caption) Future~Post~
        +mine(int limit) Future~List~Post~~
        +feed(DateTime? before, int limit) Future~PagedResult~Post~~
        +delete(String postId) Future~void~
        +like(String postId) Future~void~
        +unlike(String postId) Future~void~
        +comments(String postId, int after, int limit) Future~PagedResult~Comment~~
        +addComment(String postId, String text) Future~Comment~
        +deleteComment(String postId, int commentId) Future~void~
    }

    class LivePostRepository {
        -ApiClient _client
        -CacheDatabase _cache
        +create(...) Future~Post~
        +feed(...) Future~PagedResult~Post~~
        +like(String postId) Future~void~
        +unlike(String postId) Future~void~
        +comments(...) Future~PagedResult~Comment~~
        +addComment(...) Future~Comment~
        +deleteComment(...) Future~void~
    }
    note for LivePostRepository "Lưu trang đầu của Feed vào SQLite (feed:first_page).\nNếu mạng lỗi khi tải trang đầu, tự động đọc lại từ SQLite."

    class FeedController {
        <<AsyncNotifier~FeedState~>>
        +build() Future~FeedState~
        +refresh() Future~void~
        +loadMore() Future~void~
        +toggleLike(String postId) Future~void~
        +deletePost(String postId) Future~void~
    }

    class FeedScreen {
        <<ConsumerStatefulWidget>>
    }

    MediaRepository <|.. LiveMediaRepository : implements
    PostRepository <|.. LivePostRepository : implements
    ImagePreparationService ..> PreparedImage : produces
    UploadController --> ImagePreparationService : strips EXIF & compresses
    UploadController --> MediaRepository : uploads & polls
    UploadController --> PostRepository : creates post
    CameraScreen --> PreviewScreen : navigates with imagePath
    PreviewScreen --> UploadController : triggers publish
    FeedController --> PostRepository : loads feed & toggles like
    FeedScreen --> FeedController : watches state
    FeedScreen --> MediaRepository : resolves viewUrl via mediaUrlProvider
```

### 1.2 Sequence Diagrams theo Từng Class (`features/camera` & `features/feed`)

#### A. Class `CameraScreen`, `PreviewScreen`, `UploadController`, `ImagePreparationService` & `LiveMediaRepository` — Luồng Chụp, Xoá EXIF & Đăng ảnh
```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant Cam as CameraScreen
    participant Prev as PreviewScreen
    participant UC as UploadController
    participant Prep as ImagePreparationService
    participant MR as LiveMediaRepository
    participant S3 as Cloudflare R2 / MinIO (Presigned URL)
    participant PR as LivePostRepository

    User->>Cam: Chụp ảnh (takePicture) hoặc chọn ảnh từ thư viện
    Cam->>Prev: context.push('/preview?imagePath=...')
    User->>Prev: Nhập chú thích (caption) & nhấn "Đăng ảnh"
    Prev->>UC: publish(input: File(imagePath), caption: caption)
    UC->>UC: state = UploadFlowState(stage: preparing)
    UC->>Prep: prepare(input)
    Prep->>Prep: FlutterImageCompress.compressAndGetFile(keepExif: false, minWidth: 2048, quality: 94..74)
    Prep-->>UC: PreparedImage(file, sizeBytes <= 10MB, "image/jpeg")
    UC->>MR: createUpload(context: POST, contentType: "image/jpeg", sizeBytes: prepared.sizeBytes)
    MR-->>UC: UploadTicket(mediaId, uploadUrl, headers)
    UC->>UC: state = UploadFlowState(stage: uploading, progress: 0..1)
    UC->>MR: uploadFile(ticket, prepared.file, onProgress)
    MR->>S3: _unsignedDio.put(ticket.uploadUrl, Stream, headers: Content-Type + Content-Length)
    S3-->>MR: 200 OK
    UC->>UC: state = UploadFlowState(stage: processing)
    UC->>MR: complete(ticket.mediaId) (POST /api/v1/media/{id}/complete)
    UC->>PR: create(mediaId: ticket.mediaId, caption: caption) (POST /api/v1/posts)
    UC->>MR: waitUntilProcessed(ticket.mediaId) (GET /api/v1/media/{id} mỗi 2s, tối đa 60s)
    alt Trạng thái ảnh là READY
        MR-->>UC: MediaState(status: ready)
        UC->>Prep: prepared.cleanup() (Xoá file ảnh tạm trong khối finally)
        UC->>UC: state = UploadFlowState(stage: ready)
        Prev->>Prev: feedController.refresh() & context.go('/feed')
    else Trạng thái ảnh là REJECTED
        MR-->>UC: MediaState(status: rejected, rejectReason)
        UC->>Prep: prepared.cleanup()
        UC->>UC: state = UploadFlowState(stage: rejected, errorMessage)
    end
```

#### B. Class `FeedController`, `LivePostRepository` & `LiveMediaRepository` — Tải Feed, Thả tim Lạc quan & Lấy URL Ảnh có Chữ ký
```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant FS as FeedScreen
    participant FC as FeedController
    participant PR as LivePostRepository
    participant Cache as CacheDatabase (SQLite)
    participant MR as LiveMediaRepository

    Note over User,MR: 1. Mở màn hình Bảng tin (Feed) & phân giải URL ảnh
    User->>FS: Mở FeedScreen
    FS->>FC: build() / refresh()
    FC->>PR: feed(before: null, limit: 20)
    alt Gọi API GET /api/v1/feed thành công
        PR->>Cache: write('feed:first_page', response.data)
        PR-->>FC: PagedResult<Post>(items, nextBefore, degraded)
    else Mạng lỗi khi tải trang đầu
        PR->>Cache: read('feed:first_page')
        Cache-->>PR: Dữ liệu đệm gần nhất
        PR-->>FC: PagedResult<Post>(cachedItems, degraded: true)
    end
    FC-->>FS: FeedState(items, nextBefore, degraded)
    loop Từng _PostCard hiển thị trên màn hình
        FS->>MR: ref.watch(mediaUrlProvider(post.mediaId)) -> viewUrl(mediaId)
        MR->>MR: Kiểm tra _urlCache[mediaId] (còn hạn > 30s?)
        opt Chưa có hoặc sắp hết hạn
            MR->>MR: GET /api/v1/media/{id}/url -> Lưu MediaUrlLease vào _urlCache
        end
        MR-->>FS: signedUrl -> Image.network(signedUrl)
    end

    Note over User,PR: 2. Thả tim lạc quan (Optimistic Like)
    User->>FS: Nhấn nút Tim trên bài viết
    FS->>FC: toggleLike(postId)
    FC->>FC: Cập nhật ngay UI: likedByMe = !likedByMe, likeCount += (±1)
    FC->>PR: like(postId) hoặc unlike(postId) (PUT / DELETE /api/v1/posts/{id}/like)
    opt Gọi API thất bại
        PR-->>FC: Exception
        FC->>FC: Khôi phục lại danh sách previous (Rollback trạng thái tim trên UI)
    end
```

---

## Phần 2: Phân hệ Khám phá (`features/discovery`) & Bạn bè (`features/friends`)

### 2.1 Class Diagram (`features/discovery` & `features/friends`)

```mermaid
classDiagram
    direction TB

    %% ==========================================
    %% Discovery (features/discovery)
    %% ==========================================
    class DiscoveryRepository {
        <<interface>>
        +updateLocation(double lat, double lon) Future~void~
        +deleteLocation() Future~void~
        +heartbeat() Future~void~
        +cards(int limit) Future~DiscoveryDeck~
        +swipe(String targetPublicId, bool right) Future~SwipeResult~
        +boost() Future~void~
    }

    class LiveDiscoveryRepository {
        -ApiClient _client
        +updateLocation(double lat, double lon) Future~void~
        +deleteLocation() Future~void~
        +heartbeat() Future~void~
        +cards(int limit) Future~DiscoveryDeck~
        +swipe(String targetPublicId, bool right) Future~SwipeResult~
        +boost() Future~void~
    }

    class DiscoveryController {
        <<AsyncNotifier~DiscoveryState~>>
        -Timer? _heartbeatTimer
        +build() Future~DiscoveryState~
        +enable() Future~void~
        +refreshDeck() Future~void~
        +swipe(bool right) Future~SwipeResult?~
        +boost() Future~void~
        +setActive(bool active) void
    }
    note for DiscoveryController "Quản lý bộ thẻ quẹt và Timer nhịp tim 30s.\nChỉ gửi heartbeat khi màn hình Khám phá đang hiển thị và app ở trạng thái resumed."

    class DiscoveryScreen {
        <<ConsumerStatefulWidget>>
    }

    %% ==========================================
    %% Friends & Safety (features/friends)
    %% ==========================================
    class FriendsRepository {
        <<interface>>
        +friends() Future~List~PublicProfile~~
        +remove(String publicId) Future~void~
        +incoming() Future~List~FriendRequest~~
        +outgoing() Future~List~FriendRequest~~
        +invite(String toPublicId) Future~String~
        +accept(int requestId) Future~void~
        +decline(int requestId) Future~void~
        +cancel(int requestId) Future~void~
        +presence(List~String~ publicIds) Future~Map~String, bool~~
    }

    class SafetyRepository {
        <<interface>>
        +blocked() Future~List~PublicProfile~~
        +block(String publicId) Future~void~
        +unblock(String publicId) Future~void~
        +report(ReportTarget targetType, String targetPublicId, String reason, String? targetRef, String? details) Future~void~
    }

    class LiveFriendsRepository {
        -ApiClient _client
        +friends() Future~List~PublicProfile~~
        +incoming() Future~List~FriendRequest~~
        +outgoing() Future~List~FriendRequest~~
        +accept(int requestId) Future~void~
        +presence(List~String~ publicIds) Future~Map~String, bool~~
    }

    class LiveSafetyRepository {
        -ApiClient _client
        +blocked() Future~List~PublicProfile~~
        +block(String publicId) Future~void~
        +unblock(String publicId) Future~void~
        +report(...) Future~void~
    }

    class FriendsController {
        <<AsyncNotifier~FriendsState~>>
        +build() Future~FriendsState~
        +refresh() Future~void~
        +accept(int id) Future~void~
        +decline(int id) Future~void~
        +cancel(int id) Future~void~
        +remove(String publicId) Future~void~
    }

    class FriendsScreen {
        <<ConsumerWidget>>
    }

    DiscoveryRepository <|.. LiveDiscoveryRepository : implements
    FriendsRepository <|.. LiveFriendsRepository : implements
    SafetyRepository <|.. LiveSafetyRepository : implements
    DiscoveryController --> DiscoveryRepository : calls API
    DiscoveryScreen --> DiscoveryController : watches & syncs lifecycle
    FriendsController --> FriendsRepository : loads friends/requests/presence
    FriendsScreen --> FriendsController : renders 3 tabs
```

### 2.2 Sequence Diagrams theo Từng Class (`features/discovery` & `features/friends`)

#### A. Class `DiscoveryScreen`, `DiscoveryController` & `LiveDiscoveryRepository` — Bật Khám phá, Heartbeat, Quẹt thẻ & Boost
```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant DS as DiscoveryScreen
    participant DC as DiscoveryController
    participant UR as LiveUserRepository
    participant Geo as Geolocator (OS GPS)
    participant DR as LiveDiscoveryRepository

    Note over User,DR: 1. Bật chế độ Khám phá (Opt-in) & Lấy vị trí
    User->>DS: Nhấn "Bật chế độ khám phá"
    DS->>DC: enable()
    DC->>UR: update(discoverable: true) (PATCH /api/v1/users/me)
    DC->>Geo: checkPermission() / requestPermission()
    alt Người dùng cấp quyền Vị trí
        DC->>Geo: getCurrentPosition(LocationAccuracy.low)
        Geo-->>DC: Position(lat, lon)
        DC->>DR: updateLocation(lat, lon) (PUT /api/v1/discovery/location)
    else Từ chối quyền Vị trí
        Note over DC: Vẫn tiếp tục ở chế độ chỉ Online (locationGranted = false)
    end
    DC->>DR: cards() (GET /api/v1/discovery/cards)
    DR-->>DC: DiscoveryDeck(cards, degraded, swipesLeftToday)
    DC->>DC: setActive(true) -> Gửi heartbeat() ngay và bật Timer.periodic(30s)

    Note over User,DR: 2. Quẹt thẻ Trái / Phải & Tự nạp thêm thẻ
    User->>DS: Quẹt thẻ (hoặc nhấn nút Bỏ qua / Kết bạn)
    DS->>DC: swipe(right: true | false)
    DC->>DR: swipe(topCard.publicId, right) (POST /api/v1/discovery/swipes)
    DR-->>DC: SwipeResult(result, swipesLeftToday)
    DC->>DC: Loại bỏ thẻ đầu khỏi danh sách
    opt Số thẻ còn lại <= 3
        DC->>DR: cards() -> Gộp thêm các thẻ mới chưa trùng vào cuối bộ bài
    end
    DC-->>DS: SwipeResult (Nếu result == "MATCHED" hiển thị SnackBar kết bạn thành công!)
```

#### B. Class `FriendsScreen`, `FriendsController` & `LiveFriendsRepository` — Tải Bạn bè kèm Trạng thái Online & Xử lý Lời mời
```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant FS as FriendsScreen
    participant FC as FriendsController
    participant FR as LiveFriendsRepository

    User->>FS: Mở màn hình Bạn bè (/friends)
    FS->>FC: build() / refresh()
    FC->>FR: Gọi song song friends(), incoming(), outgoing()
    FR-->>FC: Danh sách bạn bè, lời mời đến, lời mời đã gửi
    opt Danh sách bạn bè không rỗng
        FC->>FR: presence(friendPublicIds) (GET /api/v1/discovery/presence?ids=...)
        FR-->>FC: Map<String, bool> onlineMap
    end
    FC-->>FS: FriendsState(friends, incoming, outgoing, online)
    User->>FS: Nhấn "Đồng ý" trên một lời mời kết bạn
    FS->>FC: accept(requestId)
    FC->>FR: accept(requestId) (POST /api/v1/friends/requests/{id}/accept)
    FC->>FC: refresh() (Tải lại danh sách bạn bè mới)
```

---

## Phần 3: Phân hệ Chat Realtime (`features/chat`), Hồ sơ (`features/profile`) & Nâng cấp Pro (`features/billing`)

### 3.1 Class Diagram (`features/chat`, `features/profile`, `features/billing`)

```mermaid
classDiagram
    direction TB

    %% ==========================================
    %% Chat Realtime & REST (features/chat)
    %% ==========================================
    class ChatSocketAdapter {
        <<interface>>
        +Stream~String~ messages
        +send(String data) void
        +close() Future~void~
    }

    class ChatRealtimeService {
        -AppConfig _config
        -SessionManager _session
        -ChatSocketAdapter? _socket
        -Timer? _pingTimer
        -Timer? _reconnectTimer
        -int _reconnectAttempts
        +Stream~Map~ events
        +bool isConnected
        +connect() Future~void~
        +sendFrame(Map frame) bool
        +disconnect() Future~void~
    }
    note for ChatRealtimeService "Quản lý kết nối WebSocket /ws/chat:\n- Gửi {'type':'ping'} mỗi 45 giây.\n- Khi mất kết nối: tự kết nối lại với Exponential Backoff + Jitter.\n- Phát sóng mọi khung JSON nhận được qua Stream events."

    class ChatRepository {
        <<interface>>
        +conversations() Future~List~Conversation~~
        +createConversation(String participantPublicId) Future~Conversation~
        +messages(String conversationId, DateTime? before, int limit) Future~PagedResult~ChatMessage~~
        +sendText(String conversationId, String text) Future~ChatMessage~
        +sendImage(String conversationId, String mediaId) Future~ChatMessage~
        +markRead(String conversationId) Future~void~
    }

    class LiveChatRepository {
        -ApiClient _client
        -CacheDatabase _cache
        +conversations() Future~List~Conversation~~
        +createConversation(String participantPublicId) Future~Conversation~
        +messages(...) Future~PagedResult~ChatMessage~~
        +sendText(...) Future~ChatMessage~
        +sendImage(...) Future~ChatMessage~
        +markRead(String conversationId) Future~void~
    }

    class ConversationController {
        <<AsyncNotifier~ConversationState~>>
        -Map~String, Timer~ _ackTimers
        -Set~String~ _retriedTempIds
        +build() Future~ConversationState~
        +loadOlder() Future~void~
        +sendText(String rawText) Future~void~
        +sendImage(File file) Future~void~
        -_sendRest(String conversationId, String tempId, String text) Future~void~
        -_onEvent(Map frame) void
    }
    note for ConversationController "Hỗ trợ gửi tin nhắn lạc quan (pending: true):\nƯu tiên gửi qua WebSocket (đợi ACK 10s, retry 1 lần), nếu vẫn timeout hoặc mất WS\nsẽ tự động chuyển sang gọi REST POST /chat/conversations/{id}/messages."

    %% ==========================================
    %% Profile & Settings (features/profile)
    %% ==========================================
    class UserRepository {
        <<interface>>
        +me() Future~MeProfile~
        +register(DateTime birthDate, String? alias) Future~MeProfile~
        +update(String? alias, bool? discoverable) Future~MeProfile~
        +deleteAccount() Future~void~
        +publicProfile(String publicId) Future~PublicProfile~
        +animals() Future~List~Animal~~
        +ownedAnimals() Future~List~String~~
        +spin() Future~SpinResult~
        +setLeadAnimal(String animalCode) Future~MeProfile~
    }

    class ProfileController {
        <<AsyncNotifier~ProfileData~>>
        +build() Future~ProfileData~
        +refresh() Future~void~
        +spin() Future~SpinResult~
        +setLeadAnimal(String animalCode) Future~void~
        +updateAlias(String alias) Future~void~
    }

    %% ==========================================
    %% Billing & IAP (features/billing)
    %% ==========================================
    class BillingRepository {
        <<interface>>
        +products() Future~List~BillingProduct~~
        +verify(String store, String sku, String token) Future~void~
    }

    class LiveBillingRepository {
        -ApiClient _client
        +products() Future~List~BillingProduct~~
        +verify(String store, String sku, String token) Future~void~
    }

    class BillingController {
        <<AsyncNotifier~BillingState~>>
        -StreamSubscription? _sub
        +build() Future~BillingState~
        +buy(String sku) Future~void~
        +restore() Future~void~
        -_onPurchases(List~PurchaseDetails~ purchases) Future~void~
    }
    note for BillingController "Tích hợp StoreKit / Google Play Billing:\n1. Vô hiệu hoá nếu người dùng là MINOR.\n2. Khi nhận PurchaseStatus.purchased/restored: gọi backend verify() TRƯỚC,\nchỉ gọi completePurchase() sau khi backend trả 200 OK."

    ChatRepository <|.. LiveChatRepository : implements
    BillingRepository <|.. LiveBillingRepository : implements
    ChatRealtimeService --> ChatSocketAdapter : wraps WS
    ConversationController --> ChatRealtimeService : sends & listens frames
    ConversationController --> ChatRepository : history & REST fallback
    ProfileController --> UserRepository : loads profile/animals/spin
    BillingController --> BillingRepository : verifies receipt
```

### 3.2 Sequence Diagrams theo Từng Class (`features/chat`, `features/profile`, `features/billing`)

#### A. Class `ConversationController`, `ChatRealtimeService` & `LiveChatRepository` — Gửi Tin nhắn Realtime, Xử lý ACK & Tự động Fallback sang REST
```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant Conv as ConversationScreen
    participant CC as ConversationController
    participant WS as ChatRealtimeService (/ws/chat)
    participant CR as LiveChatRepository (REST)

    Note over User,CR: 1. Gửi tin nhắn văn bản (Ưu tiên WebSocket + Fallback REST)
    User->>Conv: Nhập tin nhắn & nhấn Gửi
    Conv->>CC: sendText(rawText)
    CC->>CC: Tạo tempId = "local-<uuid>", chèn ChatMessage(pending: true) vào đầu danh sách UI
    alt WS đang kết nối (ws.isConnected == true)
        CC->>WS: sendFrame({"type":"send","conversationId":id,"text":text,"clientId":tempId})
        CC->>CC: Đặt Timer đợi ACK 10 giây (_ackTimers[tempId])
        alt Nhận được khung {"type":"ack","data":{"clientId":tempId,"messageId":serverId}} trong 10s
            WS-->>CC: _onEvent(ackFrame)
            CC->>CC: Huỷ Timer, cập nhật tin nhắn tempId -> serverId (pending: false)
        else Quá 10s không nhận được ACK
            CC->>WS: Thử gửi lại khung WS 1 lần nữa (_retriedTempIds.add(tempId))
            opt Hết thêm 10s vẫn không có ACK
                CC->>CR: _sendRest: sendText(conversationId, text) (POST /api/v1/chat/conversations/{id}/messages)
                CR-->>CC: ChatMessage đã lưu
                CC->>CC: Thay thế tin nhắn tempId bằng ChatMessage từ REST (pending: false)
            end
        end
    else WS đang mất kết nối
        CC->>CR: _sendRest: sendText(conversationId, text) (Gửi thẳng qua REST)
        CR-->>CC: ChatMessage
        CC->>CC: Cập nhật pending = false
    end

    Note over User,CR: 2. Gửi tin nhắn Hình ảnh trong Chat
    User->>Conv: Chọn ảnh từ thư viện trong màn hình Chat
    Conv->>CC: sendImage(file)
    CC->>CC: ImagePreparationService.prepare(file) (Xoá EXIF + nén <= 10MB)
    CC->>CC: media.createUpload(context: CHAT) -> uploadFile -> complete -> waitUntilProcessed
    CC->>CR: sendImage(conversationId, ticket.mediaId) (POST /api/v1/chat/conversations/{id}/messages)
    CR-->>CC: ChatMessage(type: IMAGE)
    CC->>CC: Hiển thị tin nhắn ảnh lên hội thoại
```

#### B. Class `BillingController`, `LiveBillingRepository` & `ProScreen` — Luồng Mua Gói Pro / Vật phẩm An toàn (Verify-before-Complete)
```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng (ADULT)
    participant Pro as ProScreen
    participant BC as BillingController
    participant IAP as InAppPurchase (Apple StoreKit / Google Play)
    participant BR as LiveBillingRepository (Backend)
    participant AC as AuthController

    User->>Pro: Mở màn hình Nâng cấp Pro (/pro)
    Pro->>BC: build()
    BC->>BC: Kiểm tra config.enableBilling && profile.ageGroup != AgeGroup.minor
    BC->>BR: products() (GET /api/v1/billing/products)
    BR-->>BC: Danh sách SKU từ backend
    BC->>IAP: queryProductDetails(skuSet)
    IAP-->>BC: ProductDetails (Giá tiền bản địa từ Apple/Google)
    User->>Pro: Nhấn mua gói Pro hoặc vật phẩm lẻ (buy(sku))
    Pro->>BC: buy(sku)
    BC->>IAP: buyNonConsumable(purchaseParam)
    IAP-->>BC: purchaseStream phát sự kiện PurchaseDetails(status: purchased)
    BC->>BR: verify(store: 'APPLE' | 'GOOGLE', sku: productID, token: serverVerificationData)
    alt Backend xác thực biên lai thành công (200 OK)
        BR-->>BC: 200 OK (Đã cấp quyền trong DB)
        BC->>IAP: completePurchase(purchase) (Chỉ đóng giao dịch với Store SAU KHI backend trả 200!)
        BC->>AC: refreshProfile() (Cập nhật huy hiệu PRO mới trên toàn app)
    else Backend trả lỗi tạm thời (503 STORE_UNAVAILABLE / mạng đứt)
        BR-->>BC: ApiProblem
        Note over BC,IAP: KHÔNG gọi completePurchase để Store giữ nguyên giao dịch, lần sau mở app tự khôi phục!
        BC-->>Pro: Hiển thị thông báo lỗi trên ProScreen
    end
```

