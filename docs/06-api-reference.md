# 6. Tham chiếu API

Mọi đường dẫn dưới đây đi qua gateway (`https://<domain>`) trừ phần **Nội bộ**. Nguồn: các `@RestController` và DTO trong code.

## 6.1 Quy ước chung

| Mục | Quy ước |
|---|---|
| Tiền tố | `/api/v1` (billing webhook: `/webhooks/**`; WebSocket: `/ws/chat`) |
| Xác thực | `Authorization: Bearer <JWT Keycloak>` trên mọi request (trừ `/webhooks/**`) |
| Danh tính | Gateway gắn `X-Public-Id`; client **không** được tự gửi (bị gateway xoá). Người dùng chưa đăng ký hồ sơ chỉ gọi được `POST /users/register`; các endpoint khác trả `403 PROFILE_REQUIRED` |
| Định dạng | JSON UTF-8, thời gian ISO-8601 UTC (`2026-11-06T03:21:45.123Z`) |
| Lỗi | RFC 7807 `application/problem+json`: `{"type":"about:blank","title":"Bad Request","status":400,"detail":"…","code":"INVALID_ALIAS"}`. Client dựa vào **`code`**, không dựa vào `detail` |
| Idempotency | Không dùng header `Idempotency-Key` (đã khai báo hằng số `Headers.IDEMPOTENCY_KEY` nhưng chưa dùng). Các thao tác được thiết kế idempotent theo tự nhiên: đăng ký theo `sub`, `complete` upload, like, chặn, nhận biên lai theo `(store, transactionId)` |
| Rate limit | Gateway: 20 req/s (burst 40) theo người dùng/IP; discovery 2 req/s (burst 10). Vượt → `429` (không có `code`) |
| Phân trang | Mỗi nơi một kiểu: feed `before=<Instant>&limit` (trang kế = `nextBefore`); lịch sử chat `before=<Instant>&limit`; bình luận `after=<id>&limit` (trang kế = `nextAfter`); các danh sách khác không phân trang. `limit` tối đa 50 (feed/bình luận) hoặc 100 (chat) |

### Mã lỗi chung

| HTTP | `code` | Khi nào |
|---|---|---|
| 400 | `VALIDATION_FAILED` | DTO không hợp lệ (`detail` liệt kê `trường: lý do`) |
| 401 | — | JWT thiếu/sai/hết hạn (do Spring Security, thân rỗng) |
| 403 | `PROFILE_REQUIRED` | Thiếu `X-Public-Id` (chưa đăng ký hồ sơ) |
| 403 | `FORBIDDEN` | Không có quyền |
| 403 | `INTERNAL_ONLY` | Gọi `/internal/**` thiếu/sai `X-Internal-Token` |
| 404 | `NOT_FOUND` | Không tồn tại **hoặc** không được phép thấy (không lộ sự tồn tại) |
| 429 | `*_LIMIT`, `*_COOLDOWN` | Vượt hạn mức (mã cụ thể ở từng mục) |
| 500 | `INTERNAL_ERROR` | Lỗi không lường trước (chi tiết chỉ ghi log) |
| 503 | `SERVICE_UNAVAILABLE`, `IDENTITY_UNAVAILABLE`, `*_UNAVAILABLE` | Mạch mở / dịch vụ phụ thuộc lỗi |

---

## 6.2 user-service

### Hồ sơ

| Method & đường dẫn | Mô tả | Request | Response | Lỗi |
|---|---|---|---|---|
| `POST /users/register` | Đăng ký hồ sơ lần đầu (idempotent theo `sub`; gọi lại trả hồ sơ cũ) | `{alias?: string(3–20), birthDate: "YYYY-MM-DD"}` | `201` `MeProfile` | `400 INVALID_BIRTHDATE`, `INVALID_ALIAS` |
| `GET /users/me` | Hồ sơ của tôi | — | `MeProfile` | 404 |
| `PATCH /users/me` | Đổi alias / bật-tắt khám phá | `{alias?, discoverable?}` | `MeProfile` | `400 INVALID_ALIAS`, `429 ALIAS_COOLDOWN` (1 lần/24 giờ) |
| `DELETE /users/me` | Xoá tài khoản và dữ liệu | — | `204` | 503 nếu Keycloak lỗi |
| `GET /users/{publicId}` | Hồ sơ công khai | — | `PublicProfile` | `404` nếu không tồn tại hoặc có chặn |
| `PUT /users/me/lead-animal` | Đổi con vật chủ đạo | `{animalCode}` | `MeProfile` | `402 PRO_REQUIRED`, `400 ANIMAL_NOT_OWNED` |
| `GET /users/me/animals` | Con vật đã sở hữu | — | `[AnimalView]` | |
| `POST /users/me/spin` | Quay thưởng | — | `{animal: AnimalView, nextSpinAt}` | `429 SPIN_COOLDOWN`, `409 COLLECTION_COMPLETE` |
| `GET /animals` | Danh mục con vật | — | `[AnimalView]` | |

```
MeProfile    {publicId, alias, leadAnimal, ageGroup: "MINOR|ADULT", discoverable, plan: "FREE|PRO", createdAt}
PublicProfile{publicId, alias, leadAnimal}
AnimalView   {code, name, rarity: "COMMON|RARE|EPIC", packCode|null}
```

`MeProfile` không có `birthDate`, `sub`, email.

### Bạn bè, chặn, báo cáo, thiết bị

| Method & đường dẫn | Mô tả | Request | Response | Lỗi |
|---|---|---|---|---|
| `GET /friends` | Danh sách bạn | — | `[PublicProfile]` | |
| `DELETE /friends/{publicId}` | Huỷ kết bạn | — | `204` | |
| `GET /friends/requests/incoming` | Lời mời đã nhận | — | `[{id, user: PublicProfile, createdAt}]` | |
| `GET /friends/requests/outgoing` | Lời mời đã gửi | — | idem | |
| `POST /friends/requests` | Gửi lời mời | `{toPublicId}` | `{result}` | `400 SELF_REQUEST`, `403` (khác nhóm tuổi), `404`, `429 INVITE_LIMIT` |
| `POST /friends/requests/{id}/accept` | Chấp nhận | — | `204` | `404` (không phải của tôi / không còn chờ) |
| `POST /friends/requests/{id}/decline` | Từ chối | — | `204` | 404 |
| `DELETE /friends/requests/{id}` | Huỷ lời mời đã gửi | — | `204` | 404 |
| `GET /blocks` | Danh sách đã chặn | — | `[PublicProfile]` | |
| `PUT /blocks/{publicId}` | Chặn (idempotent) | — | `204` | `400 SELF_BLOCK`, 404 |
| `DELETE /blocks/{publicId}` | Bỏ chặn | — | `204` | |
| `POST /reports` | Báo cáo | `{targetType: USER\|POST\|COMMENT\|MESSAGE, targetPublicId, targetRef?, reason(≤30), details?(≤500)}` | `201` | `429 REPORT_LIMIT` (20/24h) |
| `PUT /devices` | Đăng ký token push | `{token(≤255), platform(≤10)}` | `204` | |
| `DELETE /devices/{token}` | Gỡ token | — | `204` | |

`result` của lời mời: `REQUESTED` (đã gửi), `MATCHED` (bên kia đã mời trước → thành bạn ngay), `ALREADY_FRIENDS`, `ALREADY_REQUESTED`, `BLOCKED`.

---

## 6.3 media-service

### Quy trình upload ảnh

```
1. POST /api/v1/media/uploads  {context, refId?, contentType, sizeBytes}
        ← 201 {mediaId, uploadUrl, fields:{...}, expiresInSeconds: 300}
2. POST <uploadUrl>   (multipart/form-data, gửi THẲNG tới MinIO qua Traefik, không qua gateway)
        các trường của "fields" đúng nguyên văn, rồi trường "file" PHẢI LÀ TRƯỜNG CUỐI CÙNG
        Content-Type của phần file = contentType đã khai báo; kích thước 1..10 MB
        ← 204 từ MinIO
3. POST /api/v1/media/{mediaId}/complete
        ← 200 {mediaId, status:"UPLOADED"}     (phát PHOTO_UPLOADED)
4. Hỏi trạng thái:  GET /api/v1/media/{mediaId}  →  UPLOADED → READY | REJECTED
   (hoặc chờ push PHOTO_REJECTED; với POST thì bài tự chuyển PUBLISHED)
5. Xem ảnh đã ẩn mặt:  GET /api/v1/media/{mediaId}/url  → {url, expiresInSeconds: 600}
```

| Method & đường dẫn | Request | Response | Lỗi |
|---|---|---|---|
| `POST /media/uploads` | `{context: POST\|CHAT, refId?(≤64), contentType: image/jpeg\|png\|webp\|heic, sizeBytes(1..50_000_000)}` | `201 {mediaId, uploadUrl, fields, expiresInSeconds}` | `400 UNSUPPORTED_MEDIA_TYPE`, `400 FILE_TOO_LARGE` (> 10 MB), `429 UPLOAD_LIMIT` (60/giờ) |
| `POST /media/{id}/complete` | — | `{mediaId, status, method, rejectReason}` | `409 NOT_UPLOADED`, `404`, `503 USER_SERVICE_UNAVAILABLE` |
| `GET /media/{id}` | — | `{mediaId, status, method, rejectReason}` | 404 (chỉ chủ ảnh) |
| `GET /media/{id}/url` | — | `{url, expiresInSeconds}` | 404 (chưa `READY`, không phải chủ/bạn, hoặc bị chặn) |

`status`: `PENDING_UPLOAD`, `UPLOADED`, `READY`, `REJECTED`. `method`: `AI`, `STICKER`, `NONE`.

---

## 6.4 post-service

| Method & đường dẫn | Mô tả | Request | Response | Lỗi |
|---|---|---|---|---|
| `POST /posts` | Tạo bài từ `mediaId` đã upload | `{mediaId, caption?(≤200)}` | `201 PostView` (`PENDING_MEDIA` hoặc `PUBLISHED` nếu ảnh đã xong) | `403 FORBIDDEN` (ảnh của người khác), `429 PHOTO_LIMIT` |
| `GET /posts/mine` | Bài của tôi (mọi trạng thái trừ `DELETED`) | `?limit` | `[PostView]` | |
| `GET /posts/{id}` | Xem bài | — | `PostView` | 404 (không phải tác giả/bạn, hoặc chưa `PUBLISHED`) |
| `DELETE /posts/{id}` | Xoá bài (tác giả) | — | `204` | 404 |
| `GET /feed` | Feed bạn bè + của tôi | `?before=&limit=20` | `{items:[PostView], nextBefore, degraded}` | — (lỗi bạn bè → `degraded:true`, `items:[]`) |
| `PUT /posts/{id}/like` | Like (idempotent) | — | `204` | 404 |
| `DELETE /posts/{id}/like` | Bỏ like | — | `204` | 404 |
| `POST /posts/{id}/comments` | Bình luận | `{text(1–300)}` | `201 CommentView` | 404 |
| `GET /posts/{id}/comments` | Liệt kê | `?after=0&limit=30` | `{items:[CommentView], nextAfter}` | 404 |
| `DELETE /posts/{id}/comments/{commentId}` | Xoá (tác giả bình luận hoặc tác giả bài) | — | `204` | `403 FORBIDDEN`, 404 |

```
PostView   {id, author:{publicId, alias|null, leadAnimal|null}, caption, mediaId, status,
            likeCount, commentCount, likedByMe, createdAt, publishedAt}
CommentView{id, author:{...}, text, createdAt}
```

`PostView` **không** có đường dẫn kho ảnh; ảnh lấy bằng `GET /media/{mediaId}/url`. `alias/leadAnimal` có thể `null` khi user-service lỗi (fail soft).

---

## 6.5 discovery-service

| Method & đường dẫn | Mô tả | Request | Response | Lỗi |
|---|---|---|---|---|
| `PUT /discovery/location` | Cập nhật vị trí (chỉ khi đã bật khám phá) | `{lat: -90..90, lon: -180..180}` | `204` | `403` (chưa bật khám phá), 404 |
| `DELETE /discovery/location` | Xoá vị trí ngay | — | `204` | |
| `POST /discovery/heartbeat` | Báo đang online (gọi mỗi ≤ 30–45 giây) | — | `204` | 404 |
| `GET /discovery/presence?ids=a,b` | Trạng thái online **của bạn bè** (tối đa 200 id; id không phải bạn bị bỏ qua) | — | `{online:{id:boolean}}` | |
| `GET /discovery/cards?limit=20` | Bộ thẻ gợi ý (tối đa 30) | — | `{cards:[Card], degraded, swipesLeftToday}` | `403`, `429 TOO_MANY_SEARCHES` |
| `POST /discovery/swipes` | Quẹt | `{targetPublicId, direction: LEFT\|RIGHT}` | `{result, swipesLeftToday}` | `400 SELF_SWIPE`, `429 SWIPE_LIMIT`, `503` |
| `POST /discovery/boost` | Dùng 1 Boost | — | `204` | `402 NO_BOOST`, `503 BILLING_UNAVAILABLE` |

```
Card {publicId, alias, leadAnimal, distanceBand|null, online, boosted}
distanceBand: người lớn  UNDER_1KM | 1_TO_3KM | 3_TO_10KM | OVER_10KM
              dưới 18    UNDER_3KM | 3_TO_10KM | OVER_10KM
              null khi người đó chỉ "online" mà ngoài bán kính
```

`result` của swipe: `SKIPPED` (trái) hoặc kết quả của lời mời: `REQUESTED`, `MATCHED`, `ALREADY_FRIENDS`, `ALREADY_REQUESTED`, `BLOCKED`. Card **không** có toạ độ, mét, ảnh thật hay thông tin định danh.

---

## 6.6 chat-service

### REST

| Method & đường dẫn | Request | Response | Lỗi |
|---|---|---|---|
| `POST /chat/conversations` | `{withPublicId}` | `ConversationView` | `403` (không phải bạn / có chặn), `400 SELF_CHAT`, `503` |
| `GET /chat/conversations` | — | `[ConversationView]` (chỉ `ACTIVE`, mới nhất trước) | |
| `GET /chat/conversations/{id}/messages` | `?before=&limit=30` | `[MessageView]` (mới nhất trước) | 404 |
| `POST /chat/conversations/{id}/messages` | `{type?: TEXT\|IMAGE, text?(≤2000), mediaId?}` | `201 MessageView` | `400 INVALID_MESSAGE`, `400 INVALID_MEDIA`, `409 MEDIA_NOT_READY`, `403`, `429 CHAT_RATE_LIMIT` |
| `POST /chat/conversations/{id}/read` | — | `204` | 404 |

```
ConversationView {id, withPublicId, status, unread, lastMessageAt}
MessageView      {id, conversationId, senderId, type, text, mediaId, createdAt}
```

### WebSocket `wss://<domain>/ws/chat`

Bắt tay: HTTP Upgrade kèm `Authorization: Bearer <JWT>` (gateway gắn `X-Public-Id`; thiếu → `403`). Mỗi khung là JSON văn bản ≤ 16 KB, có trường `type`. Ping mỗi ≤ 60 giây (idle quá 120 giây bị ngắt).

| Hướng | Khung | Ý nghĩa |
|---|---|---|
| client → server | `{"type":"send","conversationId":"..","text":"..","clientId":"c-1"}` | Gửi văn bản |
| client → server | `{"type":"send","conversationId":"..","messageType":"IMAGE","mediaId":"..","clientId":"c-2"}` | Gửi ảnh |
| client → server | `{"type":"read","conversationId":".."}` | Đánh dấu đã đọc |
| client → server | `{"type":"ping"}` | Giữ kết nối |
| server → client | `{"type":"message","data":MessageView}` | Tin mới (cả tin của chính mình từ thiết bị khác) |
| server → client | `{"type":"ack","data":{"clientId":"c-1","messageId":".."}}` | Xác nhận đã lưu |
| server → client | `{"type":"read","data":{"conversationId":"..","by":"<publicId>"}}` | Bên kia đã đọc |
| server → client | `{"type":"closed","data":{"conversationId":"..","reason":"BLOCKED\|DELETED"}}` | Hội thoại bị đóng |
| server → client | `{"type":"error","data":{"code":"..","message":"..","clientId":".."}}` | Lỗi nghiệp vụ (không ngắt kết nối): `NOT_FOUND`, `FORBIDDEN`, `CHAT_RATE_LIMIT`, `INVALID_MESSAGE`, `BAD_FRAME`, `UNKNOWN_TYPE`, `INTERNAL_ERROR` |
| server → client | `{"type":"pong","data":{}}` | |

Tin ảnh: client tạo upload với `context=CHAT`, `refId=<conversationId>`, đợi `READY`, rồi gửi khung `send` kiểu `IMAGE`; người nhận lấy URL bằng `GET /media/{mediaId}/url`.

---

## 6.7 billing-service

| Method & đường dẫn | Mô tả | Request | Response | Lỗi |
|---|---|---|---|---|
| `GET /billing/products` | Danh mục đang bán | — | `[{sku, type, item, quantity}]` | |
| `GET /billing/me` | Gói hiện tại và ví | — | `{plan: FREE\|PRO, planExpiresAt, wallet:{BOOST:n,PRIORITY_INVITE:n}}` | |
| `POST /billing/purchases/verify` | Gửi giao dịch vừa mua/khôi phục; server tự hỏi store | `{store: APPLE\|GOOGLE\|DEV, sku, token}` (`token` = transactionId của Apple hoặc purchaseToken của Google) | `MeResponse` như `/me` | `400 UNKNOWN_PRODUCT`, `400 INVALID_RECEIPT`, `400 SKU_MISMATCH`, `400 RECEIPT_REVOKED`, `409 RECEIPT_ALREADY_USED`, `503 STORE_UNAVAILABLE` |
| `POST /webhooks/apple`, `POST /webhooks/google` | Thông báo từ store (công khai, **tự xác thực chữ ký**) | theo định dạng của store | `2xx` khi đã xử lý; `5xx` để store gửi lại | *(chưa có trong code tại thời điểm viết; cấu hình đã khai báo `public-paths: /webhooks/**`)* |

Client chỉ **kết thúc giao dịch với store** sau khi nhận `200` từ `verify`. `store=DEV` chỉ hoạt động khi `animal.billing.dev-store.enabled=true` (token `dev:<transactionId>[:<originalTransactionId>[:<expiresEpochSeconds>]]`) và **không bao giờ bật ở production**.

---

## 6.8 Nội bộ (không có route ở gateway)

Bảo vệ bằng header `X-Internal-Token` (`animal.internal-token`). Chỉ service trong mạng nội bộ gọi.

| Service | Endpoint | Dùng bởi | Mô tả |
|---|---|---|---|
| user | `GET /internal/identity/{sub}` | gateway | `sub → {publicId}`; 404 nếu chưa có hồ sơ |
| user | `GET /internal/users/{publicId}` | media, discovery | `{publicId, alias, leadAnimal, ageGroup, discoverable, active, pro}` |
| user | `GET /internal/users?ids=a,b` | post, discovery | danh sách như trên |
| user | `GET /internal/friends/{publicId}` | post, notification | `[publicId]` |
| user | `GET /internal/relationship?a=&b=` | media, chat | `{friends, blocked}` |
| user | `GET /internal/exclusions/{publicId}` | discovery | `{friends:[...], blockedEitherWay:[...]}` |
| user | `POST /internal/swipes/right` `{from,to}` | discovery | `{result}` |
| user | `GET /internal/devices/{publicId}` | notification | `[token]` |
| user | `DELETE /internal/devices/{token}` | notification | gỡ token FCM chết |
| media | `GET /internal/media/{id}` | chat | `{mediaId, ownerPublicId, context, status, publicKey}` |
| billing | `POST /internal/wallet/consume` `{publicId,item}` | discovery | `204`; `409 INSUFFICIENT_BALANCE`; `400 UNKNOWN_ITEM` |
| billing | `GET /internal/wallet/{publicId}` | — | `{item: balance}` |

> Lưu ý: `consume` dùng `UUID` ngẫu nhiên làm `ref` sổ cái nên **không idempotent** nếu discovery gọi lại do timeout. Với Boost (giá trị nhỏ) chấp nhận được; nếu cần chặt hơn, discovery nên gửi kèm `ref` ổn định.

## 6.9 Endpoint của gateway

| Đường dẫn | Mô tả |
|---|---|
| `/fallback/default` | 503 problem+json khi mạch mở |
| `/fallback/discovery` | `{"cards":[],"degraded":true}` |
| `/actuator/health/**`, `/actuator/prometheus` | Công khai ở tầng gateway; **Traefik không được định tuyến** hai đường này ra Internet |
