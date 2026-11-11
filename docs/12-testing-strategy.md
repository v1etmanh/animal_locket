# 12. Chiến lược kiểm thử

## 12.1 Hiện trạng: những gì đã có

Tất cả test Java chạy **không cần hạ tầng ngoài** (H2 chế độ MySQL/PostgreSQL, `KeyValueStore`/`DiscoveryStore` bộ nhớ, `LocalMessageBus`, Kafka listener tắt `auto-startup: false`, outbox relay tắt). Không còn test Python (face-worker đã gỡ).

| Module | Số test | Nội dung chính |
|---|---|---|
| `libs/common` | 12 | `PublicIds` (hợp lệ, duy nhất trên 5000 mẫu, từ chối sai định dạng); vòng khứ hồi `EventEnvelope`; `InMemoryKeyValueStore`; **`ResilienceAutoConfiguration`** (timeout cấu hình cắt lời gọi chậm, mạch mở sau lỗi lặp lại); **DLQ Kafka** (`<topic>.dlq`, cho phép service ghi đè) |
| `libs/outbox-jpa` | 5 | Hồi quy thứ tự auto-config: `OutboxRelay` phải được tạo khi có Kafka (đã chứng minh test thất bại khi bỏ `after = KafkaAutoConfiguration`), tắt relay bằng thuộc tính; `OutboxMetrics` (số dòng chờ, tuổi dòng cũ nhất) |
| `user-service` | 35 phương thức `@Test` (đếm trong mã) | `UserFlowIntegrationTest` (21, MockMvc + JWT giả, gồm đăng ký đồng thời 6 luồng, `FRIEND_REMOVED`, `DISCOVERY_DISABLED`): đăng ký idempotent và **không lộ `sub`/ngày sinh**; nhóm tuổi; thiếu `X-Public-Id`; match hai chiều và `FRIEND_ACCEPTED`; khác nhóm tuổi bị `403`; hạn mức lời mời; chấp nhận lời mời; chặn hai chiều + `USER_BLOCKED`; avatar hiển thị ở mọi nơi; spin/đổi con vật trả `410`; thư viện avatar phục vụ được và cache được; alias; xoá tài khoản + `USER_DELETED`; token nội bộ; `identity/{sub}`. `AvatarSpinIntegrationTest` (9): quay thêm vào bộ sưu tập mà không đổi avatar đang dùng, hết lượt `409`, cùng `eventId` không cộng hai lần, **kho cạn thì lượt quay không bị trừ**, quay song song không vượt số lượt, đổi avatar không sở hữu `400`, `avatarSpins` trong `/users/me`, xoá tài khoản xoá số dư. `AvatarAllocationIntegrationTest` (8): kho v1 đủ 3.000 avatar, đăng ký đồng thời không trùng avatar, avatar cuối cùng chỉ một người nhận, rollback trả avatar về kho, backfill tài khoản cũ idempotent, xoá tài khoản giữ avatar. `DevBuddyIntegrationTest` (2). `AnimalCatalogTest` (4) |
| `media-service` | 12 (+1 gated) | `MediaFlowIntegrationTest` (10): loại file/kích thước, `complete` thiếu object `409`, người khác không chạm được upload của mình, đường đi đầy đủ upload → `complete` → `READY` + `PHOTO_READY` → xem URL, người lạ/bị chặn không xem được, object quá cỡ hoặc sai `Content-Type` lúc `complete` bị `REJECTED` và xoá, job bỏ dở bị xoá, xoá tài khoản, rate limit upload. `S3PresignTest` (2): URL PUT ký sẵn. `S3ObjectStorageLiveTest` (1) chạy với R2 thật, chỉ khi đặt `R2_ENDPOINT` |
| `post-service` | 21 | Thêm so với trước: `PendingPostReconciler` gỡ bài thua cuộc đua với `PHOTO_READY`, `PHOTO_READY` đến muộn sai chủ ảnh → `REJECTED`. Phần còn lại: test tích hợp (bài chờ → `PUBLISHED` khi `PHOTO_READY`, `PHOTO_READY` đến trước, từ chối, ảnh của người khác, người lạ không xem/like/bình luận được, like/bình luận + event, chỉ tác giả xoá, feed fail soft, phân trang, xoá tài khoản, sự kiện trùng, ảnh chat bị bỏ qua) + 5 test `QuotaService` |
| `notification-service` | 10 | Kế hoạch thông báo (fan-out cho bạn bè, hai bên khi thành bạn, nội dung không lộ danh tính), retry/backoff, bỏ sau 3 lần, token chết bị gỡ, lỗi directory nuốt êm, khử trùng lặp, context nạp với `LoggingPushSender` |
| `discovery-service` | 35 (+8 gated) | `LocationPrivacyTest` (10): ô lưới, sai số, **không lộ vị trí mịn hơn ô**, offset ổn định theo người, mức khoảng cách (người dưới 18 thô hơn), khoá yếu, cực/đường đổi ngày. `DiscoveryServiceTest` (17): bộ thẻ lọc đúng (bạn, chặn, ẩn, khác nhóm tuổi, ngoài bán kính), thẻ không có toạ độ, nhóm tuổi, bán kính, Boost, quẹt trái/phải, hạn mức và hoàn lượt, TTL vị trí, presence chỉ cho bạn bè, rate limit, Pro. `InMemoryDiscoveryStoreTest` (8) chạy bộ **hợp đồng** `DiscoveryStoreContractTest`; `RedisDiscoveryStoreTest` (8) chạy cùng bộ hợp đồng nhưng chỉ khi đặt `REDIS_TEST_HOST` |
| `chat-service` | 48 (+7 gated) | **Glyph chat**: `GlyphServiceTest` (25: kiểm tra điểm và chuẩn hoá hình, trùng hình bị từ chối tới khi archive, hạn mức active/hội thoại và tạo/ngày, revision tăng dần kể cả khi va chạm hay tạo đồng thời, đồng bộ delta và client offline khôi phục từ điển, tạo idempotent theo `clientMutationId`, archive chỉ chủ glyph, tin glyph giữ thứ tự và có text dự phòng, gửi lại cùng `clientId` không nhân đôi, chặn/huỷ kết bạn dừng ghi, xoá tài khoản, cờ rollback tắt ghi), `GlyphApiTest` (5), `GlyphMongoIntegrationTest` (5, Testcontainers, tự bỏ qua khi không có Docker). `ChatServiceTest` (20) với repository giả lập: mở hội thoại cần bạn bè, gửi/nhận/phân trang/chưa đọc, người lạ 404, kiểm tra văn bản, chặn đóng hội thoại và báo hai đầu, mở lại, cache quan hệ, huỷ kết bạn đóng hội thoại, không push khi người nhận đang kết nối, rate limit, ảnh (sở hữu, ngữ cảnh, đã `READY`), xoá tài khoản, **WebSocket đầu-cuối hai client** (ack, error, ping, khung quá lớn), bắt tay không có `publicId`. `ChatMongoIntegrationTest` dùng Testcontainers MongoDB, **tự bỏ qua khi không có Docker** |
| `billing-service` | 186 phương thức `@Test` (đếm trong mã, chưa chạy lại) | **Thanh toán web (80)**: `CheckoutFlowIntegrationTest` (18), `PayOsCheckoutIntegrationTest` (25), `PayPalWebhookIntegrationTest` (15), `HttpPayPalClientTest` (8), `HttpPayOsClientTest` (8), `PayOsSignatureTest` (6, đối chiếu dữ liệu mẫu chính thức của payOS) — đều dùng HTTP giả. **88 test cho cổng Apple/Google** (chuỗi chứng chỉ giả dựng bằng BouncyCastle: hợp lệ, bị sửa, sai thuật toán, gốc không tin cậy, chứng chỉ hết hạn; gateway Apple/Google; webhook: khử trùng lặp, chữ ký sai → 401, lỗi xử lý → 5xx và hoàn tác dấu đã nhận; Google chỉ tin trạng thái hỏi lại từ Play). **21 test lõi**: danh mục, cấp Pro + event một lần, một lượt quay avatar cho mỗi kỳ thuê bao (gửi lại biên lai/webhook cùng kỳ không cấp thêm, gia hạn thì cấp thêm, không cộng vào ví), biên lai/chuỗi thuê bao không dùng chung được giữa hai tài khoản, ví và sổ cái, `consume` nguyên tử không âm, biên lai không hợp lệ không cấp gì, hết hạn, gia hạn/kết thúc, nhiều thuê bao, hoàn tiền, hạ cấp sau thời gian ân hạn, khử trùng lặp webhook, xoá tài khoản, endpoint cần JWT + hồ sơ |
| `api-gateway` | 14 | `IdentityFilter` (xoá `X-Public-Id` do client gửi, gắn id thật từ JWT, cache, chưa có hồ sơ vẫn đi tiếp, user-service lỗi → **503 fail closed**), khoá rate limit (theo `publicId`, theo `X-Forwarded-For` sau Traefik, chống giả mạo chuỗi) |
| `config-server` | 3 | Phục vụ `config-repo` cho client có Basic auth, từ chối ẩn danh/sai mật khẩu, `/actuator/health` công khai |
| `eureka-server` | 0 | Chưa có test |

> Số liệu tổng lấy từ một lần chạy `mvn -B install` **trước khi** gỡ face-worker và thêm avatar/glyph/billing web (lúc đó: 261 test Java chạy, 0 lỗi, 9 bỏ qua vì cần Redis/Docker). Riêng dòng `media-service` đã đếm lại theo code hiện tại; các dòng khác **cần chạy lại để cập nhật**. Cập nhật bảng này khi thêm test.

## 12.2 Cách chạy

```bash
# Toàn bộ Java (JDK 17, Maven 3.9; lần đầu cần Internet để tải thư viện)
mvn -B install

# Một module (kèm module phụ thuộc)
mvn -B -pl services/post-service -am install

# Test R2 thật của media-service (tự bỏ qua nếu không đặt R2_ENDPOINT)
R2_ENDPOINT=... R2_ACCESS_KEY=... R2_SECRET_KEY=... R2_BUCKET=... mvn -B -pl services/media-service test

# Bản Redis của bộ hợp đồng discovery (cần Docker)
docker run -d -p 6379:6379 redis:7
REDIS_TEST_HOST=localhost mvn -B -pl services/discovery-service test

# Test Mongo thật của chat (Testcontainers tự khởi động container; tự bỏ qua nếu không có Docker)
mvn -B -pl services/chat-service test
```

Báo cáo: `services/<tên>/target/surefire-reports/*.txt`. Lưu ý: maven-surefire mặc định **bỏ qua lớp lồng nhau** (`Outer$Inner`), vì vậy các lớp test phải là lớp cấp cao nhất.

## 12.3 Kim tự tháp kiểm thử và nguyên tắc

```
            ▲  E2E / hợp đồng với hạ tầng thật (Docker Compose)     ← CHƯA CÓ
           ╱ ╲
          ╱   ╲  Tích hợp service (Spring context + H2 + MockMvc)   ← đã có cho 5/7 service
         ╱     ╲
        ╱       ╲ Đơn vị / logic thuần (privacy, quota, store, pipeline) ← nhiều
```

Quy ước đang dùng:
- Dữ liệu test dùng chung context Spring nên **dọn DB trong `@BeforeEach`** (đã gặp lỗi do hạn mức/dữ liệu rò rỉ giữa test).
- Ranh giới mạng (user-service, media-service, billing, FCM, R2) giả lập qua interface (`Gateways.*`, `ObjectStorage`, `DeviceDirectory`, `PushSender`) hoặc `@MockBean`.
- Mỗi quy tắc riêng tư/an toàn có test khẳng định **âm** (người lạ không thấy, người bị chặn không thấy, DTO không có trường nhạy cảm).

## 12.4 Những gì CHƯA được kiểm chứng

| Hạng mục | Rủi ro nếu bỏ qua |
|---|---|
| MySQL thật + Flyway + `ddl-auto: validate` (kiểu `ENUM`, `BIT`, `DATETIME(6)`, `TEXT`) | Service không khởi động hoặc sai kiểu cột; hiện mặc định `JPA_DDL_AUTO=none` cho user/media/post |
| PostgreSQL thật (billing), `SKIP LOCKED` ở outbox, `CHECK balance >= 0` | Sai khác với H2 |
| Kafka thật: tạo topic, serialization, `OutboxRelay`, consumer group, offset | Event không chảy; đường ảnh đầu-cuối chưa chạy |
| Redis thật: GEO (`GEOSEARCH`), ZSET, pub/sub, rate limiter của gateway, `RedisKeyValueStore` | Bản Redis của `DiscoveryStore` chưa chạy test hợp đồng |
| Cloudflare R2 thật: presigned PUT/GET, `statObject` (cỡ, `Content-Type`), xoá object | Upload hoặc `complete` thất bại; có sẵn `S3ObjectStorageLiveTest` nhưng chưa chạy |
| Keycloak: realm, client, JWKS, `X-Public-Id`/`sub`, Admin API xoá user | Đăng nhập, `IdentityFilter` |
| Gateway: JWT, `IdentityFilter`, circuit breaker, rate limiter, WebSocket qua gateway | Chưa có test nào |
| Docker Compose cả hệ thống, Traefik, healthcheck | |
| Client xoá EXIF/GPS (`ImagePreparationService`) trên thiết bị thật, kể cả HEIC | Server không kiểm tra EXIF; client lỗi là lộ vị trí |
| Xác thực với Apple/Google thật; chữ ký webhook | Chỉ có thể kiểm tra bằng khoá/sandbox thật |
| Hiệu năng/tải, độ bền (soak), chaos | |
| Cấu hình `resilience4j.*` có áp dụng cho `CircuitBreakerFactory` | Xem 11.4 |

## 12.5 Kiểm thử tiếp theo nên làm

1. **Smoke E2E bằng Docker Compose** (kịch bản vàng): đăng ký 2 người → bật khám phá → quẹt thẻ → match → upload ảnh → nhận `PUBLISHED` → bạn bè xem được → chat → chặn → hội thoại đóng → xoá tài khoản. Tự động hoá bằng script (HTTP + WebSocket client).
2. **Test với Testcontainers** (MySQL, PostgreSQL, Kafka, Redis) cho từng service: Flyway + `validate`, Outbox → Kafka → consumer, GEOSEARCH.
3. **Hợp đồng sự kiện**: một bộ envelope mẫu (JSON) cho mọi `type`, dùng chung cho test producer/consumer của mọi service.
4. **Test gateway** (`WebTestClient` + Keycloak giả): chống giả mạo `X-Public-Id` (header client gửi bị xoá), 404 → không gắn header, lỗi user-service → 503, rate limit, fallback.
5. **Test bảo mật tự động** (OWASP ZAP/Schemathesis hoặc bộ test riêng): IDOR (đổi id bài/ảnh/hội thoại/job), thiếu/sai JWT, `/internal/**` không token, `/actuator` qua Traefik, WebSocket không token, payload quá lớn, injection trong alias/caption.
6. **Tải (k6)**: kịch bản — feed 1k VU, quẹt thẻ, chat WebSocket 5k kết nối, upload ảnh 50/giây. Mục tiêu theo SLO ở [11-observability-resilience.md](11-observability-resilience.md).
7. **Chaos**: dừng Kafka/Redis/user-service và chặn R2, kiểm tra đúng chính sách fail closed/soft ([03-architecture.md](03-architecture.md) mục 3.8).
8. **Mutation/property test** cho `LocationPrivacy` và hạn mức theo ngày (đổi múi giờ/giao thừa).
9. **Kiểm tra EXIF**: ảnh client gửi lên R2 không còn EXIF/GPS (JPEG, PNG, HEIC) — điều kiện trước khi ra mắt, vì server không kiểm tra.
10. **Kiểm thử client** (mobile): luồng upload presigned PUT, xử lý `503/degraded`, WebSocket reconnect.

## 12.6 Tiêu chí hoàn thành cho một thay đổi

- Có test cho hành vi mới **và** test âm (quyền/riêng tư) nếu chạm dữ liệu người dùng.
- `mvn -B install` xanh (và `flutter test` nếu chạm `mobile/`).
- Không thêm trường nhạy cảm vào DTO; không thêm đường `/internal/**` ra gateway.
- Cập nhật tài liệu liên quan ([06-api-reference.md](06-api-reference.md), [07-event-catalog.md](07-event-catalog.md)).
