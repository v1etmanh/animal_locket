# 3. Kiến trúc tổng thể

Tài liệu này mô tả kiến trúc **như code đang làm**. Kế hoạch gốc nằm ở [ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md); chỗ nào code khác kế hoạch đều có ghi chú "Khác kế hoạch".

> Trạng thái: toàn bộ service đã có code và test đơn vị/tích hợp chạy bằng H2 + bộ nhớ. **Chưa** chạy cùng nhau trên hạ tầng thật (MySQL/PostgreSQL/Mongo/Redis/Kafka/MinIO/Keycloak). Xem [12-testing-strategy.md](12-testing-strategy.md) và [14-roadmap-risks.md](14-roadmap-risks.md).

## 3.1 Sơ đồ

```
                         Internet (HTTPS / WSS)
                                   │
                           ┌───────▼────────┐
                           │    Traefik     │  TLS, 80/443 — cổng công khai duy nhất
                           └───────┬────────┘
              files.<domain> ──────┼────────────► MinIO (presigned upload/download)
                                   │
                           ┌───────▼────────┐        ┌──────────────┐
                           │  API Gateway   │◄──────►│   Keycloak   │  (JWKS, đăng nhập OIDC)
                           │   :8080        │        └──────────────┘
                           │ JWT → IdentityFilter → X-Public-Id │
                           │ CircuitBreaker + RateLimiter (Redis)│
                           └───────┬────────┘
              lb:// (Eureka :8761) │      Config Server :8888 (native/Git)
   ┌──────────┬───────────┬────────┼─────────┬────────────┬────────────┐
   ▼          ▼           ▼        ▼         ▼            ▼            ▼
┌───────┐ ┌───────┐ ┌─────────┐ ┌──────────┐ ┌──────┐ ┌─────────┐ ┌──────────────┐
│ user  │ │ post  │ │ media   │ │discovery │ │ chat │ │ billing │ │ notification │
│ :8101 │ │ :8102 │ │ :8103   │ │ :8104    │ │:8105 │ │ :8106   │ │ :8107        │
└──┬────┘ └──┬────┘ └──┬──────┘ └────┬─────┘ └──┬───┘ └────┬────┘ └──────┬───────┘
   │MySQL    │MySQL+   │MySQL+       │Redis     │Mongo+    │PostgreSQL   │(không DB)
   │user_db  │Redis    │MinIO        │(GEO)     │Redis     │billing_db   │ FCM
   │         │post_db  │media_db     │          │pub/sub   │             │
   └─────────┴────┬────┴─────┬───────┴──────────┴──────────┴─────────────┘
                  │          │
              ┌───▼──────────▼───┐   PHOTO_UPLOADED     ┌─────────────────────┐
              │      Kafka       │ ───────────────────► │ face-worker (Python)│
              │ (KRaft, outbox)  │ ◄─────────────────── │ :8110 metrics       │
              └──────────────────┘   FACE_PROCESSED/    │ MinIO raw → public  │
                                     FACE_FAILED        └─────────────────────┘
   Prometheus ◄── /actuator/prometheus      Tempo ◄── OTLP traces      Loki ◄── logs  →  Grafana
```

## 3.2 Công nghệ

| Lớp                     | Công nghệ                                                   | Ghi chú                                                                                                                                   |
| ------------------------ | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Ngôn ngữ/Framework     | Java 17, Spring Boot 3.3.5, Spring Cloud 2023.0.3             | Maven đa module, parent pom ở gốc repo                                                                                                  |
| Service nghiệp vụ      | Spring MVC (servlet)                                          | Gateway dùng Spring Cloud Gateway (reactive)                                                                                              |
| Xác thực               | Keycloak (OIDC/JWT)                                           | Gateway **và** từng service đều kiểm tra JWT bằng JWKS                                                                         |
| Định tuyến/khám phá | Eureka + `lb://`                                            | Gateway, `RestClient` có `@LoadBalanced`                                                                                              |
| Cấu hình               | Spring Cloud Config (profile `native`)                      | `infra/config-repo/application.yml` dùng chung; mọi service có `optional:configserver` nên chạy được không cần Config Server |
| Chịu lỗi               | Resilience4j qua Spring Cloud CircuitBreaker                  | Xem 3.6                                                                                                                                    |
| Message broker           | Kafka (JSON String), KRaft                                    | Event nghiệp vụ + Outbox                                                                                                                 |
| DB quan hệ              | MySQL (user, media, post), PostgreSQL (billing, Keycloak)     | Flyway; `JPA_DDL_AUTO` mặc định `none` (MySQL, chờ kiểm chứng) / `validate` (billing)                                          |
| Document                 | MongoDB (chat)                                                | `conversations`, `messages`                                                                                                            |
| Cache/GEO/hạn mức      | Redis                                                         | Qua `KeyValueStore` (hạn mức, cache) và `RedisDiscoveryStore` (GEO, online)                                                         |
| Kho ảnh                 | MinIO (S3)                                                    | Bucket `raw` và `public`, đều private                                                                                               |
| Xử lý ảnh             | Python 3.12, Pillow, OpenCV 4.x, MinIO SDK, confluent-kafka   | `face-worker/`; AI inpainting tuỳ chọn (diffusers)                                                                                     |
| Quan sát                | Micrometer → Prometheus; OTLP → Tempo; log → Loki; Grafana | Xem [11-observability-resilience.md](11-observability-resilience.md)                                                                        |
| Push                     | Firebase Admin (FCM)                                          | Mặc định `LoggingPushSender` khi chưa có khoá                                                                                      |

### Cổng dịch vụ

| Thành phần                 | Cổng | Nguồn                                                    |
| ---------------------------- | ----- | --------------------------------------------------------- |
| api-gateway                  | 8080  | `infra/api-gateway/.../application.yml`                 |
| config-server                | 8888  | idem                                                      |
| eureka-server                | 8761  | idem                                                      |
| user-service                 | 8101  | `services/user-service/.../application.yml`             |
| post-service                 | 8102  | idem                                                      |
| media-service                | 8103  | idem                                                      |
| discovery-service            | 8104  | idem                                                      |
| chat-service                 | 8105  | idem                                                      |
| billing-service              | 8106  | quy ước (xem [04-service-specs.md](04-service-specs.md)) |
| notification-service         | 8107  | idem                                                      |
| face-worker (metrics/health) | 8110  | `face-worker/facework/config.py`                        |
| Keycloak                     | 8081  | mặc định trong `KEYCLOAK_JWK_URI`                    |

Hạ tầng (MySQL 3306, PostgreSQL 5432, MongoDB 27017, Redis 6379, MinIO 9000/9001, Kafka 9092, Prometheus 9090, Loki 3100, Tempo 3200/4318, Grafana 3000) xem [10-deployment-infrastructure.md](10-deployment-infrastructure.md).

## 3.3 Luồng một request có xác thực

```
Client ──Bearer JWT──► Traefik ──► Gateway
  1. Spring Security (WebFlux) kiểm tra JWT (jwk-set-uri Keycloak). Sai/hết hạn → 401.
  2. IdentityFilter (order -1):
       a. XOÁ mọi header X-Public-Id do client gửi (chống giả mạo).
       b. sub (JWT) → GET http://user-service/internal/identity/{sub}  (+ X-Internal-Token)
          cache Caffeine 5 phút, timeout 2 giây.
            • 200  → gắn X-Public-Id: <publicId>
            • 404  → KHÔNG gắn header (người dùng chưa đăng ký hồ sơ), KHÔNG cache
            • lỗi/timeout → 503 IDENTITY_UNAVAILABLE (fail closed, không cho đi tiếp ẩn danh)
  3. Route filters: CircuitBreaker (fallback), RequestRateLimiter (Redis; khoá = publicId hoặc IP).
  4. lb://<service> qua Eureka, timeout kết nối 2s / phản hồi 3s.
Service
  5. CommonAutoConfiguration: kiểm tra JWT LẦN NỮA (oauth2ResourceServer) — đường dẫn /internal/** thì
     kiểm tra header X-Internal-Token thay vì JWT.
  6. Controller đọc @RequestHeader("X-Public-Id"). Thiếu header → 403 PROFILE_REQUIRED
     (ApiExceptionHandler.MissingRequestHeaderException).
```

**Khác kế hoạch**: kế hoạch nói "gateway kiểm tra JWT, mỗi service kiểm tra lại quyền nghiệp vụ". Code cụ thể hoá: gateway biến `sub` → `publicId` và truyền bằng header; service **tin header này** vì chỉ gateway chạm được tới service trong mạng nội bộ. Service không đối chiếu `X-Public-Id` với `sub` trong JWT, nên **bắt buộc** mạng nội bộ không lộ ra ngoài (ADR-003, xem [15-adr.md](15-adr.md) và rủi ro trong [09-privacy-safety-security.md](09-privacy-safety-security.md)).

Ngoại lệ: `POST /api/v1/users/register` không cần `X-Public-Id`; user-service lấy `sub` trực tiếp từ JWT (`@AuthenticationPrincipal Jwt`). `/webhooks/**` công khai ở gateway (billing tự xác thực chữ ký của store).

## 3.4 Đồng bộ và bất đồng bộ

| Việc                                        | Cách                                                               | Chịu lỗi                                                                      |
| -------------------------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Client → Gateway → service                 | REST/WebSocket                                                      | Circuit breaker + timeout ở gateway                                            |
| post → user (danh sách bạn)               | REST nội bộ, cache Redis 45s + bản dự phòng 1 giờ             | Dùng cache cũ; không có cache thì 503 → feed trả rỗng `degraded=true` |
| post → user (hồ sơ hiển thị)            | REST nội bộ, cache Caffeine 5 phút                               | Fail soft: thiếu alias vẫn trả bài                                          |
| media → user (con vật chủ đạo)          | Bản sao `owner_animals` cập nhật bằng event; thiếu thì REST | REST lỗi → 503 (fail closed)                                                  |
| media/chat → user (quan hệ bạn bè)       | REST nội bộ                                                       | Fail closed                                                                     |
| discovery → user                            | REST nội bộ (hồ sơ, loại trừ, quẹt phải)                    | Quẹt: 503 và hoàn lượt; thẻ: trả rỗng `degraded=true`                 |
| discovery → billing (Boost)                 | REST nội bộ                                                       | 503 `BILLING_UNAVAILABLE`                                                     |
| chat → media (kiểm tra ảnh)               | REST nội bộ                                                       | 503                                                                             |
| Ảnh: upload → ẩn mặt → đăng           | Kafka (`PHOTO_UPLOADED` → `FACE_PROCESSED` → `PHOTO_READY`) | Retry/DLQ ở worker, timeout ở media-service                                   |
| Kết bạn, chặn, xoá tài khoản, gói Pro | Kafka (Outbox)                                                      | Consumer idempotent                                                             |
| Push                                         | Kafka → notification-service → FCM                                | Retry 3 lần rồi bỏ qua                                                       |
| Tin nhắn realtime                           | WebSocket + Redis pub/sub                                           | Xem 3.7                                                                         |

## 3.5 Outbox và idempotency

- Service có DB quan hệ (user, media, post, billing) ghi event vào bảng `outbox_events` **cùng transaction** với thay đổi dữ liệu (`OutboxService.publish`, `Propagation.MANDATORY`).
- `OutboxRelay` (`@Scheduled`, mặc định 500 ms) đọc 100 dòng chưa đẩy bằng `PESSIMISTIC_WRITE` + `SKIP LOCKED`, gửi Kafka (`acks=all`, idempotent producer), đánh dấu `published_at`. Dừng ở lỗi đầu tiên để giữ thứ tự. Dọn dòng đã đẩy sau 1 ngày.
- Consumer có DB dùng bảng `processed_events` qua `IdempotencyService.firstTime(eventId)` **trong cùng transaction** xử lý: lỗi thì dấu vết rollback và event được xử lý lại.
- Consumer không có DB (discovery, chat, notification) dùng thao tác tự idempotent; notification thêm cache Caffeine theo `eventId` (best-effort).
- chat-service phát `MESSAGE_SENT` **trực tiếp** bằng `KafkaTemplate`, không qua Outbox (push là fail-soft). **Khác kế hoạch** ("mọi event phát từ service có DB đi qua Outbox"): chat dùng MongoDB, chưa có outbox cho Mongo.
- face-worker không có DB, tự phát kết quả lên `media.results`.

Chi tiết topic và payload: [07-event-catalog.md](07-event-catalog.md).

## 3.6 Ma trận chịu lỗi (như đã cấu hình)

| Chỗ                      | Cơ chế                                                                                                         | Giá trị (theo `application.yml`/code)                                            |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Gateway → mọi service   | CircuitBreaker `default` + forward `/fallback/default` (503 problem+json)                                    | cửa sổ 20, tối thiểu 10 lời gọi, ngưỡng lỗi 50%, mở 10 giây, half-open 5  |
| Gateway → discovery      | CircuitBreaker `discovery` → `/fallback/discovery` trả `{"cards":[],"degraded":true}`                    | cùng cấu hình                                                                     |
| Gateway timeout           | `connect-timeout 2000`, `response-timeout 3s`                                                                |                                                                                      |
| Gateway rate limit        | `RequestRateLimiter` Redis, khoá = publicId hoặc IP                                                          | mặc định 20 req/s, burst 40; discovery 2 req/s, burst 10                          |
| Service → service        | `CircuitBreakerFactory.create("user-service" \| "media-service" \| "billing-service")`                           | cấu hình `resilience4j.*` như trên, time limiter 2–3s                         |
| Danh sách bạn (post)    | Cache tươi 45s + bản cũ 1h                                                                                   |                                                                                      |
| Hồ sơ hiển thị (post) | Caffeine 5 phút                                                                                                 | fail soft                                                                            |
| Push                      | Thread pool riêng (4–16 luồng, hàng đợi 5000, `DiscardPolicy`) + retry 3 lần, backoff `500ms × lần` | bulkhead tự cài                                                                    |
| face-worker               | Retry `MAX_ATTEMPTS=3`, backoff `1.5s × lần`, DLQ `media.events.dlq`                                     | AI timeout 45s                                                                       |
| media-service             | Job kẹt `UPLOADED` quá 10 phút → `REJECTED/PROCESSING_TIMEOUT`                                           |                                                                                      |
| Chat                      | Giới hạn 20 tin/10 giây/người                                                                               | Bulkhead Resilience4j **mới chỉ khai báo trong YAML**, chưa gắn vào code |

> Cần kiểm chứng khi chạy thật: các giá trị `resilience4j.circuitbreaker/timelimiter.configs.default` trong YAML có áp dụng cho `CircuitBreakerFactory` của Spring Cloud hay không. Nếu không, time limiter mặc định của Spring Cloud CircuitBreaker là **1 giây**, dễ gây lỗi giả. Cách chắc chắn: khai báo `Customizer<Resilience4JCircuitBreakerFactory>` trong từng service.

## 3.7 Chat nhiều instance

```
 Client A ──WS──► chat-1 ─┐                       ┌─► chat-1 ──WS──► Client A (thiết bị khác)
                           │  Redis PUBLISH       │
                           ├─► chat:user:{B} ─────┤
 Client B ──WS──► chat-2 ◄─┘  (PSUBSCRIBE chat:user:*) └─► chat-2 ──WS──► Client B
```

Mỗi instance `PSUBSCRIBE chat:user:*` một lần (`RedisMessageBus`) và chỉ chuyển cho phiên WebSocket **cục bộ** (`SessionRegistry`). Gửi tin: lưu MongoDB rồi publish tới **cả hai** người (người gửi cũng nhận để đồng bộ nhiều thiết bị). `animal.kv.type=memory` chuyển sang `LocalMessageBus` (một instance, dùng cho test).

## 3.8 Fail closed và fail soft (đối chiếu code)

| Nhóm                                        | Hành vi                                                                                        | Nơi trong code                                                                          |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Ẩn mặt                                     | **Closed**: ảnh chỉ `PUBLISHED` khi có `PHOTO_READY`; lỗi/timeout → `REJECTED` | `PostService.applyMedia`, `MediaService.onFaceFailed/expireStuck`, `Worker.handle` |
| Xác định người dùng                    | **Closed**: không tra được `sub` → 503                                             | `IdentityFilter`                                                                       |
| Xác minh quan hệ bạn bè (chat, xem ảnh) | **Closed**                                                                                | `ChatService.requireFriends`, `MediaService.viewUrl`                                 |
| Con vật chủ đạo khi upload               | **Closed** nếu cả bản sao lẫn REST đều thiếu                                       | `MediaService.complete`                                                                |
| Thanh toán/quyền lợi                      | **Closed**: chỉ mở quyền sau khi xác minh với store                                  | `billing-service` (xem 04)                                                             |
| Vị trí                                     | **Closed**: chỉ lưu khi bật khám phá; xác thực hồ sơ mới cho cập nhật         | `DiscoveryService.updateLocation`                                                      |
| Feed                                         | **Soft**: không biết danh sách bạn → trả rỗng `degraded`                         | `PostService.feed`                                                                     |
| Bộ thẻ                                     | **Soft**: lỗi hạ tầng → rỗng `degraded`                                            | `DiscoveryController.cards`                                                            |
| Hồ sơ hiển thị                           | **Soft**                                                                                  | `UserDirectory.profiles`                                                               |
| Push                                         | **Soft**: lỗi bỏ qua sau 3 lần                                                         | `NotificationDispatcher`                                                               |

## 3.9 Cấu trúc module

```
animal-locket/
├─ pom.xml                      parent (Spring Boot 3.3.5, Spring Cloud 2023.0.3)
├─ libs/
│  ├─ common/                   dùng cho mọi service servlet
│  │   Headers, Topics, EventTypes, PublicIds
│  │   event/  EventEnvelope, EventJson, Events (payload)
│  │   web/    ApiException, ApiExceptionHandler (RFC 7807), InternalTokenFilter
│  │   config/ CommonAutoConfiguration (SecurityFilterChain, bộ lọc nội bộ)
│  │   kv/     KeyValueStore + InMemory + Redis (+ tự cấu hình, animal.kv.type)
│  └─ outbox-jpa/               OutboxEvent/Repository/Service/Relay, ProcessedEvent, IdempotencyService
├─ infra/  config-server, eureka-server, api-gateway, config-repo/
├─ services/ user, media, post, notification, discovery, chat, billing
├─ face-worker/                 Python
└─ docs/
```

- `outbox-jpa` dùng `@AutoConfigurationPackage` để JPA của service tự quét entity/repository của outbox.
- `common` khai báo Redis là `optional`: service nào cần `KeyValueStore` Redis phải tự thêm `spring-boot-starter-data-redis` (post, discovery, chat đã có).
- Cấu hình `animal.security.enabled=false` tắt kiểm tra JWT (chỉ dùng cho test); `animal.security.public-paths` mở đường dẫn không cần JWT.
- Khoá gọi nội bộ: `animal.internal-token` (biến môi trường `INTERNAL_TOKEN`), mặc định `dev-internal-token` **chỉ dành cho dev**.

## 3.10 Nguyên tắc dữ liệu giữa các service

- Mỗi service sở hữu DB riêng; **không truy cập chéo**. Dev dùng 1 MySQL với 3 schema, nhưng user riêng cho từng service là khuyến nghị.
- Mọi tham chiếu chéo service là `publicId` (chuỗi 20 ký tự `[a-z2-7]`), **không có khoá ngoại giữa các DB**.
- Bản sao dữ liệu được cập nhật bằng event: `owner_animals` (media), `media_states` (post), `entitlements` (user), khoá Redis `pro:{id}` (post, discovery).
- Không DTO nào trả `sub`, email, ngày sinh, toạ độ (xem [09-privacy-safety-security.md](09-privacy-safety-security.md)).
