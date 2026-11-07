# 9. Riêng tư, an toàn và bảo mật

Tài liệu ánh xạ các cam kết ẩn danh/an toàn trong kế hoạch sang **code thực tế**, nêu rõ chỗ còn hở. Mục 9.9 về pháp lý chỉ là điểm cần rà soát, **không phải tư vấn pháp lý**.

## 9.1 Nguyên tắc ẩn danh và nơi thực thi

| Cam kết | Thực thi trong code |
|---|---|
| Danh tính công khai chỉ gồm `publicId`, alias, con vật | DTO ra ngoài: `PublicProfile{publicId, alias, leadAnimal}`, `Card`, `Author`. Không DTO nào có `sub`, email, SĐT, `birthDate`, toạ độ |
| `publicId` không suy ra được từ `sub` | `PublicIds.generate()`: 20 ký tự ngẫu nhiên từ `SecureRandom` (~100 bit), không dẫn xuất từ dữ liệu nào |
| `sub` chỉ tồn tại ở user-service | Cột `users.keycloak_sub`; chỉ `/internal/identity/{sub}` (nội bộ) dùng. Sau khi xoá tài khoản được ghi đè `deleted:<publicId>` |
| Ngày sinh không lộ | Chỉ dùng để tính `ageGroup`; `MeProfile` chỉ trả `ageGroup`; xoá `birth_date` khi xoá tài khoản |
| Không lộ người dùng có thật hay không | `404` thay vì `403` cho bài/ảnh/hồ sơ không được phép xem; hồ sơ giữa hai bên có chặn đều `404` |
| Event/Kafka không chứa dữ liệu định danh | Payload chỉ `publicId` và mã nghiệp vụ; `MESSAGE_SENT` không chứa nội dung |
| Push không lộ danh tính | Tiêu đề/nội dung chung chung (`NotificationPlanner`); `data` chỉ có `type`, `postId`/`conversationId`/`mediaId` |
| Mặt thật không đến được người khác | Pipeline ẩn mặt + fail closed ([08-face-anonymization-pipeline.md](08-face-anonymization-pipeline.md)); `PostView` không có đường dẫn kho ảnh; ảnh xem qua URL ký sẵn 10 phút sau khi kiểm tra bạn bè |
| EXIF/GPS bị xoá | `decode_clean` tạo ảnh mới từ điểm ảnh, có test chứng minh |

Quy tắc code (bắt buộc khi review): **mọi DTO mới trả cho người khác chỉ được chứa `publicId`, alias, con vật** hoặc dữ liệu của chính người gọi. Test `cardsNeverExposeCoordinatesOrDistancesInMeters` dùng reflection để bắt trường toạ độ trong `Card`; nên có test tương tự cho DTO mới.

## 9.2 Quyền riêng tư vị trí

Đây là rủi ro cao nhất của tính năng lân cận. Thiết kế (`LocationPrivacy`, `DiscoveryService`):

1. **Chỉ lưu khi bật**: `PUT /discovery/location` yêu cầu hồ sơ `discoverable=true` (hỏi user-service mỗi lần), ngược lại `403`.
2. **Làm tròn ngay ở server**: toạ độ về **tâm ô lưới ~500 m** (`snap`). Hai điểm cùng ô cho cùng kết quả.
3. **Độ lệch cố định theo người**: cộng offset ±250 m suy từ `HMAC-SHA256(secret, publicId)`. Vì cố định nên kẻ tấn công **không thể lấy trung bình** nhiều lần truy vấn để triệt nhiễu; khoá bí mật (`animal.discovery.secret`, ≥ 16 ký tự, biến `DISCOVERY_SECRET`) khiến không thể tính lại offset từ bên ngoài. Sai số tối đa của vị trí lưu so với thật ≈ 360 m (làm tròn) + 355 m (offset) ≈ 715 m (test `storedPositionStaysWithinBoundedErrorOfTruth`).
4. **Chỉ trả mức khoảng cách**, không mét, không toạ độ: người lớn `UNDER_1KM / 1_TO_3KM / 3_TO_10KM / OVER_10KM`; **người dưới 18 thô hơn** (`UNDER_3KM / 3_TO_10KM / OVER_10KM`, không có "dưới 1 km"). Người "online" nhưng ngoài bán kính **không có mức khoảng cách** (`null`).
5. **Phân tách nhóm tuổi**: GEO/online/exp lưu theo `MINOR`/`ADULT`; truy vấn chỉ trong nhóm của người hỏi; kiểm tra lần hai ở `FriendService.connect` (khác nhóm tuổi → `403`) và bằng cách lọc `ageGroup` trên hồ sơ lấy mới. Người dưới 18 có bán kính 5 km thay vì 10 km.
6. **TTL**: vị trí hết hạn sau 30 phút (`geo:exp`), job `purgeExpired` chạy mỗi 60 giây xoá khỏi GEO (Redis GEO không có TTL từng member); `DELETE /discovery/location` và `USER_DELETED` xoá ngay.
7. **Chống dò nhiều điểm (trilateration)**: nhiễu cố định theo người + lưới 500 m (di chuyển trong một ô không làm vị trí lưu đổi: test `movingInsideACellDoesNotLeakFinerPosition`); chỉ trả mức khoảng cách thô; giới hạn 10 lần tìm/phút/người và rate limit gateway (2 req/s). Kẻ tấn công phải **đổi tài khoản** để lấy thêm mẫu, nên cần thêm giới hạn theo thiết bị/IP và theo số tài khoản mới (chưa có).

**Còn hở / cần theo dõi**
- Tắt `discoverable` qua `PATCH /users/me` **không tự xoá vị trí** ở discovery (không có event); vị trí còn tối đa 30 phút. Người này không xuất hiện trong thẻ của người khác (hồ sơ được lọc theo `discoverable` mỗi lần) nhưng dữ liệu vẫn nằm trong Redis. Client phải gọi `DELETE /discovery/location` khi tắt; nên phát event `DISCOVERABLE_CHANGED`.
- Người "đang online" (heartbeat) vẫn nằm trong `online:{ageGroup}` dù không `discoverable`; chỉ bị lọc ở bước kiểm tra hồ sơ. Ngoài việc hao tài nguyên, nếu có nhiều người online không bật khám phá thì danh sách ứng viên (`limit × 6`) có thể bị chiếm chỗ và bộ thẻ ít hơn thực tế.
- Phân tích rủi ro riêng: người dùng ở nơi thưa dân (một ô lưới chỉ có vài người) vẫn dễ bị định vị; cân nhắc chỉ hiện thẻ khi ô có ≥ k người (k-anonymity).

## 9.3 An toàn người lạ

- **Chỉ có thẻ khi cả hai bật khám phá**, cùng nhóm tuổi; tài khoản dưới 18 chỉ ghép với dưới 18 ([01-product-requirements.md](01-product-requirements.md) quy tắc 6).
- **Chặn** (`PUT /blocks/{id}`): lưu `blocks`; xoá quan hệ bạn; huỷ lời mời hai chiều; phát `USER_BLOCKED` → chat đóng hội thoại và báo cả hai đầu; hồ sơ `404` cho nhau; không còn trong thẻ của nhau (loại trừ lấy từ user-service mỗi lần); không xem được bài/ảnh của nhau (không còn là bạn); `connect` trả `BLOCKED` mà không tạo lời mời. Bỏ chặn không tự kết bạn lại.
- **Báo cáo** (`POST /reports`): lưu `reports` (`OPEN`), tối đa 20/24 giờ. **Chưa có công cụ quản trị** để xử lý hàng đợi (xem [14-roadmap-risks.md](14-roadmap-risks.md)).
- **Giới hạn**: lời mời 20/80 mỗi ngày, quẹt phải 30/150 mỗi ngày, chat 20 tin/10 giây, upload 60/giờ, bình luận/like không giới hạn riêng (chỉ rate limit gateway).
- **Chat chỉ giữa bạn bè**, kiểm tra cả lúc mở lẫn mỗi lần gửi (cache 30 giây).
- **Alias**: lọc ký tự và từ khoá mạo danh (`admin`, `support`…), đổi tối đa 1 lần/24 giờ. Chưa có danh sách từ cấm tục tĩu; cần bổ sung.

## 9.4 Xoá tài khoản

`DELETE /users/me` → trong **một transaction** ở user-service: xoá quan hệ bạn, lời mời, chặn, thiết bị, con vật, lượt quay, quyền lợi; ẩn danh bản ghi `users`; ghi `USER_DELETED` vào outbox; gọi Keycloak Admin API xoá tài khoản đăng nhập (lỗi → rollback toàn bộ, người dùng thử lại).

| Service | Khi nhận `USER_DELETED` |
|---|---|
| media-service | Xoá mọi `media_jobs` của người đó, xoá object `raw` và `public`, xoá `owner_animals` |
| post-service | Xoá bài của họ (kèm like/bình luận trên các bài đó), bình luận và like của họ trên bài người khác, `media_states`; xoá cache bạn bè |
| chat-service | Xoá mọi hội thoại và tin nhắn có họ; báo `closed(DELETED)` cho người còn lại |
| discovery-service | Xoá vị trí, online, boost, lịch sử quẹt (cả trái/phải) |
| billing-service | Xoá ví và sổ cái, xoá thuê bao; **ẩn danh** `purchases.public_id` (giữ bản ghi tài chính) |
| notification-service | Không lưu dữ liệu |

**Không bị xoá / cần quyết định**: bảng `reports` (cả người báo cáo lẫn bị báo cáo); `processed_events`; message còn trong Kafka theo retention (chứa `publicId`); log (có `traceId` nhưng không có dữ liệu cá nhân — cần kiểm tra không log `publicId` kèm nội dung); bản sao lưu DB (nếu có). Ghi rõ trong chính sách quyền riêng tư và đặt `retention.ms` Kafka ngắn.

## 9.5 Mô hình đe doạ

| # | Mối đe doạ | Hiện trạng | Biện pháp / việc còn lại |
|---|---|---|---|
| T1 | Giả mạo `X-Public-Id` để mạo danh | Gateway **xoá** header do client gửi rồi gắn lại từ `sub`. Nhưng service **tin header** và không đối chiếu với JWT: ai gọi được service trực tiếp (có JWT hợp lệ bất kỳ) có thể đặt `X-Public-Id` tuỳ ý | **Bắt buộc** cách ly mạng: chỉ gateway chạm được service (Compose network nội bộ, Traefik chỉ route tới gateway, không publish cổng service). Nên bổ sung: gateway ký HMAC header, hoặc service tự đối chiếu `sub` ↔ `publicId` |
| T2 | Lộ endpoint `/internal/**` | `InternalTokenFilter` so khớp hằng-thời-gian `X-Internal-Token`; gateway **không có route** `/internal/**` | Đổi `INTERNAL_TOKEN` mặc định (`dev-internal-token`) ở mọi môi trường thật; token riêng cho từng cặp service nếu có thể; không publish cổng service |
| T3 | Lộ `/actuator/prometheus`, `/actuator/info` công khai | Gateway và service để `permitAll` hai đường này | Traefik chỉ định tuyến `PathPrefix(/api/)`, `/ws/`, `/webhooks/`; chặn `/actuator`. Prometheus scrape trong mạng nội bộ |
| T4 | Lạm dụng URL upload ký sẵn | Biểu mẫu POST policy ràng buộc `key`, `Content-Type`, kích thước 1..10 MB, hết hạn 5 phút; bucket `raw` private và tự xoá ≤ 1 giờ | Quota 60 upload/giờ/người. Kiểm tra magic-bytes được thực hiện ở worker (`UNREADABLE_IMAGE`). Cân nhắc quét virus nếu cho phép định dạng khác |
| T5 | IDOR trên bài/ảnh/hội thoại | Mọi truy cập bài kiểm tra `tác giả hoặc bạn bè` + `PUBLISHED`; ảnh kiểm tra chủ/bạn/chặn; hội thoại kiểm tra `participants`; job media chỉ chủ xem được (`ownedJob`). Sai quyền → `404` | Test đã có cho các trường hợp chính; thêm test bảo mật tự động (xem [12-testing-strategy.md](12-testing-strategy.md)) |
| T6 | Liệt kê (enumeration) người dùng/ảnh | `publicId` ngẫu nhiên 100 bit; id ảnh là UUID; mọi lỗi quyền là `404` | Tránh trả lỗi khác nhau theo trường hợp (đã làm với bài/ảnh/hồ sơ) |
| T7 | Giả mạo webhook thanh toán | `/webhooks/**` công khai ở gateway; billing phải tự xác thực chữ ký (Apple JWS chuỗi chứng chỉ, Google OIDC của Pub/Sub) và **luôn hỏi lại store** trước khi cấp quyền | Phần endpoint webhook chưa có trong code lúc viết; trước khi bật phải có test chữ ký giả/hết hạn |
| T8 | Dùng lại biên lai (replay / chia sẻ) | `UNIQUE(store, store_transaction_id)`; biên lai đã gắn tài khoản khác → `409 RECEIPT_ALREADY_USED` | — |
| T9 | Tin vào biên lai của client | `StoreRouter` chỉ cấp quyền từ `VerifiedPurchase` do gateway store trả; store chưa bật → từ chối. `DevStoreGateway` mặc định **tắt** | Đảm bảo `BILLING_DEV_STORE=false` ở production (nên có kiểm tra khởi động cảnh báo) |
| T10 | Chiếm phiên WebSocket | JWT được kiểm tra ở bước HTTP Upgrade; `X-Public-Id` bắt buộc; khung ≤ 16 KB; idle 120 giây; rate limit 20 tin/10 giây | JWT truyền trong header (không trong query string để khỏi vào log). Token hết hạn khi phiên đang mở: phiên **không** bị ngắt — cần giới hạn thời gian sống phiên hoặc ping kiểm tra lại |
| T11 | Spam kết bạn / dò người | Giới hạn lời mời, quẹt phải, tìm kiếm; chặn/báo cáo | Chưa có phát hiện hành vi bất thường, giới hạn tạo tài khoản theo IP/thiết bị |
| T12 | XSS/injection qua alias, caption, bình luận, tin nhắn | Server lưu văn bản thô, kiểm tra độ dài; alias lọc ký tự | **Client phải escape** khi hiển thị; nếu có web client, thêm CSP |
| T13 | Brute-force/DoS | Rate limit gateway (Redis); circuit breaker | Đặt giới hạn ở Traefik/WAF; giới hạn kích thước body ở gateway |
| T14 | Lộ bí mật cấu hình | Config Server `native`; mật khẩu mặc định chỉ cho dev | Bí mật qua biến môi trường/Vault, **không** đưa vào repo cấu hình; xoay khoá định kỳ |
| T15 | Rò rỉ qua log | Mẫu log có `traceId`; không log nội dung tin/ảnh | Review để không log token, `publicId` cùng toạ độ, thân request |
| T16 | Gateway rate limit theo IP khi chưa đăng nhập | Khoá IP lấy từ `getRemoteAddress()`; sau Traefik toàn bộ người chưa đăng nhập có thể chung một IP | Cấu hình `XForwardedRemoteAddressResolver`/`forward-headers-strategy` để dùng IP thật |

## 9.6 Xác thực và phân quyền

- Keycloak phát JWT; gateway và **mỗi service** đều xác thực JWT bằng JWKS (`spring.security.oauth2.resourceserver.jwt.jwk-set-uri`). `/internal/**` dùng token nội bộ thay JWT.
- Quyền nghiệp vụ nằm ở service (tác giả, bạn bè, chủ ảnh, Pro…), không dựa vào role JWT.
- Chưa có vai trò quản trị (xử lý báo cáo, khoá tài khoản). `users.status=SUSPENDED` đã có trong mô hình nhưng chưa có API đặt/áp dụng ở mọi service.

## 9.7 Bí mật và cấu hình

| Bí mật | Biến | Ghi chú |
|---|---|---|
| Khoá gọi nội bộ | `INTERNAL_TOKEN` | Đổi khỏi mặc định |
| Khoá offset vị trí | `DISCOVERY_SECRET` | ≥ 16 ký tự; **đổi sẽ làm toàn bộ offset đổi** — chỉ đổi cùng lúc xoá dữ liệu vị trí |
| DB | `DB_USER`, `DB_PASSWORD` | Mỗi service một user chỉ có quyền trên DB của nó (production) |
| MinIO | `MINIO_ACCESS_KEY/SECRET_KEY` | Tài khoản riêng cho worker/media-service, giới hạn theo bucket |
| Config Server | `CONFIG_USER/CONFIG_PASSWORD` | |
| Keycloak Admin | `KEYCLOAK_ADMIN_CLIENT_SECRET` | Service account chỉ có quyền xoá user |
| FCM | `FCM_CREDENTIALS_FILE` | File khoá dịch vụ, mount read-only |
| Store | khoá Apple (.p8), service account Google | Chưa dùng trong code lúc viết |

Không commit bí mật; `.env` nằm trong `.gitignore`.

## 9.8 Nội dung do người dùng tạo (UGC)

Cửa hàng ứng dụng yêu cầu với ứng dụng có nội dung người dùng: cơ chế **báo cáo**, **chặn**, quy trình xử lý trong thời hạn hợp lý, và điều khoản sử dụng. Hiện có báo cáo và chặn; **chưa có** kiểm duyệt ảnh tự động (NSFW), lọc từ ngữ tin nhắn/bình luận, hàng đợi quản trị. Đây là điều kiện cần giải quyết trước khi đưa lên cửa hàng.

## 9.9 Điểm cần rà soát pháp lý (không phải tư vấn pháp lý)

- **Trẻ vị thành niên**: kế hoạch cho phép mọi lứa tuổi. Nhiều khu vực yêu cầu độ tuổi tối thiểu và sự đồng ý của cha mẹ cho trẻ nhỏ (ví dụ 13 tuổi theo COPPA ở Mỹ, 13–16 theo GDPR tuỳ nước) và hạn chế dữ liệu vị trí/quảng cáo/tin nhắn với người lạ. Code chỉ **tự khai ngày sinh** (không xác minh). Cần luật sư rà soát trước khi phát hành, đặc biệt tính năng lân cận và chat với người lạ có liên quan trẻ em.
- **Dữ liệu sinh trắc học**: xử lý khuôn mặt để che có thể bị coi là xử lý dữ liệu nhạy cảm ở một số luật (GDPR, BIPA…) dù không lưu khuôn mặt. Ảnh gốc xoá ngay, không gửi ra bên thứ ba — cần ghi vào chính sách quyền riêng tư.
- **Xoá dữ liệu / quyền của chủ thể dữ liệu**: App Store và Google Play yêu cầu xoá tài khoản trong ứng dụng; code đáp ứng luồng cơ bản (9.4) nhưng cần chốt thời hạn lưu `reports`, backup, log, Kafka.
- **Lưu trữ dữ liệu tại Việt Nam**: cân nhắc quy định về lưu trữ/xuất dữ liệu nếu vận hành tại Việt Nam.
- **Thanh toán**: tuân thủ chính sách in-app purchase của Apple/Google; người dưới 18 cần cơ chế đồng ý của phụ huynh do nền tảng cung cấp.
- Điều khoản sử dụng và chính sách quyền riêng tư phải được soạn và công bố trước khi phát hành.
