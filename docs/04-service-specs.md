# 4. Đặc tả từng service

Mỗi mục gồm: trách nhiệm, dữ liệu sở hữu, API (tóm tắt, chi tiết ở [06-api-reference.md](06-api-reference.md)), event, quy tắc nghiệp vụ, khoá cấu hình, hành vi khi lỗi. Tên cấu hình lấy từ `application.yml` của từng service.

> **billing-service**: phần luồng mua, ví và thuê bao đã có code và test; phần webhook và cổng store Apple/Google thật còn dang dở tại thời điểm viết (ghi rõ ở mục 4.9). Đối chiếu lại với code khi billing hoàn tất.

---

## 4.1 api-gateway (8080)

- **Trách nhiệm**: điểm vào duy nhất sau Traefik. Xác thực JWT, gắn `X-Public-Id`, định tuyến `lb://`, circuit breaker, rate limit.
- **Route** (`application.yml`):

| Route | Đường dẫn | Đích |
|---|---|---|
| user-service | `/api/v1/users/**, friends/**, blocks/**, reports/**, animals/**, devices/**` | `lb://user-service` |
| post-service | `/api/v1/posts/**, /api/v1/feed/**` | `lb://post-service` |
| media-service | `/api/v1/media/**` | `lb://media-service` |
| discovery-service | `/api/v1/discovery/**` (CB `discovery` + limiter chặt 2 req/s, burst 10) | `lb://discovery-service` |
| chat-ws | `/ws/**` | `lb:ws://chat-service` |
| chat-service | `/api/v1/chat/**` | `lb://chat-service` |
| billing-service | `/api/v1/billing/**, /webhooks/**` | `lb://billing-service` |

- `/internal/**` **không có route** nên không bao giờ ra ngoài.
- **Công khai (không JWT)**: `/actuator/health/**`, `/actuator/prometheus`, `/fallback/**`, `/webhooks/**`, mọi `OPTIONS`.
- **Lỗi**: user-service không trả lời và chưa có cache → `503 IDENTITY_UNAVAILABLE`; mạch mở → `503 SERVICE_UNAVAILABLE` (hoặc discovery trả rỗng).
- **Cấu hình**: `KEYCLOAK_JWK_URI`, `REDIS_HOST/PORT`, `EUREKA_URL`, `INTERNAL_TOKEN`, `animal.security.enabled`.

## 4.2 config-server (8888) và eureka-server (8761)

- Config Server: profile `native`, đọc `CONFIG_REPO_PATH` (mặc định `file:../config-repo`), Basic auth `CONFIG_USER/CONFIG_PASSWORD` (mặc định chỉ dành cho dev). Production nên dùng profile `git`; **bí mật không để trong repo cấu hình**.
- `infra/config-repo/application.yml` chứa cấu hình chung: Eureka, actuator, OTLP, tag metric `application`, mẫu log có `traceId`, `animal.internal-token`.
- Eureka: `register-with-eureka=false`, `enable-self-preservation=false` (dev) — production nên bật lại.

---

## 4.3 user-service (8101, MySQL `user_db`)

**Trách nhiệm**: danh tính ẩn danh, kết bạn, chặn, báo cáo, bộ sưu tập con vật, quay thưởng, thiết bị push, bản sao quyền lợi Pro.

**Dữ liệu sở hữu**: `users`, `friendships`, `friend_requests`, `blocks`, `reports`, `animals`, `user_animals`, `spin_log`, `device_tokens`, `entitlements`, `outbox_events`, `processed_events` ([05-data-model.md](05-data-model.md)). Bảng `users.keycloak_sub` là nơi duy nhất ánh xạ `sub` ↔ `publicId`.

**API công khai**: `register`, `me` (GET/PATCH/DELETE), hồ sơ người khác, đổi con vật chủ đạo (Pro), con vật đã sở hữu, quay thưởng, danh mục con vật, bạn bè, lời mời, chặn, báo cáo, thiết bị.
**API nội bộ**: `identity/{sub}`, `users/{id}`, `users?ids=`, `friends/{id}`, `relationship`, `exclusions/{id}`, `swipes/right`, `devices/{id}`, `DELETE devices/{token}`.

**Event phát** (Outbox): `USER_REGISTERED`, `USER_DELETED`, `USER_BLOCKED`, `LEAD_ANIMAL_CHANGED` (topic `user.events`); `FRIEND_REQUEST_RECEIVED`, `FRIEND_ACCEPTED` (topic `friend.events`).
**Event nhận** (`billing.events`, group `user-service`): `SUBSCRIPTION_ACTIVATED/EXPIRED` → bảng `entitlements`; `CONSUMABLE_GRANTED` với `item=ANIMAL_PACK:<mã>` → thêm con vật của gói.

**Quy tắc nghiệp vụ chính**
- Đăng ký idempotent theo `sub`. Ngày sinh → `ageGroup` (`MINOR` nếu dưới 18). Tuổi > 120 hoặc ngày sinh tương lai → `400 INVALID_BIRTHDATE`. Không chặn theo tuổi.
- `discoverable` mặc định **false** cho mọi người.
- Con vật đầu tiên: ngẫu nhiên trong nhóm COMMON của bộ cơ bản. Alias gợi ý dạng "`<Tên con vật> <Tính từ> <3 chữ số>`".
- Alias: 3–20 ký tự (chữ, số, khoảng trắng, `_ . -`), chặn từ khoá (`admin`, `moderator`, `support`, `animallocket`, `staff` — so sánh sau khi bỏ dấu), đổi tối đa 1 lần/24 giờ.
- Đổi con vật chủ đạo: cần Pro (`402 PRO_REQUIRED`) và đã sở hữu (`400 ANIMAL_NOT_OWNED`).
- Quay thưởng: chọn theo trọng số COMMON 70 / RARE 25 / EPIC 5 trong bộ cơ bản chưa sở hữu; cooldown free 7 ngày, Pro 1 ngày.
- `connect(from,to,source)` (dùng cho quẹt phải và lời mời): chặn → `BLOCKED`; khác nhóm tuổi → `403`; đã là bạn → `ALREADY_FRIENDS`; bên kia đã mời → `MATCHED` (thành bạn ngay, phát `FRIEND_ACCEPTED`); đã mời → `ALREADY_REQUESTED`; vượt hạn mức → `429 INVITE_LIMIT`; còn lại tạo/tái dùng lời mời → `REQUESTED` (phát `FRIEND_REQUEST_RECEIVED`).
- Chặn: lưu `blocks`, xoá quan hệ bạn, huỷ lời mời đang chờ hai chiều, phát `USER_BLOCKED`. Hồ sơ người chặn/bị chặn trả `404` cho nhau.
- Xoá tài khoản: xoá quan hệ/chặn/thiết bị/con vật/lượt quay/quyền lợi, ẩn danh bản ghi (`alias="deleted"`, `keycloak_sub="deleted:<publicId>"`, `birth_date=null`), phát `USER_DELETED`, gọi Keycloak Admin xoá user. Lỗi Keycloak → rollback (người dùng thử lại).
- Báo cáo: tối đa 20/24 giờ. **Không xoá `reports` khi xoá tài khoản** (giữ cho an toàn/pháp lý).

**Cấu hình**: `animal.limits.invites-per-day.free|pro` (20/80), `animal.limits.spin-interval.free|pro` (7d/1d), `keycloak.admin.url|realm|client-id|client-secret`, `DB_URL/DB_USER/DB_PASSWORD`, `KAFKA_BOOTSTRAP`.

**Khi lỗi**: Keycloak Admin không cấu hình → `NoopIdentityProviderClient` chỉ ghi cảnh báo (chỉ cho dev). Kafka tạm hỏng không ảnh hưởng ghi DB (event nằm trong outbox).

---

## 4.4 media-service (8103, MySQL `media_db` + Cloudflare R2)

**Trách nhiệm**: cấp URL upload ký sẵn (presigned PUT), kiểm tra ảnh khi client báo xong, phát `PHOTO_READY/REJECTED`, cấp URL xem ngắn hạn, dọn job bỏ dở. **Không xử lý ảnh** (face-worker đã gỡ; client tự nén và xoá EXIF).

**Dữ liệu**: `media_jobs` (trạng thái `PENDING_UPLOAD → READY | REJECTED`), `owner_animals`, outbox/processed. R2: **một** bucket private (`R2_BUCKET`), khoá `{mediaId}.{ext}`; `publicKey` = `rawKey` (cùng object, không sao chép). Các cột `method`, `faces_detected`, `lead_animal` còn trong bảng nhưng không còn ý nghĩa (`method = "NONE"`, `faces_detected = 0`).

**API**: `POST /media/uploads`, `POST /media/{id}/complete`, `GET /media/{id}`, `GET /media/{id}/url`; nội bộ `GET /internal/media/{id}`.

**Event phát**: `PHOTO_READY`, `PHOTO_REJECTED` (topic `media.events`, khoá = `mediaId`).
**Event nhận** (group `media-service`, topic `user.events`): `USER_REGISTERED`, `LEAD_ANIMAL_CHANGED` → `owner_animals` (bản sao hiện không được đọc ở đâu); `USER_DELETED` → xoá job và object.

**Quy tắc**
- Chỉ nhận `image/jpeg|png|webp|heic`, tối đa `animal.media.max-bytes` (10 MB), tối đa 60 yêu cầu upload/giờ/người (`UPLOAD_LIMIT`).
- `POST /media/uploads` trả `{mediaId, uploadUrl, headers, expiresInSeconds: 300}`. Client `PUT` file tới `uploadUrl` kèm đúng `headers` (`Content-Type`). R2 **không hỗ trợ presigned POST** nên không ràng buộc được cỡ file lúc upload.
- `complete`: kiểm tra object tồn tại (`409 NOT_UPLOADED` nếu chưa), rồi kiểm tra lại cỡ và `Content-Type` thật của object (chữ ký PUT không khoá được hai thứ này). Sai → xoá object, job `REJECTED` (`FILE_TOO_LARGE` / `UNSUPPORTED_MEDIA_TYPE`), phát `PHOTO_REJECTED`. Đúng → job `READY`, phát `PHOTO_READY`. Idempotent: gọi lại khi job đã khỏi `PENDING_UPLOAD` chỉ trả trạng thái.
- Xem ảnh (`/url`): chủ ảnh, hoặc bạn bè **không bị chặn**; còn lại `404`. URL ký sẵn hiệu lực 10 phút.
- Dọn dẹp định kỳ (`MediaJanitor`, mỗi 60 giây, tắt bằng `animal.media.janitor.enabled=false`): job `PENDING_UPLOAD` quá 1 giờ bị xoá cùng object.

**Cấu hình**: `storage.endpoint` (`R2_ENDPOINT`, dạng `https://<account-id>.r2.cloudflarestorage.com`), `storage.region=auto`, `storage.access-key/secret-key` (`R2_ACCESS_KEY/R2_SECRET_KEY`), `storage.bucket` (`R2_BUCKET`), `animal.media.*`.

**Khi lỗi**: user-service lỗi khi xem ảnh của người khác → không cấp URL (fail closed). R2 lỗi → `complete` lỗi, client gọi lại được (idempotent).

---

## 4.5 post-service (8102, MySQL `post_db` + Redis)

**Trách nhiệm**: bài đăng, like, bình luận, feed bạn bè, hạn mức ảnh/ngày.

**Dữ liệu**: `posts`, `post_likes`, `comments`, `media_states`, outbox/processed. Redis: `quota:photo:*`, `pro:*`, `friends:*`.

**API**: tạo/xem/xoá bài, bài của tôi, feed (`before`, `limit`), like/unlike, bình luận (thêm/liệt kê/xoá).

**Event phát** (`post.events`): `POST_PUBLISHED`, `POST_LIKED` (không phát khi tự like), `POST_COMMENTED`.
**Event nhận** (group `post-service`): `PHOTO_READY/REJECTED` (chỉ `context=POST`), `USER_DELETED`, `USER_BLOCKED` và `FRIEND_ACCEPTED` (xoá cache bạn bè), `SUBSCRIPTION_ACTIVATED/EXPIRED` (khoá `pro:{id}`).

**Quy tắc**
- Tạo bài từ `mediaId` đã upload. Bài ở `PENDING_MEDIA`; chuyển `PUBLISHED` khi `PHOTO_READY` và **chủ ảnh trùng tác giả** (sai → `REJECTED/OWNER_MISMATCH`). `PHOTO_READY` đến **trước** khi tạo bài được xử lý nhờ bảng `media_states`.
- Hạn mức ảnh: free 10, Pro 50 mỗi ngày giờ Việt Nam; ảnh bị từ chối được hoàn lượt.
- Chỉ tác giả và bạn bè thấy bài `PUBLISHED`; người khác nhận `404` (không lộ sự tồn tại). Chỉ lưu `publicKey` của ảnh và **không bao giờ** trả ra DTO.
- Xoá bài: trạng thái `DELETED`, xoá like/bình luận. (Ảnh trên R2 chưa được xoá — xem [14-roadmap-risks.md](14-roadmap-risks.md).)

**Cấu hình**: `animal.limits.photos-per-day.free|pro` (10/50), `animal.kv.type`, `REDIS_HOST`.
**Khi lỗi**: user-service lỗi → feed trả rỗng `degraded=true`; xem bài lẻ `404`.

---

## 4.6 notification-service (8107, không DB)

**Trách nhiệm**: biến event thành push FCM (Android + iOS qua FCM).

**Event nhận** (group `notification-service`, `auto-offset-reset: latest`): `FRIEND_REQUEST_RECEIVED`, `FRIEND_ACCEPTED` (cả hai bên), `POST_PUBLISHED` (tới mọi bạn của tác giả), `POST_LIKED`, `POST_COMMENTED`, `MESSAGE_SENT`, `PHOTO_REJECTED`, `SUBSCRIPTION_ACTIVATED`.

**Quy tắc**: nội dung **chung chung**, không nêu alias hay danh tính ("Có người thích ảnh của bạn"). Token thiết bị lấy từ user-service; token chết (`INVALID_TOKEN`) được gỡ qua `DELETE /internal/devices/{token}`.
**Cấu hình**: `animal.push.fcm.credentials-file` (`FCM_CREDENTIALS_FILE`; rỗng → chỉ ghi log), `animal.push.max-attempts` (3), `animal.push.backoff-ms` (500).
**Khi lỗi**: fail soft — hết lượt retry thì bỏ; hàng đợi đầy thì bỏ bớt (`DiscardPolicy`). Chưa có tuỳ chọn tắt từng loại thông báo (yêu cầu F2).

---

## 4.7 discovery-service (8104, Redis)

**Trách nhiệm**: vị trí gần đúng, trạng thái online, bộ thẻ quẹt, lượt quẹt phải, Boost.

**Dữ liệu (Redis)**: `geo:{ageGroup}`, `geo:exp:{ageGroup}`, `online:{ageGroup}`, `boost`, `swipe:left:{me}`, `swipe:right:{me}`, khoá hạn mức qua `KeyValueStore` ([05-data-model.md](05-data-model.md)).

**API**: `PUT/DELETE /discovery/location`, `POST /heartbeat`, `GET /presence?ids=`, `GET /cards`, `POST /swipes`, `POST /boost`.

**Event nhận** (group `discovery-service`): `USER_DELETED` → xoá mọi dấu vết; `SUBSCRIPTION_*` → khoá `pro:{id}`. `USER_BLOCKED`/`FRIEND_ACCEPTED` **không cần** xử lý vì danh sách loại trừ lấy trực tiếp từ user-service mỗi lần.

**Quy tắc**
- Cập nhật vị trí chỉ khi hồ sơ đang `discoverable`; vị trí được làm tròn lưới 500 m, cộng độ lệch cố định theo người, TTL 30 phút; chỉ ghép trong cùng nhóm tuổi ([09-privacy-safety-security.md](09-privacy-safety-security.md)).
- **Bộ thẻ = người lân cận HOẶC đang online** (online = heartbeat trong 60 giây). Người online ngoài bán kính vẫn có thẻ nhưng **không có mức khoảng cách**. Bán kính: người lớn 10 km, dưới 18 5 km.
- Loại trừ: chính mình, bạn bè, chặn hai chiều, đã quẹt trái trong 30 ngày, đã quẹt phải. Hồ sơ ứng viên được lấy **mới** từ user-service để lọc `active && discoverable && cùng nhóm tuổi`.
- Sắp xếp: đang Boost → gần hơn → đang online → `publicId`.
- Quẹt phải: hạn mức free 30, Pro 150/ngày; gọi user-service; `BLOCKED/ALREADY_FRIENDS/ALREADY_REQUESTED` và lỗi hệ thống **hoàn lượt**.
- Boost: trừ 1 `BOOST` trong ví billing (`/internal/wallet/consume`), hiệu lực 30 phút; hết số dư → `402 NO_BOOST`.
- Giới hạn tìm: 10 lần/phút/người (`TOO_MANY_SEARCHES`); thêm giới hạn ở gateway.

**Cấu hình**: `animal.discovery.secret` (**bắt buộc đổi** ở production, ≥ 16 ký tự), `location-ttl` 30m, `radius-adult-m` 10000, `radius-minor-m` 5000, `cards-per-minute` 10, `animal.limits.swipes-per-day.free|pro` (30/150), `purge-interval-ms` 60000.
**Khi lỗi**: thẻ → rỗng `degraded=true`; quẹt/Boost → `503` và hoàn lượt.

---

## 4.8 chat-service (8105, MongoDB + Redis)

**Trách nhiệm**: hội thoại 1-1 giữa bạn bè, tin nhắn văn bản và ảnh, WebSocket thời gian thực.

**Dữ liệu**: Mongo `conversations` (khoá duy nhất `a:b` theo thứ tự), `messages` (index `conversationId + createdAt desc`). Redis: pub/sub `chat:user:{id}`, `chat:conn:{id}`, `chat:rel:*`, `chat:rl:*`.

**API**: REST (mở hội thoại, danh sách, lịch sử, gửi, đánh dấu đã đọc) và WebSocket `/ws/chat` ([06-api-reference.md](06-api-reference.md)).

**Event phát**: `MESSAGE_SENT` (topic `chat.events`, trực tiếp, không Outbox). **Event nhận** (group `chat-service`): `USER_BLOCKED` → đóng hội thoại và báo cả hai đầu; `FRIEND_ACCEPTED` → xoá cache quan hệ; `USER_DELETED` → xoá hội thoại và tin nhắn.

**Quy tắc**
- Chỉ mở/gửi khi `friends && !blocked` (cache 30 giây). Người lạ chỉ chat được sau khi **đã thành bạn** (lời mời được chấp nhận ≡ bạn bè).
- Tin văn bản 1–2000 ký tự. Tin ảnh: `mediaId` phải của chính người gửi, `context=CHAT`, trạng thái `READY` (`INVALID_MEDIA`, `MEDIA_NOT_READY`).
- Giới hạn 20 tin/10 giây/người (`CHAT_RATE_LIMIT`).
- Xác thực WebSocket ngay lúc bắt tay: JWT (Spring Security) + `X-Public-Id` do gateway gắn; thiếu → `403`. Khung > 16 KB đóng kết nối.
- Chưa đọc = số tin của người kia mới hơn mốc đọc; mốc đọc = thời điểm tin mới nhất đã đọc.

**Khi lỗi**: user-service/media-service lỗi → `503` (fail closed); không gửi được push không ảnh hưởng việc gửi tin.

---

## 4.9 billing-service (8106, PostgreSQL)

**Trách nhiệm**: thuê bao Pro, mua lẻ (Boost, lời mời ưu tiên, gói con vật), ví/sổ cái vật phẩm, xác thực giao dịch với store, thu hồi khi hoàn tiền/hết hạn.

**Dữ liệu**: `products` (seed 8 sản phẩm), `purchases`, `subscriptions`, `wallet_balances`, `wallet_ledger`, `webhook_events`, outbox/processed ([05-data-model.md](05-data-model.md)).

**API công khai**: `GET /billing/products`, `GET /billing/me` (`plan`, `planExpiresAt`, `wallet`), `POST /billing/purchases/verify` (`{store, sku, token}`).
**API nội bộ**: `POST /internal/wallet/consume` (discovery trừ Boost), `GET /internal/wallet/{publicId}`.
**Webhook** `POST /webhooks/apple`, `/webhooks/google`: cấu hình công khai (`animal.security.public-paths=/webhooks/**`) và hàm xử lý (`firstTimeWebhook`, `onSubscriptionUpdated/Ended`, `onRefund`) đã có trong `BillingService`, nhưng **controller nhận webhook chưa có trong code lúc viết tài liệu**.

**Event phát** (Outbox, topic `billing.events`): `SUBSCRIPTION_ACTIVATED` / `SUBSCRIPTION_EXPIRED` (theo trạng thái Pro hiện tại), `CONSUMABLE_GRANTED` (`BOOST`, `PRIORITY_INVITE`, `ANIMAL_PACK:<mã>`).
**Event nhận** (group `billing-service`, topic `user.events`): chỉ `USER_DELETED` → xoá ví/sổ cái/thuê bao, ẩn danh `purchases`.

**Luồng mua (`PurchaseFlow` → `BillingService.grant`)**
1. Sản phẩm phải tồn tại và `active` (`400 UNKNOWN_PRODUCT`).
2. **Hỏi store trước** (`StoreRouter.verify`) và **không giữ transaction/kết nối DB** trong lúc chờ mạng. `StoreException.INVALID` → `400 INVALID_RECEIPT`; lỗi khác hoặc store chưa bật → `503 STORE_UNAVAILABLE` ("bạn sẽ không bị mất quyền lợi").
3. Kiểm tra `sku` khớp (`SKU_MISMATCH`) và chưa bị thu hồi (`RECEIPT_REVOKED`).
4. Trong **một transaction ngắn**: nếu `(store, transactionId)` đã có → cùng người thì trả trạng thái hiện tại (idempotent), khác người → `409 RECEIPT_ALREADY_USED`. Ngược lại ghi `purchases` rồi cấp quyền:
   - `SUBSCRIPTION`: tạo/cập nhật `subscriptions` theo `(store, originalTransactionId)` (thuê bao đã gắn tài khoản khác → `409`), `ACTIVE` nếu `expiresAt` còn ở tương lai; phát event theo Pro hiện tại.
   - `CONSUMABLE`: cộng ví (`credit`, ref `purchase:<id>`) + `CONSUMABLE_GRANTED`.
   - `PACK`: chỉ phát `CONSUMABLE_GRANTED` với `item=ANIMAL_PACK:<mã>`; user-service mở các con vật.
5. Client chỉ kết thúc giao dịch với store **sau khi nhận 200**, nên người dùng không bị trừ tiền mà không có quyền lợi (gửi lại `verify` để "khôi phục giao dịch").

**Cổng store (`StoreGateway`)**
- `StoreRouter` chọn cổng theo `store`; store không có cổng (chưa cấu hình/tắt) → từ chối, không bao giờ cấp quyền.
- `DevStoreGateway`: **chỉ khi `animal.billing.dev-store.enabled=true`** (mặc định tắt, biến `BILLING_DEV_STORE`); tin token do client khai (`dev:<tx>[:<orig>[:<expiresEpochSeconds>]]`). Tuyệt đối không bật ở production.
- `AppleJwsVerifier`: xác thực JWS ES256 của Apple (chỉ chấp nhận `alg=ES256`, chuỗi `x5c` hợp lệ PKIX tới Apple Root CA đã cấu hình, OID đánh dấu của Apple, chữ ký hợp lệ; không có root cấu hình → từ chối). Không kiểm tra thu hồi chứng chỉ (OCSP/CRL). Cùng với `AppleProperties`, `GoogleProperties`, `StoreCaller` (retry/circuit breaker `store-apple`/`store-google`). **Cổng Apple/Google gọi API store thật chưa hoàn chỉnh trong code lúc viết, chưa thử sandbox.**

**Ví** (`WalletService`): `credit`/`debit` chạy bằng câu `UPDATE` nguyên tử, mỗi thay đổi có dòng sổ cái duy nhất theo `(reason, ref, item)` (`CHECK balance >= 0`). `consume` (nội bộ): `409 INSUFFICIENT_BALANCE` nếu không đủ; `400 UNKNOWN_ITEM`; `ref` là UUID ngẫu nhiên nên **không idempotent** theo yêu cầu gọi.

**Hoàn tiền/hết hạn**: `onRefund` thu hồi tối đa số dư còn lại của vật phẩm mua lẻ, kết thúc thuê bao, giữ nguyên con vật của gói đã mở. `BillingMaintenance` mỗi 5 phút hạ thuê bao `ACTIVE` quá hạn **cộng thêm `animal.billing.expiry-grace` (1 giờ)** (chờ thông báo gia hạn đến muộn).

**Cấu hình**: `animal.billing.expiry-grace` (1h), `expiry-interval-ms` (300000), `animal.billing.dev-store.enabled`, cấu hình Apple/Google (`AppleProperties`/`GoogleProperties`), `resilience4j.circuitbreaker.instances.store-apple|store-google`, `resilience4j.retry` (3 lần, 500 ms, luỹ thừa), `JPA_DDL_AUTO` (mặc định `validate`).

**Khi lỗi**: fail closed — không xác minh được thì không cấp quyền; webhook xử lý lỗi nên trả 5xx để store gửi lại.

---

## 4.10 face-worker — đã gỡ

Worker Python ẩn mặt đã bị gỡ khỏi repo. media-service tự đánh dấu ảnh `READY` khi client báo upload xong (xem 4.4). Lịch sử thiết kế cũ ở [08-face-anonymization-pipeline.md](08-face-anonymization-pipeline.md).
