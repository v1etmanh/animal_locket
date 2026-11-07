# 12. Chiến lược kiểm thử

## 12.1 Hiện trạng: những gì đã có

Tất cả test Java chạy **không cần hạ tầng ngoài** (H2 chế độ MySQL/PostgreSQL, `KeyValueStore`/`DiscoveryStore` bộ nhớ, `LocalMessageBus`, Kafka listener tắt `auto-startup: false`, outbox relay tắt). Test Python cũng không cần Kafka/MinIO/GPU.

| Module | Số test | Nội dung chính |
|---|---|---|
| `libs/common` | 12 | `PublicIds` (hợp lệ, duy nhất trên 5000 mẫu, từ chối sai định dạng); vòng khứ hồi `EventEnvelope`; `InMemoryKeyValueStore`; **`ResilienceAutoConfiguration`** (timeout cấu hình cắt lời gọi chậm, mạch mở sau lỗi lặp lại); **DLQ Kafka** (`<topic>.dlq`, cho phép service ghi đè) |
| `libs/outbox-jpa` | 3 | Hồi quy thứ tự auto-config: `OutboxRelay` phải được tạo khi có Kafka (đã chứng minh test thất bại khi bỏ `after = KafkaAutoConfiguration`) |
| `user-service` | 24 | 20 test tích hợp MockMvc + JWT giả (gồm đăng ký đồng thời 6 luồng, `FRIEND_REMOVED`, `DISCOVERY_DISABLED`): đăng ký idempotent và **không lộ `sub`/ngày sinh**; nhóm tuổi; thiếu `X-Public-Id`; match hai chiều và `FRIEND_ACCEPTED`; khác nhóm tuổi bị `403`; hạn mức lời mời; chấp nhận lời mời; chặn hai chiều + `USER_BLOCKED`; Pro/đổi con vật; quay thưởng + cooldown; alias; xoá tài khoản + `USER_DELETED`; token nội bộ; `identity/{sub}`. 4 test `AnimalCatalog`/`AliasPolicy` |
| `media-service` | 11 | 9 test tích hợp (loại file/kích thước, `complete` thiếu object `409`, chủ ảnh, đường đi đầy đủ upload → `PHOTO_UPLOADED` → `FACE_PROCESSED` → `READY` → xem URL, người lạ/bị chặn không xem được, `FACE_FAILED` xoá raw, job kẹt bị từ chối, xoá tài khoản, rate limit upload) + 2 test **hợp đồng Python ↔ Java** (`FaceWorkerContractTest`: Jackson đọc được chuỗi do `facework.worker.envelope()` sinh ra, kể cả định dạng thời gian `+00:00`) |
| `post-service` | 18 | 13 test tích hợp (bài chờ → `PUBLISHED` khi `PHOTO_READY`, `PHOTO_READY` đến trước, từ chối, ảnh của người khác, người lạ không xem/like/bình luận được, like/bình luận + event, chỉ tác giả xoá, feed fail soft, phân trang, xoá tài khoản, sự kiện trùng, ảnh chat bị bỏ qua) + 5 test `QuotaService` |
| `notification-service` | 10 | Kế hoạch thông báo (fan-out cho bạn bè, hai bên khi thành bạn, nội dung không lộ danh tính), retry/backoff, bỏ sau 3 lần, token chết bị gỡ, lỗi directory nuốt êm, khử trùng lặp, context nạp với `LoggingPushSender` |
| `discovery-service` | 35 (+8 gated) | `LocationPrivacyTest` (10): ô lưới, sai số, **không lộ vị trí mịn hơn ô**, offset ổn định theo người, mức khoảng cách (người dưới 18 thô hơn), khoá yếu, cực/đường đổi ngày. `DiscoveryServiceTest` (17): bộ thẻ lọc đúng (bạn, chặn, ẩn, khác nhóm tuổi, ngoài bán kính), thẻ không có toạ độ, nhóm tuổi, bán kính, Boost, quẹt trái/phải, hạn mức và hoàn lượt, TTL vị trí, presence chỉ cho bạn bè, rate limit, Pro. `InMemoryDiscoveryStoreTest` (8) chạy bộ **hợp đồng** `DiscoveryStoreContractTest`; `RedisDiscoveryStoreTest` (8) chạy cùng bộ hợp đồng nhưng chỉ khi đặt `REDIS_TEST_HOST` |
| `chat-service` | 19 (+1 gated) | `ChatServiceTest` với repository giả lập: mở hội thoại cần bạn bè, gửi/nhận/phân trang/chưa đọc, người lạ 404, kiểm tra văn bản, chặn đóng hội thoại và báo hai đầu, mở lại, cache quan hệ, huỷ kết bạn đóng hội thoại, không push khi người nhận đang kết nối, rate limit, ảnh (sở hữu, ngữ cảnh, đã `READY`), xoá tài khoản, **WebSocket đầu-cuối hai client** (ack, error, ping, khung quá lớn), bắt tay không có `publicId`. `ChatMongoIntegrationTest` dùng Testcontainers MongoDB, **tự bỏ qua khi không có Docker** |
| `billing-service` | 106 | **88 test cho cổng Apple/Google** (chuỗi chứng chỉ giả dựng bằng BouncyCastle: hợp lệ, bị sửa, sai thuật toán, gốc không tin cậy, chứng chỉ hết hạn; gateway Apple/Google; webhook: khử trùng lặp, chữ ký sai → 401, lỗi xử lý → 5xx và hoàn tác dấu đã nhận; Google chỉ tin trạng thái hỏi lại từ Play). **18 test lõi**: danh mục, cấp Pro + event một lần, biên lai/chuỗi thuê bao không dùng chung được giữa hai tài khoản, ví và sổ cái, `consume` nguyên tử không âm, biên lai không hợp lệ không cấp gì, hết hạn, gia hạn/kết thúc, nhiều thuê bao, hoàn tiền, hạ cấp sau thời gian ân hạn, khử trùng lặp webhook, xoá tài khoản, endpoint cần JWT + hồ sơ |
| `face-worker` (pytest) | 33 | Xoá EXIF/GPS + áp hướng xoay; ảnh không mặt; sticker che **kín cả góc** (hộp ở mép, hộp dẹt/cao); nhiều mặt; chính sách mặt người khác; ảnh hỏng/bomb/quá lớn/PNG alpha; hợp nhất hộp; Haar không lỗi; 25 sticker; AI giả (thành công, không đổi, lỗi, timeout → sticker); worker: thành công, ảnh không mặt, retry rồi DLQ, hồi phục lỗi tạm thời, ảnh hỏng không retry, raw mất, giao lại sau crash, JSON hỏng, xoá raw lỗi; **ảnh HEIC** |
| `api-gateway` | 11 | `IdentityFilter` (xoá `X-Public-Id` do client gửi, gắn id thật từ JWT, cache, chưa có hồ sơ vẫn đi tiếp, user-service lỗi → **503 fail closed**), khoá rate limit (theo `publicId`, theo `X-Forwarded-For` sau Traefik, chống giả mạo chuỗi) |
| `config-server` | 3 | Phục vụ `config-repo` cho client có Basic auth, từ chối ẩn danh/sai mật khẩu, `/actuator/health` công khai |
| `eureka-server` | 0 | Chưa có test |

> Số liệu lấy từ lần chạy `mvn -B install` toàn bộ (BUILD SUCCESS: **261 test Java chạy, 0 lỗi, 9 bỏ qua** vì cần Redis/Docker) và `pytest` (33 đạt). Cập nhật bảng này khi thêm test.

## 12.2 Cách chạy

```bash
# Toàn bộ Java (JDK 17, Maven 3.9; lần đầu cần Internet để tải thư viện)
mvn -B install

# Một module (kèm module phụ thuộc)
mvn -B -pl services/post-service -am install

# face-worker
cd face-worker
python -m venv .venv
.venv/Scripts/pip install -r requirements-dev.txt     # Linux/macOS: .venv/bin/pip
.venv/Scripts/python -m pytest -q

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
- Ranh giới mạng (user-service, media-service, billing, FCM, MinIO) giả lập qua interface (`Gateways.*`, `ObjectStorage`, `DeviceDirectory`, `PushSender`) hoặc `@MockBean`.
- Mỗi quy tắc riêng tư/an toàn có test khẳng định **âm** (người lạ không thấy, người bị chặn không thấy, DTO không có trường nhạy cảm).
- Hợp đồng giữa hai ngôn ngữ (Python ↔ Java) có test dùng chuỗi do code Python thật sinh ra.

## 12.4 Những gì CHƯA được kiểm chứng

| Hạng mục | Rủi ro nếu bỏ qua |
|---|---|
| MySQL thật + Flyway + `ddl-auto: validate` (kiểu `ENUM`, `BIT`, `DATETIME(6)`, `TEXT`) | Service không khởi động hoặc sai kiểu cột; hiện mặc định `JPA_DDL_AUTO=none` cho user/media/post |
| PostgreSQL thật (billing), `SKIP LOCKED` ở outbox, `CHECK balance >= 0` | Sai khác với H2 |
| Kafka thật: tạo topic, serialization, `OutboxRelay`, consumer group, offset | Event không chảy; đường ảnh đầu-cuối chưa chạy |
| Redis thật: GEO (`GEOSEARCH`), ZSET, pub/sub, rate limiter của gateway, `RedisKeyValueStore` | Bản Redis của `DiscoveryStore` chưa chạy test hợp đồng |
| MinIO thật: POST policy, ký URL theo `public-endpoint`, tạo bucket, `statObject` | Upload thất bại do chữ ký/host không khớp |
| Keycloak: realm, client, JWKS, `X-Public-Id`/`sub`, Admin API xoá user | Đăng nhập, `IdentityFilter` |
| Gateway: JWT, `IdentityFilter`, circuit breaker, rate limiter, WebSocket qua gateway | Chưa có test nào |
| Docker Compose cả hệ thống, Traefik, healthcheck | |
| face-worker với Kafka/MinIO thật; **ảnh có mặt thật**; HEIC; AI inpainting (GPU) | Chất lượng ẩn mặt chưa đo |
| Xác thực với Apple/Google thật; chữ ký webhook | Chỉ có thể kiểm tra bằng khoá/sandbox thật |
| Hiệu năng/tải, độ bền (soak), chaos | |
| Cấu hình `resilience4j.*` có áp dụng cho `CircuitBreakerFactory` | Xem 11.4 |

## 12.5 Kiểm thử tiếp theo nên làm

1. **Smoke E2E bằng Docker Compose** (kịch bản vàng): đăng ký 2 người → bật khám phá → quẹt thẻ → match → upload ảnh có mặt → nhận `PUBLISHED` → bạn bè xem được → chat → chặn → hội thoại đóng → xoá tài khoản. Tự động hoá bằng script (HTTP + WebSocket client).
2. **Test với Testcontainers** (MySQL, PostgreSQL, Kafka, Redis, MinIO) cho từng service: Flyway + `validate`, Outbox → Kafka → consumer, GEOSEARCH, POST policy.
3. **Hợp đồng sự kiện**: một bộ envelope mẫu (JSON) cho mọi `type`, dùng chung cho test producer/consumer của mọi service (mở rộng ý tưởng `FaceWorkerContractTest`).
4. **Test gateway** (`WebTestClient` + Keycloak giả): chống giả mạo `X-Public-Id` (header client gửi bị xoá), 404 → không gắn header, lỗi user-service → 503, rate limit, fallback.
5. **Test bảo mật tự động** (OWASP ZAP/Schemathesis hoặc bộ test riêng): IDOR (đổi id bài/ảnh/hội thoại/job), thiếu/sai JWT, `/internal/**` không token, `/actuator` qua Traefik, WebSocket không token, payload quá lớn, injection trong alias/caption.
6. **Tải (k6)**: kịch bản — feed 1k VU, quẹt thẻ, chat WebSocket 5k kết nối, upload ảnh 50/giây. Mục tiêu theo SLO ở [11-observability-resilience.md](11-observability-resilience.md); đo `facework_duration_seconds` để tính chi phí GPU.
7. **Chaos**: dừng Kafka/Redis/user-service/face-worker và kiểm tra đúng chính sách fail closed/soft ([03-architecture.md](03-architecture.md) mục 3.8).
8. **Mutation/property test** cho `LocationPrivacy` và hạn mức theo ngày (đổi múi giờ/giao thừa).
9. **Đo chất lượng ẩn mặt** bằng `tools/evaluate.py` trên bộ ảnh gán nhãn ([08-face-anonymization-pipeline.md](08-face-anonymization-pipeline.md) mục 8.7) — điều kiện bắt buộc trước khi ra mắt (miss rate < 1%, EXIF = 0).
10. **Kiểm thử client** (mobile): luồng upload POST policy, xử lý `503/degraded`, WebSocket reconnect.

## 12.6 Tiêu chí hoàn thành cho một thay đổi

- Có test cho hành vi mới **và** test âm (quyền/riêng tư) nếu chạm dữ liệu người dùng.
- `mvn -B install` và `pytest` đều xanh.
- Không thêm trường nhạy cảm vào DTO; không thêm đường `/internal/**` ra gateway.
- Cập nhật tài liệu liên quan ([06-api-reference.md](06-api-reference.md), [07-event-catalog.md](07-event-catalog.md)).
