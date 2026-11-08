# 14. Lộ trình, rủi ro và việc còn lại

Chú giải trạng thái:
- ✅ **Xong + có test** (chạy xanh với H2/bộ nhớ, chưa gặp hạ tầng thật)
- 🟡 **Có code, chưa kiểm chứng** với hạ tầng/dịch vụ thật
- ⬜ **Chưa làm**

## 14.1 Lộ trình theo giai đoạn (đối chiếu thứ tự dựng ở kế hoạch gốc)

| # | Giai đoạn | Trạng thái | Chi tiết |
|---|---|---|---|
| 0 | ~~Spike ẩn mặt~~ | — | **Đã bỏ** (ADR-014): face-worker gỡ khỏi repo; ẩn danh dựa trên alias + avatar con vật duy nhất ([19-avatar-mechanism.md](19-avatar-mechanism.md)); client tự xoá EXIF |
| 1 | Hạ tầng lõi (Config, Eureka, Gateway, Keycloak, Traefik) | 🟡 | Code config/eureka/gateway biên dịch được, **không có test**; file realm Keycloak và cấu hình Traefik nằm trong `deploy/` (nhánh hạ tầng) |
| 2 | user-service | ✅ | Đăng ký ẩn danh, bạn bè, quẹt (nội bộ), chặn, báo cáo, con vật, quay thưởng, thiết bị, xoá tài khoản. 21 test. 🟡 MySQL/Flyway/Keycloak Admin thật chưa chạy |
| 3 | Kafka + Outbox + R2 + media-service | 🟡 | Outbox/idempotency ✅ (test qua H2); media-service 12 test (presigned PUT, kiểm tra lại cỡ/`Content-Type` lúc `complete`). 🟡 Kafka thật; **R2 thật chưa chạy** (`S3ObjectStorageLiveTest` gated `R2_ENDPOINT`) |
| 4 | post-service + feed | ✅ | 18 test. 🟡 MySQL/Redis thật |
| 5 | notification-service | ✅ | 10 test. 🟡 FCM thật chưa thử; ⬜ tuỳ chọn tắt từng loại thông báo |
| 6 | discovery-service | ✅ | 32 test + hợp đồng store. 🟡 Redis GEO thật chưa chạy (test Redis đã viết, gated `REDIS_TEST_HOST`) |
| 7 | chat-service | ✅ | 17 test (repository giả lập, WebSocket đầu-cuối). 🟡 MongoDB/Redis pub/sub thật chưa chạy (1 test Testcontainers chờ Docker) |
| 8 | billing-service | 🟡 | Danh mục, ví, sổ cái, thuê bao, xác thực biên lai qua `StoreGateway` (+ `DevStoreGateway`), hoàn tiền, ân hạn, xoá tài khoản; 18 test. Có `AppleJwsVerifier` (PKIX + ES256). ⬜ Cổng Apple/Google gọi API store thật và **endpoint webhook** chưa có trong code lúc viết; ⬜ chưa thử với sandbox |
| 9 | Resilience4j tinh chỉnh + Grafana stack | 🟡 | Cấu hình có, `deploy/observability` có; ⬜ chưa kiểm chứng áp dụng cấu hình; ✅ metric `outbox_pending`/`outbox_oldest_pending_age_seconds` + cảnh báo `OutboxStuck`/`OutboxBacklogHigh` (có test); ⬜ chưa có metric nghiệp vụ |
| — | Docker Compose cả hệ thống | 🟡/⬜ | Do nhánh hạ tầng viết; `docker compose config` hợp lệ với `.env.example`; ✅ **đã `up` thật (6/11/2026)**: `core` + `app` đều healthy (22 container), Flyway tạo bảng trên MySQL, Keycloak import realm, Kafka/MinIO init chạy. Đã sửa: MinIO không còn image công khai, quyền `/data`, cổng 80 bị Windows chặn (dùng `HTTP_PORT=8080`), `billing-service` lỗi bind `resilience4j ... : {}`. ✅ **luồng ảnh đầu-cuối chạy thật** (Keycloak code+PKCE → gateway → register → ticket → POST MinIO → complete → face-worker → URL tải ảnh; ảnh có mặt bị che bằng sticker, ảnh không mặt giữ nguyên). Lỗi tìm ra và đã sửa: gateway 500 với mọi JWT (`ReadOnlyHttpHeaders`), ticket upload thiếu `key`/`Content-Type`. ⬜ chưa thử `obs`, `validate`. **Sau lần chạy đó** kiến trúc đã đổi: bỏ MinIO/face-worker, chuyển ảnh sang R2, DB chuyển sang dịch vụ ngoài (Aiven/Supabase/Atlas) — luồng ảnh mới **chưa chạy đầu-cuối** |
| — | Admin/moderation | ⬜ | Không có console, không có kiểm duyệt ảnh/chữ tự động |
| — | Mobile client (Flutter, `mobile/`) | 🟡 | Có trong repo: đăng nhập Keycloak, camera/đăng ảnh, feed, bạn bè, khám phá, chat (kể cả glyph offline), hồ sơ, thanh toán, avatar. Có `flutter test`; xem [17](17-flutter-app-requirements.md), [18](18-mobile-integration-brief.md) |

**Đề xuất thứ tự tiếp theo**
1. Có Docker → chạy checklist 14.5 (một ngày): bật `validate`, đường ảnh đầu-cuối, gateway/Keycloak.
2. Chạy luồng ảnh với R2 thật (`S3ObjectStorageLiveTest` + app trên điện thoại); kiểm tra ảnh trên R2 không còn EXIF/GPS.
3. Hoàn tất billing (webhook + store thật + sandbox).
4. Moderation tối thiểu (NSFW ảnh + từ cấm) và công cụ xử lý báo cáo — điều kiện lên cửa hàng.
5. Backlog kỹ thuật 14.4.

## 14.2 Đăng ký rủi ro

Xác suất/ảnh hưởng: T = thấp, TB = trung bình, C = cao.

| ID | Rủi ro | XS | ẢH | Giảm thiểu |
|---|---|---|---|---|
| R1 | **Khuôn mặt thật hiển thị trong ảnh** (không còn ẩn mặt, ADR-014) → bạn bè nhận ra danh tính người đăng hoặc người khác trong ảnh | C | Cao (khác lời hứa "ẩn danh" cũ) | Nói rõ trong app rằng ảnh hiện nguyên bản; chỉ bạn bè xem; cân nhắc làm mờ mặt phía client nếu cần lại |
| R2 | **EXIF/GPS chỉ được xoá ở client**; client sửa đổi hoặc lỗi nén có thể gửi ảnh kèm vị trí | TB | Cao | Kiểm tra trên thiết bị thật (JPEG/PNG/HEIC); cân nhắc kiểm tra/xoá EXIF phía server |
| R3 | **Không quét nội dung ảnh** ở server (không magic-bytes, không virus, không NSFW); chỉ kiểm cỡ và `Content-Type` khai báo | TB | Cao | Xem R9; kiểm magic-bytes lúc `complete` |
| R4 | **Trẻ vị thành niên + tìm người lân cận + chat người lạ** (rủi ro an toàn và pháp lý) | C | Rất cao | Tách nhóm tuổi (đã có), vị trí thô hơn (đã có); rà soát pháp lý; xác minh tuổi tốt hơn; hạn chế tính năng với nhóm dưới 18; kiểm duyệt chat |
| R5 | **Tự khai ngày sinh** dễ bị khai gian | C | Cao | Xác minh tuổi (nhà cung cấp), giám sát hành vi, báo cáo |
| R6 | **Xác thực thanh toán chưa thử với store thật**; webhook chưa hoàn chỉnh | TB | Cao | Hoàn tất + sandbox Apple/Google; test chữ ký giả/hết hạn; giám sát `STORE_UNAVAILABLE`; chắc chắn `BILLING_DEV_STORE=false` ở production |
| R7 | **Rò rỉ vị trí** (k-anonymity ở vùng thưa, trilateration bằng nhiều tài khoản, không xoá vị trí khi tắt khám phá) | TB | Cao | Xem 9.2; xoá vị trí khi tắt; k ≥ 5 mỗi ô; giới hạn tài khoản mới theo thiết bị/IP; kiểm thử xâm nhập |
| R8 | **Mạo danh qua `X-Public-Id`** nếu mạng nội bộ bị lộ | T | Rất cao | Cách ly mạng; ký header ở gateway hoặc service tự đối chiếu `sub` |
| R9 | **Thiếu kiểm duyệt** (ảnh NSFW, quấy rối, tin nhắn) và công cụ quản trị → bị từ chối ở cửa hàng, hại người dùng | C | Cao | Phân loại ảnh trước khi publish; từ cấm; console xử lý báo cáo; SLA xử lý |
| R10 | **Giới hạn mở rộng**: `OutboxRelay` một luồng/instance; `processed_events` phình; fan-out push N+1; chat mọi instance PSUBSCRIBE toàn bộ kênh; DLQ `<topic>.dlq` chưa được tạo trong `kafka-init` (trừ `media.events.dlq`) | TB | TB | Đo; phân vùng outbox; tạo đủ topic DLQ; job dọn; gom batch token; kênh chia theo băm |
| R11 | **Event kẹt/mất** do cấu hình topic, relay dừng ở một message lỗi | TB | Cao | Metric độ trễ outbox + cảnh báo; tạo topic tường minh; runbook R5 |
| R12 | **Phụ thuộc đồng bộ vào user-service** (xác định người dùng, quan hệ) | TB | Cao | Cache (đã có), nhân bản `ageGroup`/danh tính, nhiều instance, giám sát mạch |
| R13 | **Thiếu kiểm chứng hạ tầng thật** (Flyway/validate, Kafka, Redis GEO, R2, Keycloak) | C | TB-Cao | Checklist 14.5 trước khi demo/ra mắt |
| R14 | **Rò rỉ dữ liệu cá nhân** qua log/Kafka retention/backup sau khi xoá tài khoản | TB | Cao | Retention ngắn, chính sách rõ, rà log; xem 9.4 |
| R15 | **Ảnh mồ côi trên R2** (xoá bài không xoá ảnh) | C | Thấp-TB | Job đối chiếu object R2 với `media_jobs`/`posts`; sự kiện `POST_DELETED` |
| R16 | **Phụ thuộc dịch vụ ngoài** (Cloudflare R2, Aiven, Supabase, Atlas: hạn mức gói miễn phí, độ trễ mạng, sự cố nhà cung cấp) | TB | TB | Theo dõi hạn mức; backup DB; timeout/circuit breaker đã có |
| R17 | **Chi phí/độ phức tạp vận hành** ~20 container, đội nhỏ | TB | TB | Compose profiles, bật dần; cân nhắc gộp service ở giai đoạn đầu; chuyển Kubernetes khi cần |
| R18 | **Gian lận hoàn tiền/chia sẻ biên lai** | T | TB | Ràng buộc duy nhất theo `(store, transactionId)` (đã có); xử lý `REFUND` (đã có logic) |

## 14.3 Câu hỏi còn mở

Từ kế hoạch gốc:
1. Tài khoản dưới 18 chỉ ghép với nhóm tuổi của mình — **code đang áp dụng mặc định này**. Giữ hay bỏ?
2. ~~Ngân sách GPU production~~ — không còn cần (đã bỏ ẩn mặt).
3. Có cho hoàn tác quẹt trái không, có phải tính năng Pro không? (Chưa làm: `swipe:left` không có thao tác xoá.)

Mới phát sinh khi hiện thực:
4. **Bộ thẻ "lân cận hoặc online"**: có giữ việc người online ở xa vẫn xuất hiện (không kèm khoảng cách) không, hay chỉ trong bán kính?
5. **Người dưới 18 có được chat với người lạ** sau khi match không, hay cần xác nhận thêm? Có cho dùng tính năng Boost/lời mời ưu tiên không?
6. **Ảnh hiện mặt thật**: có cần cảnh báo người dùng khi đăng ảnh, hoặc làm mờ mặt phía client, để giữ tinh thần "ẩn danh" không?
7. **`reports`**: giữ bao lâu, ai xem, cho phép người bị báo cáo kháng nghị không?
8. **Huỷ kết bạn** có nên đóng hội thoại và xoá lịch sử tin nhắn không?
9. **Khi xoá bài**, có xoá ảnh khỏi kho ngay không (hiện chỉ ẩn khỏi DB)?
10. **Hạn mức** (ảnh 10/50, quẹt 30/150, lời mời 20/80, tin 20/10 giây) — các con số đề xuất, cần thử nghiệm.
11. **`PRIORITY_INVITE`** mua được nhưng chưa có tính năng tiêu thụ — thiết kế cơ chế hay bỏ khỏi danh mục?
12. **Cho phép đăng nhập mạng xã hội** nào ở Keycloak, và có cần xác minh email/SĐT để chống tài khoản rác?

## 14.4 Backlog kỹ thuật phát hiện khi đọc code

Xếp theo mức ưu tiên (C = cao, TB, T). **✅ = đã sửa trong mã và có test** (chưa chạy trên hạ tầng thật); các mục còn lại chưa làm.

### Đã sửa

| Mức | Việc | Cách xử lý |
|---|---|---|
| C | Ảnh HEIC (iPhone) bị từ chối | ✅ (thời face-worker) — nay server nhận `image/heic` nguyên bản, không giải mã |
| C | `/actuator/prometheus` lộ ra Internet qua Traefik | ✅ router `api` chỉ nhận `/api/`, `/ws/`, `/webhooks/` |
| C | `OutboxRelay` có thể không bao giờ được tạo (thiếu thứ tự sau `KafkaAutoConfiguration`), event kẹt vĩnh viễn trong outbox | ✅ khai báo `after = KafkaAutoConfiguration`; test hồi quy `OutboxAutoConfigurationOrderingTest` (đã chứng minh thất bại khi bỏ dòng sửa) |
| C | Billing: webhook Apple/Google, cổng store thật | ✅ code + 106 test với chứng chỉ/HTTP giả; ⬜ chưa chạy với Apple/Google thật (xem `services/billing-service/STORES.md`) |
| C | Tắt `discoverable` không xoá vị trí | ✅ phát `DISCOVERY_DISABLED`, discovery xoá vị trí/online/boost nhưng giữ lịch sử quẹt |
| TB | Huỷ kết bạn không có event | ✅ `FRIEND_REMOVED`: post xoá cache, chat đóng hội thoại (`UNFRIENDED`) |
| TB | Người không bật khám phá chiếm chỗ trong danh sách online của bộ thẻ | ✅ heartbeat chỉ vào danh sách thẻ khi `discoverable`; trạng thái online cho bạn bè đi qua khoá `presence:{id}` riêng |
| TB | Consumer Java không có DLQ | ✅ `KafkaErrorHandlingAutoConfiguration`: thử lại 3 lần rồi chuyển sang `<topic>.dlq` |
| TB | Cấu hình `resilience4j.*` không áp dụng cho `CircuitBreakerFactory` | ✅ `ResilienceAutoConfiguration` đặt mặc định tường minh (timeout 2s, mở mạch ≥50% lỗi/20 lời gọi); test chứng minh timeout và mở mạch |
| TB | Rate limit theo IP gộp mọi người sau Traefik | ✅ đọc `X-Forwarded-For` (tin 1 proxy); test chống giả mạo chuỗi |
| TB | `IdentityFilter` chưa có test | ✅ 7 test (chống giả mạo header, cache, 404, fail closed 503) |
| TB | Push `MESSAGE_SENT` khi người nhận đang mở app | ✅ bỏ qua khi có khoá `chat:conn:{id}` |
| T | Đăng ký đồng thời cùng `sub` trả 500 | ✅ thử lại idempotent; test 6 luồng đồng thời |
| TB | Mốc "đã đọc" của chat có thể rơi tin do độ phân giải mili-giây của Mongo | ✅ mốc = thời điểm tin mới nhất thực sự tồn tại |

### Còn lại

| Mức | Việc | Tham chiếu |
|---|---|---|
| C | Kiểm duyệt ảnh tự động trước khi publish; công cụ xử lý báo cáo | 09 mục 9.8 |
| C | Cách ly mạng cho `X-Public-Id` (service tin header, không đối chiếu `sub`); đổi mọi mật khẩu/token mặc định | 09 T1–T3 |
| C | Cảnh báo/chặn khởi động nếu `dev-store` bật ở production | 04 mục 4.9, 09 T7/T9 |
| TB | Xoá ảnh khỏi R2 khi xoá bài; dọn ảnh mồ côi | 04 mục 4.5 |
| TB | Tạo topic DLQ cho mọi topic trong `kafka-init` (hiện chỉ có `media.events.dlq`) | 07 mục 7.7 |
| TB | Dọn di sản face-worker trong code/cấu hình: `EventTypes.PHOTO_UPLOADED/FACE_*`, `Topics.MEDIA_RESULTS/MEDIA_DLQ`, topic `media.results`, cột `method/faces_detected/lead_animal`, job Prometheus `minio`, middleware `ratelimit-files`, dashboard `photo-pipeline` | ADR-014 |
| TB | Job dọn `processed_events` (> 30 ngày) | 05 mục 5.6 |
| TB | Trace xuyên Kafka; `correlationId` | 11 mục 11.1 |
| TB | WebSocket: giới hạn thời gian sống phiên theo hạn JWT | 09 T10 |
| TB | `consume` ví idempotent theo `ref` do discovery gửi | 06 mục 6.8 |
| TB | Google: acknowledge giao dịch sau khi ghi quyền lợi (hiện cờ `GOOGLE_SERVER_ACKNOWLEDGE` tắt, client phải tự acknowledge trong 3 ngày) | `services/billing-service/STORES.md` |
| T | Phân trang feed theo `(publishedAt, id)` để không bỏ sót khi trùng thời điểm | 06 mục 6.4 |
| T | Fan-out `POST_PUBLISHED` gọi user-service N+1 lần; gom batch | 04 mục 4.6 |
| T | Bulkhead Resilience4j của chat mới khai báo, chưa gắn | 03 mục 3.6 |
| T | Danh sách từ cấm cho alias; tuỳ chọn tắt từng loại thông báo | 04 mục 4.6 |

## 14.5 Checklist "kiểm tra khi có Docker"

Thứ tự đề xuất — tick từng mục và ghi kết quả vào PR:

**Hạ tầng và khởi động**
- [ ] DB ngoài sẵn sàng: MySQL (3 schema), PostgreSQL (billing, keycloak), MongoDB; bucket R2 + token.
- [ ] `docker compose --profile core up` : Redis, Kafka (KRaft), Keycloak, Traefik khỏe.
- [ ] Topic tường minh (`user.events`, `friend.events`, `media.events`, `post.events`, `chat.events`, `billing.events` và các `<topic>.dlq`) với số phân vùng ≥ 3.
- [ ] `--profile app`: mọi service đăng ký Eureka, `/actuator/health` UP, đọc được Config Server.
- [ ] Keycloak: import realm, tạo user thử, lấy JWT, gọi qua Traefik → gateway.

**Cơ sở dữ liệu**
- [ ] Flyway chạy sạch trên MySQL/PostgreSQL thật.
- [ ] Đặt `JPA_DDL_AUTO=validate` cho user/media/post: nếu lỗi kiểu enum → thêm `@JdbcTypeCode(SqlTypes.VARCHAR)`; đổi mặc định về `validate`.
- [ ] `OutboxRelay` với `SKIP LOCKED` trên MySQL 8 và PostgreSQL; chạy 2 instance cùng lúc không phát trùng liên tục.

**Luồng nghiệp vụ đầu-cuối** (kịch bản vàng, [12-testing-strategy.md](12-testing-strategy.md))
- [ ] Đăng ký 2 người (`register`) → gateway tự gắn `X-Public-Id`; thử giả mạo header → bị xoá.
- [ ] Bật khám phá, cập nhật vị trí, nhận thẻ, quẹt hai chiều → match → `FRIEND_ACCEPTED` → push (log).
- [ ] Upload ảnh bằng presigned PUT thẳng tới R2 → `complete` → `PHOTO_READY` → bài `PUBLISHED` → bạn bè xem URL GET.
- [ ] Gửi file sai `Content-Type` hoặc quá 10 MB: `complete` → `REJECTED`, object bị xoá, bài `REJECTED`, hoàn lượt.
- [ ] Redis: GEOSEARCH, ZSET, pub/sub; chạy `RedisDiscoveryStoreTest` (`REDIS_TEST_HOST`).
- [ ] Chat: 2 instance chat, 2 client WebSocket khác instance nhận tin; chặn → `closed`.
- [ ] Mongo: chạy `ChatMongoIntegrationTest`.
- [ ] Xoá tài khoản: dữ liệu biến mất ở mọi service; Keycloak user bị xoá.
- [ ] Billing: `BILLING_DEV_STORE=true` thử mua Pro/Boost/gói; `consume` Boost từ discovery.

**An toàn và chịu lỗi**
- [ ] `/internal/**` không vào được qua Traefik; `/actuator/*` không lộ ra Internet.
- [ ] Dừng từng thành phần (Kafka, Redis, user-service, chặn R2) và đối chiếu bảng fail closed/soft.
- [ ] Mạch circuit breaker mở/đóng; xem timeout thực tế của time limiter (xác nhận mục 3.6).
- [ ] Prometheus thu được metric của mọi service + `outbox_*`; Grafana dashboard; Tempo nhận trace; Loki có log kèm `traceId`.

**Ảnh**
- [ ] Ảnh tải về từ R2 không còn EXIF/GPS (JPEG, PNG, HEIC từ iPhone).
