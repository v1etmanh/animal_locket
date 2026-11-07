# 05. Kiến trúc `discovery-service` (`com.animallocket.discovery`)

`discovery-service` (`:8104`, Redis GEO/ZSET, không dùng SQL DB) chịu trách nhiệm:
- Bảo vệ quyền riêng tư vị trí bằng cách làm tròn về tâm ô lưới ~500m kết hợp độ lệch cố định theo người dùng bằng `HMAC-SHA256(secret, publicId)` (`±250m`), chỉ trả về dải khoảng cách thô (`LocationPrivacy`).
- Tách biệt hoàn toàn dữ liệu vị trí và trạng thái online theo nhóm tuổi (`geo:ADULT` vs `geo:MINOR`, `online:ADULT` vs `online:MINOR`).
- Xây dựng bộ thẻ quẹt kết hợp **người ở gần (GEO)** HOẶC **đang online (Heartbeat trong 60s)**, loại trừ bạn bè, người bị chặn 2 chiều, người đã quẹt trái (trong 30 ngày) hoặc đã quẹt phải.
- Xử lý quẹt trái/phải có hạn mức (Free 30/ngày, Pro 150/ngày, tự hoàn lượt khi lỗi/đã kết bạn/bị chặn) và kích hoạt `Boost` 30 phút qua `billing-service`.

---

## 1. Class Diagram (`discovery-service`)

```mermaid
classDiagram
    direction TB

    %% ==========================================
    %% Privacy & Store Layer
    %% ==========================================
    class LocationPrivacy {
        <<final>>
        +double CELL_METERS = 500.0$
        +double MAX_OFFSET_METERS = 250.0$
        -byte[] secret
        +snap(LatLon p)$ LatLon
        +storedPosition(String publicId, LatLon raw) LatLon
        ~offsetMeters(String publicId) double[]
        +distanceMeters(LatLon a, LatLon b)$ double
        +band(double meters, boolean minor)$ String
    }
    note for LocationPrivacy "Cơ chế chống định vị tam giác (Anti-trilateration):\n1. Làm tròn toạ độ về tâm ô lưới ~500m.\n2. Cộng độ lệch cố định theo người dùng (HMAC-SHA256) ±250m.\n3. Nhóm MINOR không có mức UNDER_1KM (gộp vào UNDER_3KM)."

    class DiscoveryStore {
        <<interface>>
        +putLocation(String ageGroup, String publicId, LatLon pos, Instant expiresAt) void
        +location(String ageGroup, String publicId) Optional~LatLon~
        +nearby(String ageGroup, LatLon center, double radiusMeters, int limit) List~Neighbor~
        +touchOnline(String ageGroup, String publicId, Instant now) void
        +online(String ageGroup, Instant since, int limit) List~String~
        +onlineStatus(Set~String~ publicIds, Instant since) Map~String, Boolean~
        +boost(String publicId, Instant until) void
        +boosted(Instant now) Set~String~
        +recordLeft(String me, String target, Instant at) void
        +recentLeft(String me, Instant since) Set~String~
        +recordRight(String me, String target, Instant at) void
        +rights(String me) Set~String~
        +removePresence(String publicId) void
        +purgeExpired(Instant now) int
        +forget(String publicId) void
    }
    note for DiscoveryStore "Giao diện lưu trữ trạng thái khám phá.\nTách khoá theo ageGroup để người lớn và trẻ vị thành niên không bao giờ thấy nhau."

    class RedisDiscoveryStore {
        -StringRedisTemplate redis
        +putLocation(...) void
        +nearby(...) List~Neighbor~
        +touchOnline(...) void
        +online(...) List~String~
        +boost(...) void
        +purgeExpired(Instant now) int
        +forget(String publicId) void
    }
    note for RedisDiscoveryStore "Triển khai trên Redis:\n- GEOSET: geo:{ageGroup} + ZSET hạn dùng geo:exp:{ageGroup}\n- ZSET online: online:{ageGroup}\n- ZSET boost: boost\n- ZSET/SET quẹt: swipe:left:{me}, swipe:right:{me}."

    class InMemoryDiscoveryStore {
        +putLocation(...) void
        +nearby(...) List~Neighbor~
    }

    %% ==========================================
    %% S2S Gateways
    %% ==========================================
    class UserGateway {
        <<interface Gateways.UserGateway>>
        +profile(String publicId) Profile
        +profiles(List~String~ publicIds) Map~String, Profile~
        +exclusions(String publicId) Exclusions
        +swipeRight(String from, String to) String
    }

    class RemoteUserGateway {
        <<@Component>>
        -RestClient client
        -CircuitBreakerFactory breakers
        +profile(String publicId) Profile
        +profiles(List~String~ publicIds) Map~String, Profile~
        +exclusions(String publicId) Exclusions
        +swipeRight(String from, String to) String
    }

    class BillingGateway {
        <<interface Gateways.BillingGateway>>
        +consumeBoost(String publicId) boolean
    }

    class RemoteBillingGateway {
        <<@Component>>
        -RestClient client
        -CircuitBreakerFactory breakers
        +consumeBoost(String publicId) boolean
    }

    %% ==========================================
    %% Service, Messaging & Controller
    %% ==========================================
    class DiscoveryService {
        <<@Service>>
        -DiscoveryStore store
        -UserGateway users
        -BillingGateway billing
        -LocationPrivacy privacy
        -KeyValueStore kv
        -Clock clock
        -Duration locationTtl
        -double radiusAdultM
        -double radiusMinorM
        -int cardsPerMinute
        -int swipesFree
        -int swipesPro
        +updateLocation(String me, double lat, double lon) void
        +clearLocation(String me) void
        +heartbeat(String me) void
        +presence(String me, Set~String~ ids) PresenceResponse
        +cards(String me, int limit) CardsResponse
        +swipe(String me, String target, Direction dir) SwipeResponse
        +boost(String me) void
        +forget(String publicId) void
        +setPro(String publicId, Instant expiresAt) void
        +clearPro(String publicId) void
        +purge() int
    }

    class DiscoveryEvents {
        <<@Component>>
        -DiscoveryService discovery
        +onMessage(String json) void
        +purge() void
    }
    note for DiscoveryEvents "Lắng nghe user.events & billing.events (USER_DELETED, DISCOVERY_DISABLED, SUBSCRIPTION_*)\nvà chạy @Scheduled mỗi 60s để dọn các điểm GEO/online hết hạn."

    class DiscoveryController {
        <<@RestController /api/v1/discovery>>
        -DiscoveryService discovery
        +location(String me, LocationRequest req) void
        +clearLocation(String me) void
        +heartbeat(String me) void
        +presence(String me, List~String~ ids) PresenceResponse
        +cards(String me, int limit) CardsResponse
        +swipe(String me, SwipeRequest req) SwipeResponse
        +boost(String me) void
    }
    note for DiscoveryController "Endpoint /cards xử lý Fail-soft: nếu user-service 503 hoặc Redis lỗi\nsẽ trả về CardsResponse([], degraded=true, 0) thay vì làm sập màn hình."

    DiscoveryStore <|.. RedisDiscoveryStore : implements
    DiscoveryStore <|.. InMemoryDiscoveryStore : implements
    UserGateway <|.. RemoteUserGateway : implements
    BillingGateway <|.. RemoteBillingGateway : implements
    DiscoveryController --> DiscoveryService : delegates
    DiscoveryEvents --> DiscoveryService : triggers
    DiscoveryService --> DiscoveryStore : reads/writes GEO & online
    DiscoveryService --> LocationPrivacy : snaps & bands coordinates
    DiscoveryService --> UserGateway : fetches profiles/exclusions/swipes
    DiscoveryService --> BillingGateway : consumes BOOST
```

---

## 2. Sequence Diagrams theo Từng Class (`discovery-service`)

### 2.1 Class `DiscoveryController`, `DiscoveryService` & `LocationPrivacy` — Cập nhật Vị trí, Heartbeat & Truy vấn Online

```mermaid
sequenceDiagram
    autonumber
    actor Client as Mobile Client
    participant DC as DiscoveryController
    participant DS as DiscoveryService
    participant UG as RemoteUserGateway (user-service)
    participant LP as LocationPrivacy
    participant Store as RedisDiscoveryStore
    participant KV as KeyValueStore (Redis)

    Note over Client,Store: 1. Cập nhật vị trí (PUT /api/v1/discovery/location)
    Client->>DC: PUT /api/v1/discovery/location ({lat, lon})
    DC->>DS: updateLocation(me, lat, lon)
    DS->>UG: profile(me) (GET /internal/users/{me})
    alt Hồ sơ không tồn tại hoặc !active
        UG-->>DS: null / inactive
        DS-->>Client: 404 Not Found
    else Hồ sơ đang tắt khám phá (!discoverable)
        UG-->>DS: discoverable = false
        DS-->>Client: 403 Forbidden ("Bạn đang tắt chế độ khám phá")
    else Đang bật khám phá
        DS->>LP: storedPosition(me, LatLon(lat, lon))
        LP->>LP: snap(raw) (Làm tròn tâm lưới 500m) + offsetMeters(me) (HMAC-SHA256 ±250m)
        LP-->>DS: LatLon noisyPos
        DS->>Store: putLocation(profile.ageGroup, me, noisyPos, now + 30m)
        DS->>Store: touchOnline(profile.ageGroup, me, now)
        DC-->>Client: 204 No Content
    end

    Note over Client,KV: 2. Gửi nhịp tim Online (POST /api/v1/discovery/heartbeat)
    Client->>DC: POST /api/v1/discovery/heartbeat
    DC->>DS: heartbeat(me)
    DS->>UG: profile(me)
    DS->>KV: set("presence:" + me, epochSecond, 3 minutes) (Dùng cho danh sách bạn bè)
    opt profile.discoverable() == true
        DS->>Store: touchOnline(profile.ageGroup, me, now) (Dùng cho bộ thẻ khám phá)
    end
    DC-->>Client: 204 No Content

    Note over Client,KV: 3. Kiểm tra trạng thái Online của Bạn bè (GET /api/v1/discovery/presence?ids=...)
    Client->>DC: GET /api/v1/discovery/presence?ids=u1,u2
    DC->>DS: presence(me, ids)
    DS->>UG: exclusions(me).friends() (Chỉ cho phép xem trạng thái online của bạn bè thực sự)
    loop Từng ID thuộc giao của ids và friends
        DS->>KV: get("presence:" + id) (Kiểm tra timestamp >= now - 60s)
    end
    DS-->>DC: PresenceResponse(Map<String, Boolean>)
    DC-->>Client: 200 OK (PresenceResponse)
```

---

### 2.2 Class `DiscoveryService` & `RedisDiscoveryStore` — Ghép Bộ Thẻ Khám Phá (`GET /api/v1/discovery/cards`)

```mermaid
sequenceDiagram
    autonumber
    actor Client as Mobile Client
    participant DC as DiscoveryController
    participant DS as DiscoveryService
    participant KV as KeyValueStore (Redis)
    participant UG as RemoteUserGateway (user-service)
    participant Store as RedisDiscoveryStore
    participant LP as LocationPrivacy

    Client->>DC: GET /api/v1/discovery/cards?limit=20
    DC->>DS: cards(me, limit)
    DS->>KV: increment("rl:cards:" + me + ":" + minute, 2m)
    alt Vượt quá 10 lần tìm/phút
        DS-->>Client: 429 Too Many Requests (TOO_MANY_SEARCHES)
    else Trong giới hạn tìm kiếm
        DS->>UG: profile(me) (Kiểm tra active && discoverable)
        DS->>UG: exclusions(me) (Lấy friends + blockedEitherWay)
        DS->>Store: recentLeft(me, now - 30d) & rights(me)
        DS->>DS: excluded = friends ∪ blockedEitherWay ∪ recentLeft ∪ rights ∪ {me}
        DS->>Store: location(self.ageGroup, me)
        opt Người gọi có vị trí lưu trong Redis
            DS->>Store: nearby(self.ageGroup, myPos, radius (Adult 10km / Minor 5km), size * 6)
            Store-->>DS: List<Neighbor(publicId, distanceMeters)>
        end
        DS->>Store: online(self.ageGroup, now - 60s, size * 6)
        Store-->>DS: List<String> onlineIds
        DS->>DS: Hợp nhất ứng viên = (nearby ∪ online) \ excluded
        opt Có ứng viên
            DS->>UG: profiles(candidateIds) (Lấy hồ sơ mới nhất để lọc active && discoverable && cùng ageGroup)
            DS->>Store: boosted(now)
            DS->>DS: Sắp xếp theo: (1) Đang Boost -> (2) Khoảng cách gần hơn -> (3) Đang Online -> (4) publicId
            DS->>LP: band(distanceMeters, isMinor) (Nếu chỉ online không có vị trí -> distanceBand = null)
        end
        DS-->>DC: CardsResponse(cards, degraded=false, swipesLeftToday)
        DC-->>Client: 200 OK (CardsResponse)
    end
```

---

### 2.3 Class `DiscoveryService` & `RemoteBillingGateway` — Quẹt Thẻ (`swipe`) & Kích hoạt `Boost`

```mermaid
sequenceDiagram
    autonumber
    actor Client as Mobile Client
    participant DC as DiscoveryController
    participant DS as DiscoveryService
    participant KV as KeyValueStore (Redis)
    participant Store as RedisDiscoveryStore
    participant UG as RemoteUserGateway (user-service)
    participant BG as RemoteBillingGateway (billing-service)

    Note over Client,UG: 1. Quẹt thẻ Trái / Phải (POST /api/v1/discovery/swipes)
    Client->>DC: POST /api/v1/discovery/swipes ({targetPublicId, direction})
    DC->>DS: swipe(me, target, direction)
    alt direction == LEFT (Bỏ qua)
        DS->>Store: recordLeft(me, target, now) (Ẩn trong 30 ngày)
        DS-->>DC: SwipeResponse("SKIPPED", swipesLeftToday)
        DC-->>Client: 200 OK
    else direction == RIGHT (Thích / Kết bạn)
        DS->>KV: increment("quota:swipe:" + me + ":" + YYYYMMDD, 30h)
        alt Vượt hạn mức ngày (Free: 30, Pro: 150)
            DS->>KV: decrement(key)
            DS-->>Client: 429 Too Many Requests (SWIPE_LIMIT)
        else Còn lượt quẹt phải
            DS->>UG: swipeRight(me, target) (POST /internal/swipes/right)
            alt user-service lỗi (Exception)
                DS->>KV: decrement(key) (Hoàn lại lượt quẹt cho người dùng)
                DS-->>Client: 503 Service Unavailable
            else Thành công
                UG-->>DS: result ("REQUESTED" | "MATCHED" | "BLOCKED" | "ALREADY_FRIENDS" | "ALREADY_REQUESTED")
                opt result thuộc [BLOCKED, ALREADY_FRIENDS, ALREADY_REQUESTED]
                    DS->>KV: decrement(key) (Không tính vào lượt quẹt hợp lệ)
                end
                opt result != BLOCKED
                    DS->>Store: recordRight(me, target, now)
                end
                DS-->>DC: SwipeResponse(result, swipesLeftToday)
                DC-->>Client: 200 OK (SwipeResponse)
            end
        end
    end

    Note over Client,BG: 2. Kích hoạt Boost nổi bật 30 phút (POST /api/v1/discovery/boost)
    Client->>DC: POST /api/v1/discovery/boost
    DC->>DS: boost(me)
    DS->>UG: profile(me) (Bắt buộc đang bật discoverable)
    DS->>BG: consumeBoost(me) (POST /internal/wallet/consume {publicId: me, item: "BOOST"})
    alt Ví không còn lượt BOOST (409/402)
        BG-->>DS: false
        DS-->>Client: 402 Payment Required (NO_BOOST)
    else Trừ 1 BOOST thành công
        BG-->>DS: true
        DS->>Store: boost(me, now + 30 minutes)
        DC-->>Client: 204 No Content
    end
```

