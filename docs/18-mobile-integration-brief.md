# 18. Brief giao việc: hoàn thiện app Flutter và nối với backend thật

> Dành cho một AI/dev tiếp nhận `mobile/`. Đọc hết file này trước khi viết code. Ngày lập: 2026-11-06.
> Tài liệu liên quan (đọc khi cần, không chép lại): [06-api-reference.md](06-api-reference.md) (hợp đồng API, lấy từ code),
> [17-flutter-app-requirements.md](17-flutter-app-requirements.md) (màn hình S01–S13, hành vi chi tiết, câu hỏi mở Q1–Q9),
> [09-privacy-safety-security.md](09-privacy-safety-security.md), `../CLAUDE.md` (cạm bẫy đã gặp).
>
> **Cập nhật 2026-11-08**: sau ngày lập, kho ảnh đã chuyển từ MinIO sang **Cloudflare R2** (upload bằng presigned **PUT**, không còn `files.<domain>`/`MINIO_PUBLIC_ENDPOINT`) và **face-worker đã gỡ** (ảnh không còn bị che mặt, `complete` trả `READY` ngay). Các mục hướng dẫn bên dưới đã sửa theo; mục 4 ("đã chạy thật") giữ nguyên làm lịch sử của lần chạy với MinIO.

## 1. Mục tiêu

Biến `mobile/` từ **bản demo dữ liệu giả** thành app chạy được với backend thật (Docker Compose trên máy dev): đăng nhập, đăng ký hồ sơ,
chụp/đăng ảnh, feed, bạn bè, khám phá, chat, hồ sơ, thanh toán, push. Giữ nguyên giao diện hiện có (theme kính, tiếng Việt, 13 màn).

**Điều kiện hoàn thành chung**: `flutter analyze` sạch, `flutter test` xanh, và luồng được liệt kê ở mục 7 chạy thật trên emulator/thiết bị
với backend, có ghi lại kết quả (mục 9). Không được tuyên bố "chạy được" cho phần chưa chạy thật.

## 2. Hiện trạng `mobile/` (đã kiểm tra)

- Flutter (SDK ở `D:\fluttersdk\flutter`), Dart ^3.13, Riverpod 3, go_router 18, dio, flutter_secure_storage, web_socket_channel, intl (ARB, tiếng Việt).
- Có: khung 4 tab + route S01–S13 (`lib/core/router/app_router.dart`), theme/`GlassContainer`/nút gradient, `ApiClient` (dio: gắn Bearer, xoá `X-Public-Id`,
  thử refresh 1 lần khi 401), `ApiProblem` + bảng map `code` → thông điệp tiếng Việt, `TokenStore`, 3 file test.
- **Mọi màn hình đang dùng dữ liệu demo cố định**. Chưa có repository/provider gọi API nào, chưa có đăng nhập thật, `refreshSession` chưa được cấp.
- **Chưa có trong `pubspec.yaml`**: `flutter_appauth` (hoặc tương đương), `camera`, `image_picker`, `firebase_messaging`/`firebase_core`, `in_app_purchase`, `geolocator`, `permission_handler`.
- `application id` Android `com.animallocket.animal_locket`, iOS `com.animallocket.animalLocket`. **Không khớp** custom scheme của Keycloak (mục 3).
- Có thư mục `web/` nhưng phạm vi sản phẩm là iOS + Android.
- README của `mobile/` ghi client id `animal-locket-mobile` — **sai**, client thật là `mobile` (mục 3).

## 3. Backend và cách chạy thử

Backend (Java, Docker Compose) **đã chạy thật** và luồng ảnh đầu-cuối đã được kiểm chứng bằng script (mục 4). Dựng bằng:

```bash
# ở gốc repo; .env đã có (HTTP_PORT=8080). Lần đầu build Maven mất vài phút, cần mạng ổn định.
docker compose --profile core --profile app up -d --build
docker compose ps -a        # mong đợi mọi service "healthy" (22 container, ~5.5 GB RAM)
```

| Địa chỉ (Traefik, cổng 8080) | Dịch vụ |
|---|---|
| `http://api.localhost:8080` | API gateway (REST + WebSocket `/ws/chat`) |
| `http://auth.localhost:8080` | Keycloak, realm `animal-locket` |
| URL ký sẵn của Cloudflare R2 | Ảnh — upload (PUT) và xem (GET) thẳng tới R2, không qua Traefik/gateway |

**Keycloak**: client `mobile` (public, Authorization Code + **PKCE S256**, `directAccessGrants` tắt), redirect URI `com.animallocket.app:/oauth2redirect`
(và `com.animallocket.app:/*`). Realm dùng **email làm username**, không bật xác minh email, cho phép tự đăng ký; **không có** nhà cung cấp Google/Apple/SĐT
(chỉ email + mật khẩu, mật khẩu ≥ 10 ký tự, không trùng email). Nút đăng nhập Google/Apple/SĐT trong S01 hiện **chưa có backend tương ứng** — xem Q6 ở docs/17.
Nếu Keycloak đòi bước `VERIFY_PROFILE` (họ/tên) thì phải hiển thị trong luồng trình duyệt; app không tự bỏ qua.

Tạo user thử cho dev (thông tin test, không phải bí mật thật; đặt mật khẩu của riêng bạn):

```bash
# MSYS_NO_PATHCONV=1 nếu chạy trong Git Bash trên Windows
docker exec animal-locket-keycloak-1 /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user "$KEYCLOAK_ADMIN" --password "$KEYCLOAK_ADMIN_PASSWORD"
docker exec animal-locket-keycloak-1 /opt/keycloak/bin/kcadm.sh create users -r animal-locket -s username=dev1@example.test -s email=dev1@example.test -s enabled=true -s emailVerified=true -s firstName=Dev -s lastName=One
docker exec animal-locket-keycloak-1 /opt/keycloak/bin/kcadm.sh set-password -r animal-locket --username dev1@example.test --new-password '<mật-khẩu-test>'
```

### Địa chỉ công khai: bài toán thật khi chạy trên emulator/điện thoại

`*.localhost` chỉ hợp lệ trên chính máy chạy Docker. Emulator Android thấy máy host là `10.0.2.2`; điện thoại thật thấy IP LAN. Nhưng Traefik **định tuyến theo
Host header**, và giá trị sau bị "đóng dấu" vào dữ liệu nên phải khớp đúng địa chỉ mà app dùng:
- `KEYCLOAK_PUBLIC_URL` → claim `iss` của token (gateway kiểm tra issuer).

URL ảnh trỏ thẳng tới R2 (Internet công khai) nên không phụ thuộc địa chỉ LAN.

Đề xuất (**chưa kiểm chứng**): dùng tên miền wildcard trỏ về IP LAN, ví dụ `PUBLIC_DOMAIN=192-168-1-10.nip.io` rồi đặt
`KEYCLOAK_PUBLIC_URL=http://auth.192-168-1-10.nip.io:8080`, `API_BASE_URL=http://api.192-168-1-10.nip.io:8080`,
rồi `docker compose up -d` lại `keycloak`, `api-gateway`. Cách này chạy cho cả emulator lẫn điện thoại thật (cần DNS ra internet).
Android chặn HTTP thường: cần `usesCleartextTraffic`/network security config cho bản debug; iOS cần ngoại lệ ATS cho bản debug. **Không** để các ngoại lệ này trong bản release.
Ghi lại cách bạn thực sự làm cho chạy được vào mục 9.

## 4. Những gì đã được chạy thật (tin được) và chưa chạy

> **Lịch sử (2026-11-06, thời MinIO + face-worker)** — luồng ảnh bên dưới **không còn đúng**: nay là `PUT` lên R2 và `complete` trả `READY` ngay, không che mặt. Luồng R2 mới chưa được chạy đầu-cuối.

Đã chạy thật qua gateway bằng script Python (không phải bằng app):
1. Keycloak Authorization Code + PKCE (`mobile`) → access token.
2. `POST /api/v1/users/register` → `201`, `GET /api/v1/users/me` → `200`.
3. `POST /api/v1/media/uploads` → `201 {mediaId, uploadUrl, fields, expiresInSeconds}`. `fields` gồm `policy`, `x-amz-*`, **`key`, `Content-Type`**.
4. `POST <uploadUrl>` multipart tới MinIO → `204`. Quy tắc: gửi **đúng nguyên văn mọi `fields`**, trường **`file` là trường cuối**, phần file có `Content-Type` = `contentType` đã khai,
   **không** gắn `Authorization`, host phải là host trong `uploadUrl`.
5. `POST /media/{id}/complete` → `200 UPLOADED`; `GET /media/{id}` chuyển `UPLOADED → READY` sau vài giây (`method`: `STICKER` khi có mặt, `NONE` khi không có mặt; `AI` chưa bật).
6. `GET /media/{id}/url` → URL ký 600 giây → tải ảnh `200`. Ảnh có mặt đã bị che bằng sticker con vật.

**Chưa chạy với backend thật** (coi là chưa kiểm chứng — bạn là người đầu tiên chạy chúng): `posts`/`feed`/like/bình luận, bạn bè, discovery (cards, swipes, heartbeat, vị trí),
chat REST + WebSocket, billing (`verify` với store thật; chỉ có `store=DEV` khi cấu hình cho phép), push FCM, xoá tài khoản.
Khi gặp lỗi 5xx hoặc hành vi lệch tài liệu 06 ở các phần này: **không vá vòng bằng cách né ở client**. Ghi lại (request, response, log của service liên quan:
`docker logs animal-locket-<service>-1`) và báo ở mục "Lỗi backend" trong báo cáo. Hai lỗi thật đã tìm ra theo cách này (gateway 500 với mọi JWT; ticket upload thiếu `key`) — đã sửa.

Cạm bẫy khi chạy thử đã biết:
- Sau khi restart một service, Eureka giữ bản ghi cũ ~90 giây → gateway có thể trả `503 SERVICE_UNAVAILABLE`; đợi rồi thử lại, không phải lỗi app.
- Cookie của Keycloak có cờ `Secure` dù đi qua HTTP (trình duyệt hệ thống trên Android/iOS chấp nhận ở `localhost`; trên host khác **cần kiểm tra**, có thể phải chạy Keycloak qua HTTPS cho điện thoại thật).
- Giới hạn tốc độ gateway 20 req/s; discovery 2 req/s (xem 06 §6.1).

## 5. Quy tắc bắt buộc (không thương lượng)

1. **Không bao giờ gửi `X-Public-Id`** (gateway xoá/ghi đè). Mọi request kèm `Authorization: Bearer <JWT>`, trừ PUT/GET tới URL ký sẵn của R2.
2. Phân nhánh lỗi theo trường **`code`** của RFC 7807, không theo `detail`/thông điệp. `401` thân rỗng → refresh token 1 lần rồi về đăng nhập.
   `403 PROFILE_REQUIRED` = chưa đăng ký hồ sơ → luồng S11/S02. `429` không có `code`.
3. Định danh người dùng là `publicId` (20 ký tự `[a-z2-7]`), tham chiếu bằng chuỗi. Không giả định có email/`sub` trong dữ liệu client.
4. Quyền riêng tư: không lưu/hiển thị toạ độ; xoá EXIF/GPS trước khi upload (server không kiểm tra); ảnh chỉ xem qua `GET /media/{id}/url` (hết hạn theo `expiresInSeconds`, cache theo đó).
   Xin quyền vị trí chỉ khi người dùng bật khám phá; từ chối vẫn dùng được chế độ "online". Tắt khám phá → gọi `DELETE /discovery/location`.
5. Tài khoản `ageGroup=MINOR`: **không hiện** nút mua/ưu đãi gây áp lực (docs/02 §2.7–2.8). Đăng nhập Apple bắt buộc trên iOS nếu có đăng nhập mạng xã hội khác.
6. Không commit bí mật (token, `google-services.json` thật, khoá). Cấu hình qua `--dart-define` (`API_BASE_URL`, `WS_URL`, `KEYCLOAK_ISSUER`, `KEYCLOAK_CLIENT_ID=mobile`). Không hard-code giá gói.
7. Không dùng `store=DEV` trong bản release. Chỉ gọi hoàn tất giao dịch với store **sau khi** `POST /billing/purchases/verify` trả `200`.
8. Không sửa hợp đồng API/backend trong repo này trừ khi được yêu cầu; nếu app cần endpoint chưa có (Q1–Q4, Q7 trong docs/17), dùng phương án "bản đầu" ghi ở đó và liệt kê vào báo cáo.

## 6. Kiến trúc mong muốn

Giữ cấu trúc hiện có và Riverpod; thêm theo từng feature: `features/<tên>/{data,domain,presentation}`.
- `data`: repository gọi `ApiClient` (dio), DTO có `fromJson`; **không** để widget gọi dio trực tiếp.
- Một `AuthController` giữ trạng thái `unauthenticated | needsProfile | ready`, cấp `refreshSession` cho `ApiClient`, và điều khiển redirect của go_router.
- Mọi lỗi mạng đi qua `ApiProblem`; UI hiển thị thông điệp từ `error_messages.dart`, thêm mã còn thiếu (tra bảng mã ở 06).
- Giữ **chế độ demo** (route demo ở màn đăng nhập) bằng cách đặt repository giả sau cùng interface, để dev không cần backend khi làm giao diện.
- Test: unit cho repository/DTO/map lỗi (mock dio hoặc `mocktail`), widget test cho luồng chính; một bộ "contract test" tuỳ chọn chạy với backend thật, bật bằng `--dart-define=BACKEND_TESTS=true`, mặc định bỏ qua.

## 7. Kế hoạch theo bước, mỗi bước có tiêu chí nghiệm thu

Làm tuần tự; chỉ sang bước sau khi bước trước chạy thật. Chi tiết hành vi từng màn: docs/17 §4.

| # | Việc | Nghiệm thu (chạy thật với backend) |
|---|---|---|
| 0 | Nền: thêm gói còn thiếu, `AppConfig` đúng client id `mobile`, cấu hình cleartext cho debug, sửa README | App build được trên Android (và iOS nếu có Mac); `flutter analyze`, `flutter test` xanh; gọi được `GET /api/v1/users/me` (kỳ vọng 401 khi chưa đăng nhập) từ app |
| 1 | Đăng nhập OIDC (AppAuth, PKCE, redirect `com.animallocket.app:/oauth2redirect`), lưu token an toàn, refresh, đăng xuất | Đăng nhập bằng user dev; token lưu; hết hạn thì tự refresh; đăng xuất xoá token. Cấu hình scheme cho cả Android (`appAuthRedirectScheme`) và iOS (`Info.plist`) |
| 2 | Đăng ký hồ sơ (S11 → S02): ngày sinh + điều khoản, `POST /users/register`, xử lý `INVALID_BIRTHDATE`/`INVALID_ALIAS`; điều hướng theo `404`/`PROFILE_REQUIRED` | User mới đi hết luồng, vào tab chính; gọi lại `register` không lỗi; kill app mở lại vẫn đăng nhập |
| 3 | Hồ sơ + con vật (S09, S13 phần xem): `/users/me`, `/animals`, `/users/me/animals`, đổi alias (spin và lead-animal đã ngừng, `410`) | Hiển thị dữ liệu thật và avatar; xử lý `ALIAS_COOLDOWN` |
| 4 | Chụp/chọn ảnh + đăng (S03/S04): nén ≤ 10 MB, luồng 5 bước (06 §6.3), polling `GET /media/{id}` (2 giây, tối đa ~60), `POST /posts` | Đăng ảnh: ảnh `READY`, bài `PUBLISHED`, ảnh trên R2 không còn EXIF/GPS; `REJECTED` hiện lý do + "Chụp lại"; không gửi `Authorization` tới R2 |
| 5 | Feed (S05): phân trang `before`, `degraded`, like lạc quan, bình luận, xoá bài, cache URL ảnh | Thấy bài của mình và của bạn; like/bình luận/xoá chạy; URL ảnh hết hạn thì tự lấy lại |
| 6 | Bạn bè + an toàn (S07, S13, S12 một phần): danh sách, lời mời, chặn, báo cáo, `presence` | Hai tài khoản kết bạn được với nhau (dùng 2 user dev); chặn làm biến mất khỏi danh sách |
| 7 | Khám phá (S06): bật khám phá + vị trí, `heartbeat` 30 giây, `cards`, `swipes`, MATCHED, `SWIPE_LIMIT`, tôn trọng 2 req/s | Hai tài khoản thấy nhau và quẹt ra `MATCHED`; từ chối quyền vị trí vẫn dùng được; tắt khám phá xoá vị trí |
| 8 | Chat (S08): REST lịch sử + WebSocket (`send/ack/message/read/closed/error`, ping ≤ 60 giây, nối lại backoff 1→30 giây), gửi ảnh `context=CHAT` | Hai thiết bị/emulator nhắn qua lại thời gian thực; mất mạng rồi nối lại; `closed` khoá ô nhập; fallback `POST .../messages` |
| 9 | Cài đặt (S12): bật/tắt khám phá, danh sách chặn, đăng xuất, **xoá tài khoản** (2 bước, gỡ `DELETE /devices/{token}` trước, rồi xoá token cục bộ) | Xoá tài khoản xong không đăng nhập lại được vào hồ sơ cũ |
| 10 | Thanh toán (S10): `/billing/products` + giá thật từ store, `verify`, khôi phục; ẩn với MINOR | Mua thử ở sandbox/`store=DEV` (nếu backend bật) ra `plan=PRO`; `STORE_UNAVAILABLE` cho thử lại. Nếu chưa có tài khoản store thật: nói rõ chưa kiểm chứng |
| 11 | Push (FCM): `PUT /devices`, xử lý khi nhận (mở đúng màn); cần Firebase của chủ dự án | Chỉ làm khi được cấp `google-services.json`/`GoogleService-Info.plist`; nếu không, để sau cờ cấu hình và ghi rõ |

Các điểm giao diện ↔ API chưa khớp (Q1–Q9 trong docs/17 §7) — dùng phương án "bản đầu" ở đó: bỏ chọn người nhận ảnh (Q1), ẩn thẻ "ai quẹt phải bạn" (Q2),
thanh tiến trình đổi mặt là ước lượng (Q5), ẩn "hoàn tác quẹt" (Q7), map độ hiếm `COMMON/RARE/EPIC` (Q9).

## 8. Việc ngoài phạm vi

Admin/kiểm duyệt, gọi thoại/video, feed công khai, tuỳ chỉnh từng loại thông báo, hoàn tác quẹt, bản web, sửa backend (trừ khi được yêu cầu riêng).
Đăng nhập Google/Apple/SĐT cần cấu hình Keycloak mà repo chưa có: đừng giả lập; để nút ẩn/vô hiệu có chú thích, hoặc hỏi chủ dự án.

## 9. Bàn giao và báo cáo

Mỗi bước nộp: mã nguồn + test; `flutter analyze` và `flutter test` đầu ra; **báo cáo ngắn** gồm (a) đã chạy thật những gì, trên thiết bị/emulator nào, với backend nào;
(b) chưa chạy/chưa kiểm chứng gì và vì sao; (c) **Lỗi backend** gặp phải (request, response, log); (d) quyết định đã chọn cho Q1–Q9;
(e) cách cấu hình địa chỉ công khai bạn thực sự dùng (mục 3). Không viết "hoạt động tốt" cho thứ chưa chạy; nêu số liệu/kết quả cụ thể.
Cập nhật `mobile/README.md` (client id, cách chạy với backend, lưu ý cleartext) và đừng đưa bí mật vào repo.

Câu hỏi cần chủ dự án quyết định (hỏi trước khi làm, đừng tự đoán): có thêm Google/Apple/SĐT vào Keycloak không; có cấp Firebase/tài khoản store sandbox không;
chạy thiết bị nào (Android emulator / điện thoại thật / iOS có Mac không); có sửa backend cho Q1–Q4 không.
