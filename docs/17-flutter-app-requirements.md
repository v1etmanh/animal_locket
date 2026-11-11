# 17. Requirement app Flutter (iOS + Android)

> Mục đích: tài liệu giao việc cho đội làm app. Nguồn sự thật cho API là [06-api-reference.md](06-api-reference.md) (lấy từ code); nguồn cho giao diện là bản thiết kế "Giao diện Animal Locket" (10 màn hình, https://claude.ai/artifact/AHoi73tY2ULi48dm1j8WG9).
> Ghi chú độ tin cậy: mô tả màn **Camera, Feed, Chat** chưa được đối chiếu với file thiết kế (suy ra từ tên màn và API) — người làm phải mở thiết kế để xác nhận. Backend **chưa chạy thử trên hạ tầng thật** (xem CLAUDE.md), nên mọi tích hợp cần có mock server (mục 8).

## 1. Phạm vi

- Nền tảng: Flutter (Dart 3), iOS + Android. Không làm web.
- Ngôn ngữ giao diện: tiếng Việt (chuẩn bị sẵn `intl`/ARB để thêm ngôn ngữ).
- Ngoài phạm vi bản đầu: admin/quản trị, voice/video call, feed công khai, tuỳ chỉnh từng loại thông báo (F2), hoàn tác quẹt trái (D9 — backend chưa có API).

## 2. Khuyến nghị kỹ thuật (có thể đổi)

| Hạng mục | Đề xuất |
|---|---|
| Kiến trúc | Feature-first: `features/<tên>/{data,domain,presentation}` |
| State | Riverpod |
| HTTP | `dio` + interceptor gắn `Authorization`, tự refresh token, map lỗi RFC 7807 theo trường `code` |
| Đăng nhập | OIDC với Keycloak (`flutter_appauth`), lưu token ở `flutter_secure_storage` |
| Điều hướng | `go_router` (thanh dưới 4 tab: Ảnh, Khám phá, Chat, Hồ sơ) |
| WebSocket | `web_socket_channel`, tự nối lại có backoff |
| Push | `firebase_messaging` → `PUT /devices` |
| Camera/ảnh | `camera`, `image_picker` |
| Mua hàng | `in_app_purchase` |
| Vị trí | `geolocator` (chỉ khi người dùng bật khám phá) |
| Cấu hình | `--dart-define`: `API_BASE_URL`, `WS_URL`, `KEYCLOAK_ISSUER`, `KEYCLOAK_CLIENT_ID`. Không commit bí mật |

Client **không** được gửi `X-Public-Id` (gateway tự gắn). Mọi request kèm `Authorization: Bearer <JWT>`.

## 3. Phong cách giao diện (rút từ thiết kế)

**Khung chuẩn**: 390×844 pt. Nền dốc dọc `#FFFFFF → #FBFAFD (60%) → #F4F1F9`. Chữ chính `#1E1B2E`, chữ phụ `#5F5878`. Viền nhạt `#E8E5EE`.

**Phông chữ** (Google Fonts): tiêu đề `Fraunces` 500 (26–38 px); nội dung `Plus Jakarta Sans` 400/500/700 (11–17 px). Nhãn nhỏ viết hoa: 12–13 px, 700, giãn chữ `.04–.08em`, màu tím.

**Màu**

| Vai trò | Mã |
|---|---|
| Nhấn tím (liên kết, tab đang chọn, tiến trình) | `#7C4DDB`, nét vẽ tay `#B79CF0` |
| Nút chính (cam) | gradient `#FFB877 → #FF8F45`, chữ `#2B1400`; viền chọn `#FF9B57` |
| Nút thành công / "Quay" | gradient `#2FC49C → #0D8466`, chữ trắng; chấm online `#0D8466` |
| Huy hiệu báo | nền `#D63B45`, chữ trắng |
| Màu thẻ/ô (pastel, xoay vòng) | vàng `#FFF1C2`, xanh ngọc `#B1EEF3`, lá `#D0F7A3`, cam nhạt `#F5D3B3`, tím nhạt `#E6DDF5`, đào `#FCE3CB` |

**Thành phần**

- **Kính (glass)** cho nút phụ, ô nhập, thanh tab, thẻ nổi: nền gradient trắng `.95 → .55`, `BackdropFilter` blur 16 + bão hoà 1.4, đổ bóng `0 10 26 rgba(30,27,46,.12)`, bóng trong sáng ở trên / tím nhạt ở dưới, viền trong trắng. Bọc thành một widget `GlassContainer` dùng lại ở mọi nơi.
- **Nút chính**: cao 54–60, bo 18, bóng cam đậm; nút tròn quẹt phải 72 px, bỏ qua 64 px, Boost 48 px.
- **Bo góc**: thẻ lớn 32–36, ô danh sách 20, nút 14–18, chip/pill 16–24.
- **Ảnh con vật**: PNG nền trong suốt, đặt trong vòng tròn pastel, `blendMode: multiply`, phóng ~116–132% để cắt gọn. Cần bộ asset con vật từ designer (xem mục 9).
- **Thanh dưới**: nổi, bo 32, kính, 4 tab; tab đang chọn tím `#7C4DDB`, chữ đậm 700.
- **Chạm**: vùng bấm ≥ 44×44. Mọi icon thuần biểu tượng phải có `Semantics` label (thiết kế đã có `aria-label` tiếng Việt).
- Trạng thái chưa mở: ô viền đứt `#E8E5EE` dấu "?".

## 4. Danh sách màn hình (10 màn + 3 màn phụ)

Tổng **13 màn**: 10 màn trong thiết kế (S01–S10) và 3 màn thiết kế chưa vẽ nhưng backend bắt buộc (S11–S13). Ước lượng là số ngày công cho một dev Flutter có kinh nghiệm, **chưa kể** thời gian chờ backend thật.

| Mã | Màn hình | Tab | Chức năng chính | API dùng | Ước lượng |
|---|---|---|---|---|---|
| S01 | Chào & đăng nhập (`Main`) | — | Đăng nhập Google / Apple / số điện thoại qua Keycloak; dòng cam kết riêng tư | Keycloak OIDC | 2 |
| S02 | Nhận con vật đầu tiên (`Reveal`) | — | Hiện con vật được cấp, đặt/ngẫu nhiên biệt danh, nhập ngày sinh (xem S11), nút "Vào app" | `POST /users/register`, `GET /users/me` | 2 |
| S03 | Camera (`Camera`)* | Ảnh | Chụp/chọn ảnh, bật tắt đèn/lật camera, xin quyền | — (cục bộ) | 3 |
| S04 | Xem trước & đổi mặt (`Preview`) | Ảnh | Upload ảnh 3 bước, thanh tiến trình đổi mặt, chọn người nhận, lời nhắn, "Chụp lại" / "Gửi khi xong" | `/media/*`, `POST /posts`, `GET /friends` | 5 |
| S05 | Feed bạn bè (`Feed`)* | Ảnh | Danh sách bài, like, bình luận, xoá bài mình, kéo làm mới, tải thêm | `/feed`, `/posts/*`, `/media/{id}/url` | 5 |
| S06 | Khám phá (`Discover`) | Khám phá | Chồng thẻ, quẹt trái/phải, Boost, còn N lượt, nút "Bạn bè (badge)" | `/discovery/*` | 5 |
| S07 | Bạn bè & lời mời (`Friends`) | Khám phá | 3 tab Bạn bè / Lời mời / Đã gửi; chấp nhận, từ chối, huỷ; thẻ "N người đã quẹt phải bạn" (Pro) | `/friends/*` | 3 |
| S08 | Chat (`Chat`)* | Chat | Danh sách hội thoại + màn trò chuyện thời gian thực, chưa đọc, gửi ảnh | `/chat/*`, `WS /ws/chat` | 8 |
| S09 | Hồ sơ (`Profile`) | Hồ sơ | Avatar, thống kê, bộ sưu tập, đổi biệt danh (quay thưởng đã ngừng) | `/users/me*`, `/animals` | 4 |
| S10 | Paywall Pro (`Pro`) | — | Lợi ích Pro, chọn gói 1/6/12 tháng, mua, khôi phục giao dịch | `/billing/*` + store | 4 |
| S11 | Ngày sinh & đồng ý điều khoản | — | Chọn ngày sinh (bắt buộc, quyết định nhóm tuổi), tick điều khoản | `POST /users/register` | 1 |
| S12 | Cài đặt & riêng tư | Hồ sơ | Bật/tắt khám phá, danh sách đã chặn, đăng xuất, **xoá tài khoản** (xác nhận 2 bước) | `PATCH/DELETE /users/me`, `/blocks`, `/discovery/location` | 3 |
| S13 | Hồ sơ người khác (bottom sheet) | — | Xem alias + con vật, chặn, báo cáo, huỷ kết bạn, nhắn tin | `GET /users/{id}`, `/blocks`, `/reports`, `/friends/{id}` | 3 |

\* chưa đối chiếu thiết kế.

Cộng thêm nền tảng chung (khung app, theme, `GlassContainer`, API client, auth, WebSocket, push, xử lý lỗi/offline): **~10 ngày**. Tổng ước lượng ≈ **58 ngày công** (1 dev), chưa gồm QA.

### Chi tiết hành vi theo màn hình

**S01 – Đăng nhập**: 3 nút (Google, Apple, SĐT). Sau khi có token: `GET /users/me`; `404`/`403 PROFILE_REQUIRED` → S11/S02 để đăng ký; có hồ sơ → vào tab Ảnh. Apple bắt buộc có trên iOS nếu có đăng nhập mạng xã hội khác. *Lưu ý*: PRD (A1) chỉ nêu email/mạng xã hội; **đăng nhập bằng số điện thoại cần xác nhận Keycloak có cấu hình**.

**S02 – Con vật đầu tiên**: gọi `register` với `birthDate` (từ S11) và `alias` (tuỳ chọn; để trống thì server gợi ý). Nút xúc xắc đặt biệt danh ngẫu nhiên là **logic phía client** (API không có endpoint này; danh sách từ ghép do client giữ). Lỗi `INVALID_ALIAS`, `INVALID_BIRTHDATE` hiện ngay dưới ô nhập. Gọi lại `register` là an toàn (idempotent).

**S03/S04 – Đăng ảnh** (luồng 5 bước trong tài liệu 06 §6.3):
1. `POST /media/uploads {context:"POST", contentType, sizeBytes}` — ảnh ≤ 10 MB; client nén lại **và xoá EXIF/GPS** (`keepExif: false`) trước khi gửi.
2. `PUT <uploadUrl>` thân là file, gửi thẳng Cloudflare R2, gắn đúng các `headers` nhận được (`Content-Type`). Không gắn `Authorization` vào request này.
3. `POST /media/{id}/complete` → trả ngay `READY` hoặc `REJECTED` (`FILE_TOO_LARGE`/`UNSUPPORTED_MEDIA_TYPE`).
4. `POST /posts {mediaId, caption≤200}` → bài `PENDING_MEDIA`, chuyển `PUBLISHED` khi post-service nhận `PHOTO_READY` (thường dưới vài giây).
5. `REJECTED` → hiện `rejectReason`, cho "Chụp lại".

~~Thanh "Đang đổi mặt thành <con vật> 68%"~~: không còn bước đổi mặt (ADR-014); chỉ cần tiến trình upload. Chọn người nhận "Tất cả / từng bạn": **API tạo bài không có tham số người nhận** (bài hiển thị cho mọi bạn bè). Cần quyết định: bỏ phần chọn người nhận hoặc yêu cầu backend bổ sung (xem mục 7, câu hỏi Q1).

**S05 – Feed**: `GET /feed?limit=20`, trang kế bằng `before=nextBefore`. `degraded:true` → hiện banner "Đang tải chậm", không coi là lỗi. Ảnh lấy bằng `GET /media/{mediaId}/url` (URL hết hạn sau 600 s: cache theo `expiresInSeconds`, gọi lại khi hết hạn). `author.alias/leadAnimal` có thể `null` → hiện placeholder. Like là `PUT/DELETE` idempotent, cập nhật lạc quan và hoàn lại nếu lỗi. Bình luận phân trang `after`. Bài `PENDING_MEDIA`/`REJECTED` của mình xem qua `GET /posts/mine`.

**S06 – Khám phá**:
- Vào màn: kiểm tra `discoverable` (từ `/users/me`). Chưa bật → màn giải thích + nút bật (`PATCH /users/me`), xin quyền vị trí, rồi `PUT /discovery/location`. Từ chối quyền vị trí vẫn dùng được ở chế độ chỉ "online" (thẻ khi đó `distanceBand=null`).
- Gọi `POST /discovery/heartbeat` mỗi 30 s khi app ở foreground và đang ở tab Khám phá.
- `GET /discovery/cards?limit=20`. Hiện chip: "Đang online" (`online`), khoảng cách theo `distanceBand` (`UNDER_1KM`→"dưới 1 km", `1_TO_3KM`→"1–3 km", `3_TO_10KM`→"3–10 km", `OVER_10KM`→"trên 10 km", `UNDER_3KM`→"dưới 3 km"; `null` → ẩn chip), "<con vật> · độ hiếm" (độ hiếm lấy từ danh mục `/animals`). Thẻ `boosted` có dấu hiệu nhỏ.
- Quẹt phải/trái → `POST /discovery/swipes`; kết quả `MATCHED` → màn chúc mừng nhỏ "Đã thành bạn" + nút nhắn tin. `swipesLeftToday` hiển thị "Còn N lượt quẹt phải hôm nay". `SWIPE_LIMIT` → dẫn tới S10. Hết thẻ → trạng thái rỗng + nút tải lại. Cache bộ thẻ, tải trước khi còn 3 thẻ.
- Boost: `POST /discovery/boost`; `NO_BOOST` → gợi ý mua; hiện số dư từ `/billing/me`.
- Tuân thủ rate limit khám phá (2 req/s): không gọi `cards` dồn dập; `TOO_MANY_SEARCHES` → hiện thời gian chờ.
- Thẻ không có toạ độ/ảnh thật: **không** cố hiển thị hay lưu thêm thông tin định danh.

**S07 – Bạn bè**: tab "Bạn bè" `GET /friends`; "Lời mời" `GET /friends/requests/incoming` (chấp nhận/từ chối, badge đếm); "Đã gửi" `.../outgoing` (huỷ). Lời mời trả `PublicProfile` **không có khoảng cách** → dòng phụ "Cách bạn …" trong thiết kế **không lấy được** từ API này (xem Q3). Thẻ "N người đã quẹt phải bạn": **backend chưa có API** — hiện ẩn/khoá cho tới khi có (Q2). Hiện trạng thái online của bạn: `GET /discovery/presence?ids=…` (≤ 200 id).

**S08 – Chat**:
- Danh sách `GET /chat/conversations` (đã sắp xếp); mỗi dòng cần alias + con vật → gọi `GET /users/{withPublicId}` và cache (chat không trả sẵn).
- Mở hội thoại: `GET .../messages?limit=30` (mới nhất trước; `before` để tải cũ hơn), đảo thứ tự khi hiển thị. Gửi qua WebSocket `send` kèm `clientId`; hiện "đang gửi" tới khi nhận `ack`; không có ack/`error` → nút gửi lại. Khi WS mất thì rơi về `POST .../messages`.
- WS: `wss://<domain>/ws/chat`, header `Authorization`, ping ≤ 60 s, tự nối lại backoff 1→30 s. Xử lý `message`, `ack`, `read`, `closed` (BLOCKED/DELETED → khoá ô nhập, ẩn hội thoại), `error` (hiện theo `code`).
- Gửi `read` khi mở hội thoại / có tin mới lúc đang xem; `POST .../read` làm dự phòng.
- Gửi ảnh: upload `context=CHAT, refId=<conversationId>`, đợi `READY` (hỏi `GET /media/{id}`), rồi gửi `IMAGE`. Nhận ảnh: `GET /media/{id}/url`. `MEDIA_NOT_READY (409)` → chờ và thử lại.
- Tạo hội thoại từ S13/S07: `POST /chat/conversations {withPublicId}`; `403` → "Chỉ nhắn được với bạn bè".

**S09 – Hồ sơ**: `GET /users/me`, `GET /users/me/animals`, `GET /animals` (đếm "5 / 24"). **Không có API thống kê** "Bạn bè", "Ảnh đã gửi": lấy bạn bè = `length` của `/friends`; "ảnh đã gửi" = số bài `PUBLISHED` từ `/posts/mine` (giới hạn `limit` 50 nên có thể thiếu → xem Q4, hoặc ẩn ô này). ~~Quay thưởng (`POST /users/me/spin`) và đổi con vật chủ đạo (`PUT /users/me/lead-animal`)~~ — **đã ngừng**, server trả `410 FEATURE_RETIRED`; ẩn hai nút này. Hồ sơ hiển thị avatar duy nhất của người dùng (`avatar` trong `/users/me`, vẽ bằng `AnimalAvatar`, xem docs/19). Sửa biệt danh: `PATCH /users/me`; `ALIAS_COOLDOWN` hiện "chỉ đổi được 1 lần/24 giờ". Bộ sưu tập: chạm một avatar để đặt làm avatar chính (`PUT /users/me/avatar`); khi `avatarSpins > 0` hiện nút mở màn quay (`/avatar-spin` → `POST /users/me/avatar/spin`), xem docs/19 §8.

**S10 – Paywall**: lấy `GET /billing/products` (sku/loại/số lượng) rồi hỏi store lấy **giá hiển thị thật** (giá trong thiết kế `[Giá tháng]`… là chỗ giữ chỗ — không hard-code giá). Mua xong → `POST /billing/purchases/verify {store: APPLE|GOOGLE, sku, token}`; **chỉ gọi `completePurchase` với store sau khi nhận 200**. "Khôi phục giao dịch" gọi lại `verify` cho từng giao dịch cũ. Sau thành công làm mới `/billing/me` và `/users/me` (`plan`). Xử lý `RECEIPT_ALREADY_USED`, `STORE_UNAVAILABLE` (thử lại), `INVALID_RECEIPT`. Tài khoản dưới 18 (`ageGroup=MINOR`): **không hiện** nút mua/ưu đãi gây áp lực (theo tài liệu 02 §2.7–2.8). Không dùng `store=DEV` trong bản phát hành.

**S12 – Cài đặt**: xoá tài khoản `DELETE /users/me` (503 nếu Keycloak lỗi → cho thử lại), sau đó xoá token cục bộ, gỡ `DELETE /devices/{token}` **trước** khi xoá, huỷ WS. Tắt khám phá gọi thêm `DELETE /discovery/location`.

**S13 – Hồ sơ người khác**: báo cáo `POST /reports {targetType, targetPublicId, reason≤30, details≤500}`; chặn `PUT /blocks/{id}` (xác nhận trước; sau đó đóng hội thoại, bỏ khỏi danh sách).

## 5. Danh mục API client cần gọi

Tất cả qua `API_BASE_URL/api/v1`. Chi tiết request/response/lỗi: tài liệu 06.

| Nhóm | Endpoint | Màn dùng |
|---|---|---|
| Hồ sơ | `POST /users/register`, `GET/PATCH/DELETE /users/me`, `GET /users/{publicId}`, `GET /users/me/animals`, `GET /animals` (`PUT /users/me/lead-animal`, `POST /users/me/spin` đã ngừng → `410`) | S02, S09, S12, S13 |
| Bạn bè | `GET /friends`, `DELETE /friends/{id}`, `GET /friends/requests/incoming|outgoing`, `POST /friends/requests`, `POST /friends/requests/{id}/accept|decline`, `DELETE /friends/requests/{id}` | S04, S07, S13 |
| An toàn | `GET /blocks`, `PUT|DELETE /blocks/{id}`, `POST /reports` | S12, S13 |
| Thiết bị | `PUT /devices`, `DELETE /devices/{token}` | khởi động, S12 |
| Media | `POST /media/uploads`, upload multipart tới `uploadUrl`, `POST /media/{id}/complete`, `GET /media/{id}`, `GET /media/{id}/url` | S04, S05, S08 |
| Bài viết | `POST /posts`, `GET /posts/mine`, `GET /posts/{id}`, `DELETE /posts/{id}`, `GET /feed`, `PUT|DELETE /posts/{id}/like`, `POST|GET /posts/{id}/comments`, `DELETE /posts/{id}/comments/{cid}` | S04, S05 |
| Khám phá | `PUT|DELETE /discovery/location`, `POST /discovery/heartbeat`, `GET /discovery/presence`, `GET /discovery/cards`, `POST /discovery/swipes`, `POST /discovery/boost` | S06, S07, S12 |
| Chat | `POST|GET /chat/conversations`, `GET|POST /chat/conversations/{id}/messages`, `POST /chat/conversations/{id}/read`, `WS /ws/chat` | S08 |
| Thanh toán | `GET /billing/products`, `GET /billing/me`, `POST /billing/purchases/verify` | S06, S10 |

**Không gọi từ app**: mọi `/internal/**`, `/webhooks/**`, `/actuator/**`.

### Xử lý lỗi chung (bắt buộc)

- Lỗi RFC 7807: dựa vào `code`, không dựa `detail`. Bảng `code` → câu tiếng Việt đặt ở một chỗ (`error_messages.dart`), mọi mã chưa biết rơi về thông báo chung.
- `401` → thử refresh token một lần, thất bại thì về S01. `403 PROFILE_REQUIRED` → về S02/S11.
- `429` (kể cả không có `code`) → hiện "Thao tác quá nhanh", tôn trọng `Retry-After` nếu có; không tự động thử lại dồn dập.
- `503`/mạng lỗi → trạng thái lỗi có nút "Thử lại"; GET được thử lại tự động tối đa 2 lần với backoff; **POST không tự thử lại** (không có Idempotency-Key).
- Phân trang: mỗi nơi một kiểu (`before`/`after`), `limit` tối đa 50 (feed/bình luận), 100 (chat).
- Thời gian ISO-8601 UTC → hiển thị theo giờ địa phương. Thời gian so sánh/gửi lên giữ nguyên chuỗi server trả (độ phân giải mili-giây).

## 6. Yêu cầu phi chức năng

- **Riêng tư**: không ghi log token, ảnh, vị trí, nội dung chat. Không lưu ảnh gốc lâu; xoá file tạm sau upload. Vị trí chỉ gửi khi đã bật khám phá; tắt thì xoá. Không chụp màn hình lộ dữ liệu trong crash report.
- **Lưu trữ an toàn**: token trong Keychain/Keystore. Không nhúng bí mật vào mã nguồn.
- **Hiệu năng**: feed cuộn 60 fps; ảnh dùng `cached_network_image` có khoá theo `mediaId` (không theo URL vì URL đổi mỗi lần); khởi động nguội < 3 s trên máy tầm trung.
- **Offline**: đọc được feed/chat đã tải gần nhất; gửi tin/ảnh khi mất mạng xếp hàng hoặc báo lỗi rõ ràng.
- **Truy cập**: hỗ trợ cỡ chữ hệ thống, nhãn `Semantics`, tương phản chữ ≥ 4.5:1.
- **Quyền hệ thống**: camera, thư viện ảnh, vị trí (khi dùng), thông báo — mỗi quyền có màn giải thích trước khi xin.
- **Cửa hàng**: iOS cần Sign in with Apple; mô tả quyền riêng tư (App Privacy / Data Safety) phải khai báo vị trí thô, ảnh, định danh thiết bị.

## 7. Câu hỏi mở / khoảng trống giữa thiết kế và backend

| # | Vấn đề | Đề xuất |
|---|---|---|
| Q1 | Thiết kế (S04) cho chọn người nhận ảnh; `POST /posts` không có tham số người nhận | Bản đầu: bỏ chọn người nhận (gửi cho toàn bộ bạn bè), hoặc backend thêm `audience` |
| Q2 | "Xem ai đã quẹt phải bạn" (Pro, S07/S10) chưa có API | Ẩn thẻ này ở bản đầu, hoặc backend bổ sung endpoint |
| Q3 | Lời mời kết bạn không trả khoảng cách / độ hiếm con vật | Bỏ dòng "Cách bạn …" ở S07, hoặc backend bổ sung `distanceBand` |
| Q4 | Thống kê hồ sơ (bạn bè, ảnh đã gửi) không có API; "Còn N lượt quay" không có | Tính phía client như S09; hoặc backend thêm `GET /users/me/stats` |
| Q5 | Thanh tiến trình đổi mặt không có % thật | Dùng tiến trình ước lượng + trạng thái thật (`UPLOADED`→`READY`) |
| Q6 | Đăng nhập SĐT chưa nằm trong PRD (A1) | Xác nhận Keycloak hỗ trợ; nếu không thì bỏ nút |
| Q7 | Hoàn tác quẹt (Pro) chưa có API (D9 còn là câu hỏi mở) | Không làm ở bản đầu; bỏ khỏi danh sách lợi ích Pro hoặc ghi "sắp có" |
| Q8 | Webhook Apple/Google trong tài liệu 06 ghi "chưa có trong code" | App vẫn chạy với `verify`; gia hạn/huỷ tự động có thể chưa cập nhật `plan` — cần kiểm tra |
| Q9 | Tên con vật + độ hiếm (Phổ thông/Hiếm) khác enum API (`COMMON|RARE|EPIC`) | Map: COMMON→"Phổ thông", RARE→"Hiếm", EPIC→"Sử thi" (xác nhận với thiết kế) |

## 8. Kiểm thử

### 8.1 Chiến lược

| Tầng | Công cụ | Phạm vi | Chỉ tiêu |
|---|---|---|---|
| Unit | `flutter_test`, `mocktail` | repository, mapper DTO, bộ map lỗi `code`, logic phân trang, hàng đợi tin nhắn, tính tiến trình ảnh | ≥ 80% dòng ở `domain/` và `data/` |
| Widget | `flutter_test` + golden | mỗi màn S01–S13 ở các trạng thái: tải, rỗng, lỗi, dữ liệu | mỗi màn ≥ 3 golden (so ảnh với thiết kế) |
| Contract | mock server + file mẫu JSON | DTO khớp tài liệu 06 (kể cả `null` của `alias`/`distanceBand`) | mọi endpoint ở mục 5 có ≥ 1 mẫu thành công + 1 mẫu lỗi |
| Tích hợp | `integration_test` | các luồng ở 8.2 chạy với mock server (backend giả `dio` adapter hoặc `shelf`) | chạy được trên CI (emulator) |
| E2E với backend thật | thủ công / Patrol | các luồng cốt lõi sau khi hạ tầng sẵn sàng | **chưa thực hiện được** cho tới khi Docker Compose/Keycloak được kiểm chứng |
| Thiết bị | thủ công | camera, vị trí, push, mua hàng (sandbox Apple/Google), 2 hệ điều hành, 3 cỡ màn | bảng thiết bị ở 8.4 |

Mock server: dựng bằng file JSON theo tài liệu 06 (kèm bộ giả lập WebSocket). Đây là điều kiện để làm app song song với backend.

### 8.2 Kịch bản kiểm thử chức năng (test case chính)

Mỗi dòng là một test case tối thiểu; người nhận việc bổ sung biên.

**Đăng nhập / đăng ký (S01, S02, S11)**
- T01 Người dùng mới: đăng nhập → 403 `PROFILE_REQUIRED` → nhập ngày sinh → `register` 201 → thấy con vật + biệt danh → vào app.
- T02 Người dùng cũ: đăng nhập → `GET /users/me` 200 → vào thẳng tab Ảnh.
- T03 Ngày sinh không hợp lệ/tương lai → hiện lỗi `INVALID_BIRTHDATE`, không gọi lại vô hạn.
- T04 Alias 2 ký tự hoặc ký tự cấm → `INVALID_ALIAS` hiện dưới ô nhập; bấm xúc xắc tạo alias hợp lệ (3–20).
- T05 Token hết hạn giữa chừng → tự refresh; refresh hỏng → về S01, xoá dữ liệu cục bộ.

**Đăng ảnh (S03, S04)**
- T10 Chụp → upload → `complete` → tạo bài → `READY` → bài `PUBLISHED` hiện ở "Ảnh của tôi".
- T11 Ảnh > 10 MB: tự nén dưới 10 MB hoặc báo `FILE_TOO_LARGE`.
- T12 Định dạng HEIC được chấp nhận; định dạng khác bị chặn trước khi upload (`UNSUPPORTED_MEDIA_TYPE`).
- T13 Upload multipart: `file` là trường cuối; sai thứ tự → lỗi được báo, không treo.
- T14 `REJECTED` → hiện lý do + "Chụp lại"; không tạo bài trùng.
- T15 `PHOTO_LIMIT`/`UPLOAD_LIMIT` (429) → thông báo hạn mức, gợi ý Pro (chỉ người lớn).
- T16 Mất mạng giữa bước 2 → báo lỗi, cho thử lại từ đầu; không để `mediaId` mồ côi gây đăng đôi.
- T17 Đóng app khi đang xử lý → mở lại vẫn thấy bài `PENDING_MEDIA` (từ `/posts/mine`) và nhận kết quả.

**Feed (S05)**
- T20 Tải trang đầu; kéo xuống nối trang bằng `nextBefore`; hết dữ liệu dừng.
- T21 `degraded:true` → banner, không crash, `items` rỗng không hiện "chưa có bạn".
- T22 Like/Unlike lạc quan; lỗi mạng → hoàn lại số đếm.
- T23 Bình luận: gửi, phân trang `after`; xoá được khi là tác giả bình luận hoặc tác giả bài, ngược lại `403` ẩn nút.
- T24 `author.alias=null` → placeholder, không crash.
- T25 URL ảnh hết hạn (600 s) → tự lấy lại, không hiện ảnh lỗi vĩnh viễn.
- T26 Xoá bài của mình → biến mất khỏi feed.

**Khám phá (S06)**
- T30 Chưa bật khám phá → màn bật; bật + cho phép vị trí → `PUT location` → có thẻ.
- T31 Từ chối quyền vị trí → vẫn có thẻ online, chip khoảng cách ẩn khi `distanceBand=null`.
- T32 Quẹt phải → `REQUESTED`; quẹt phải người đã mời mình → `MATCHED` → hiện màn thành bạn.
- T33 `SWIPE_LIMIT` → khoá nút quẹt phải, hiện lời mời nâng cấp Pro (người lớn), "Còn 0 lượt".
- T34 `degraded:true` hoặc 503 → trạng thái rỗng có "Thử lại", không crash.
- T35 Boost thành công (204) / `NO_BOOST` (402) → tương ứng.
- T36 Rời tab/app nền → ngừng heartbeat; quay lại tiếp tục.
- T37 Tắt khám phá → xoá vị trí (`DELETE /discovery/location`) và không gửi thêm vị trí.
- T38 Tài khoản `MINOR` hiển thị khoảng cách theo thang dưới 18 (`UNDER_3KM`…).

**Bạn bè (S07, S13)**
- T40 Chấp nhận/từ chối/huỷ lời mời cập nhật danh sách và badge; `404` (lời mời đã mất) → làm mới danh sách.
- T41 Huỷ kết bạn có xác nhận.
- T42 Chặn → người đó biến mất khỏi danh sách bạn/hội thoại; "Bỏ chặn" trong S12 hoạt động.
- T43 Báo cáo: gửi thành công; `REPORT_LIMIT` hiện thông báo; `reason` > 30 ký tự bị chặn ở form.
- T44 Gửi lời mời cho người khác nhóm tuổi (403) → thông báo thân thiện.

**Chat (S08)**
- T50 Danh sách hội thoại mới nhất trước, đếm `unread`, xoá badge sau khi đọc.
- T51 Gửi tin qua WS: trạng thái đang gửi → `ack` → đã gửi; không có ack sau 10 s → có nút gửi lại với `clientId` mới.
- T52 Nhận tin realtime khi đang mở và khi đang ở danh sách; tin từ thiết bị khác của mình cũng hiện.
- T53 Mất kết nối WS → tự nối lại; trong lúc đó vẫn gửi được qua REST.
- T54 `closed` (BLOCKED/DELETED) → khoá ô nhập, hiện thông báo.
- T55 Gửi ảnh: upload `context=CHAT` → `READY` → gửi `IMAGE`; `MEDIA_NOT_READY` → chờ/thử lại.
- T56 Vượt `CHAT_RATE_LIMIT` → thông báo, không mất nội dung đã gõ.
- T57 Tin quá 2000 ký tự bị chặn ở UI.

**Hồ sơ & Pro (S09, S10, S12)**
- ~~T60, T61 (quay thưởng, đổi con vật chủ đạo)~~ — đã ngừng; thay bằng: hồ sơ không có nút quay/đổi con vật, avatar hiển thị đúng `avatar` từ `/users/me`.
- T62 Đổi biệt danh lần 2 trong 24 giờ → `ALIAS_COOLDOWN`.
- T63 Mua Pro (sandbox): `verify` 200 → `plan=PRO`, giao dịch được kết thúc với store; `verify` lỗi → **không** kết thúc giao dịch, cho thử lại.
- T64 Khôi phục giao dịch trên máy mới; `RECEIPT_ALREADY_USED` được xử lý.
- T65 Tài khoản `MINOR` không thấy nút mua/ưu đãi.
- T66 Xoá tài khoản: xác nhận 2 bước → `204` → xoá token/dữ liệu cục bộ → về S01. Keycloak 503 → báo lỗi, tài khoản vẫn còn.
- T67 Đăng xuất gỡ token thiết bị khỏi push.

**Push**
- T70 Xin quyền thông báo; `PUT /devices` với `platform` đúng; token đổi → cập nhật.
- T71 Chạm thông báo mở đúng màn đích (bài, hội thoại, lời mời).

### 8.3 Kiểm thử phi chức năng

- Bảo mật: không có token/URL ảnh có chữ ký trong log; ảnh cache không nằm ở vùng chia sẻ; build release tắt `debugPrint`.
- Hiệu năng: feed 200 bài cuộn không giật; bộ nhớ ổn định sau 5 phút lướt thẻ khám phá.
- Giới hạn: kiểm tra hành vi khi gặp `429` liên tiếp không tạo vòng lặp thử lại.
- Truy cập: font hệ thống 200%, TalkBack/VoiceOver đọc đúng nhãn các nút icon (X, tim, tia chớp, quay lại, đóng, cài đặt).

### 8.4 Ma trận thiết bị tối thiểu

iOS 16+ (iPhone SE, iPhone 15), Android 9+ (máy tầm thấp 3 GB RAM, Pixel mới). Kiểm thử camera, push, vị trí, mua hàng sandbox bắt buộc trên **máy thật**.

## 9. Bàn giao & tiêu chí nghiệm thu

**Designer/backend cung cấp trước**
- Bộ ảnh con vật PNG trong suốt (24 loại trong thiết kế "5 / 24") theo `animal.code` + bảng màu nền pastel từng con; màu xoay vòng được thì không cần.
- Môi trường dev (URL gateway, Keycloak realm/client, WS URL) **hoặc** mock server; tài khoản test.
- Danh sách SKU sandbox ở App Store Connect / Play Console khớp `GET /billing/products`.
- Project Firebase (FCM) cho iOS/Android.

**Nghiệm thu một màn hình khi**
1. Giống thiết kế (golden được duyệt) ở 3 cỡ màn, chế độ chữ lớn không vỡ bố cục.
2. Đủ trạng thái tải / rỗng / lỗi / hết quyền.
3. Mọi mã lỗi trong tài liệu 06 cho endpoint màn đó đều có xử lý và thông báo tiếng Việt.
4. Có test unit + widget + (nếu thuộc luồng ở 8.2) integration test đi kèm, CI xanh (`flutter analyze`, `flutter test`).
5. Không có dữ liệu nhạy cảm trong log; không lộ `publicId` người khác ngoài những gì API vốn trả.

**Nghiệm thu cả app khi**: toàn bộ T01–T71 qua trên mock server; T01, T10, T20, T32, T50, T63 qua trên backend thật (khi hạ tầng sẵn sàng) và được ghi nhận riêng.

## 10. Thứ tự đề xuất

1. **Nền tảng** (10 ngày): theme + `GlassContainer`, API client, auth Keycloak, mock server, khung tab.
2. **Vòng 1 – Vào app**: S01, S11, S02, S09 (xem), S12.
3. **Vòng 2 – Lõi giá trị**: S03, S04, S05.
4. **Vòng 3 – Kết bạn**: S06, S07, S13.
5. **Vòng 4 – Trò chuyện**: S08 (REST trước, WebSocket sau), push.
6. **Vòng 5 – Kiếm tiền & hoàn thiện**: S10, quay thưởng, đổi con vật, hạ tầng test thiết bị.

Các màn ở vòng 2–4 có thể giao cho nhiều người cùng lúc sau khi xong vòng nền tảng, vì chúng chỉ phụ thuộc vào API client, theme và mock server.
