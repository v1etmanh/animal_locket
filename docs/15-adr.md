# 15. Nhật ký quyết định kiến trúc (ADR)

Mẫu: **Bối cảnh → Quyết định → Hệ quả**. Trạng thái "Chấp nhận" nghĩa là đã được hiện thực trong code.

---

## ADR-001 — Microservice trong một monorepo

- **Bối cảnh**: sản phẩm có các miền khác nhau về tải và công nghệ lưu trữ (quan hệ, document, GEO, ảnh/AI, thanh toán); kế hoạch yêu cầu rõ MySQL/PostgreSQL/MongoDB, Kafka, Keycloak, Eureka…
- **Quyết định**: tách 7 service nghiệp vụ + gateway/config/eureka (ban đầu có thêm face-worker, đã gỡ theo ADR-014); tất cả nằm trong **một repo Maven đa module** (kèm thư viện dùng chung `libs/`), mỗi service có DB riêng.
- **Hệ quả**: (+) ranh giới dữ liệu rõ, chọn đúng công nghệ lưu trữ, scale từng phần; thay đổi xuyên service làm trong một PR. (−) vận hành nặng (≈ 23 container), nhất quán cuối cùng (eventual consistency) cần Outbox, độ phức tạp test E2E. Giảm nhẹ: Compose profiles, bật dần; có thể gộp service ở giai đoạn đầu nếu đội nhỏ.

## ADR-002 — Outbox + consumer idempotent cho mọi event nghiệp vụ

- **Bối cảnh**: ghi DB rồi gửi Kafka là hai bước, dễ mất hoặc phát đôi event khi lỗi; thanh toán/đăng ảnh/chặn không được mất event.
- **Quyết định**: service có DB ghi event vào `outbox_events` **trong cùng transaction**, `OutboxRelay` đẩy sang Kafka (at-least-once, `SKIP LOCKED`, dừng ở lỗi đầu tiên). Consumer có DB dùng bảng `processed_events` trong cùng transaction xử lý. Triển khai ở `libs/outbox-jpa`.
- **Hệ quả**: (+) không mất event, tái sử dụng được; (−) có độ trễ ≤ ~0.5 giây, một message hỏng chặn hàng đợi của service đó, cần dọn bảng và theo dõi lag. Ngoại lệ có chủ đích: chat (MongoDB) phát `MESSAGE_SENT` trực tiếp vì push là fail-soft.

## ADR-003 — Gateway gắn `X-Public-Id`; service tin header; `/internal/**` dùng token nội bộ

- **Bối cảnh**: danh tính công khai phải là `publicId`, `sub` Keycloak không được lọt ra service; mọi service cần biết "ai đang gọi" mà không tự tra `sub`.
- **Quyết định**: gateway xác thực JWT, **xoá** `X-Public-Id` do client gửi, tra `sub → publicId` ở user-service (cache 5 phút) rồi gắn lại. Service vẫn kiểm tra JWT (chống gọi không xác thực) nhưng lấy danh tính từ header. Gọi giữa service dùng `X-Internal-Token`; `/internal/**` không có route ở gateway.
- **Hệ quả**: (+) service đơn giản, `sub` chỉ ở user-service; một điểm tra danh tính. (−) **an toàn phụ thuộc cách ly mạng**: ai chạm được service trực tiếp (có JWT bất kỳ) có thể đặt `X-Public-Id` tuỳ ý; gateway thành điểm phụ thuộc user-service (fail closed 503). Cải tiến: ký HMAC header hoặc service đối chiếu `sub`; token nội bộ riêng theo cặp.

## ADR-004 — Chat dùng Redis pub/sub để phân phối giữa các instance

- **Bối cảnh**: WebSocket giữ trạng thái trên từng instance; hai người dùng có thể ở hai instance; kế hoạch gốc còn lưỡng lự "broker hoặc Redis".
- **Quyết định**: kênh `chat:user:{publicId}`; mỗi instance `PSUBSCRIBE chat:user:*` và chuyển cho phiên cục bộ. Gửi tin = lưu MongoDB rồi publish cho **cả hai** người. Trừu tượng hoá bằng `MessageBus` (Redis / cục bộ cho test).
- **Hệ quả**: (+) đơn giản, độ trễ thấp, tận dụng Redis đã có; test không cần Redis. (−) pub/sub **không bền**: client offline/đứt kết nối phải tải lại lịch sử qua REST; mọi instance nhận mọi kênh (cần chia nhỏ khi rất lớn).

## ADR-005 — Kafka chỉ cho event nghiệp vụ; không dùng cho chat

- **Bối cảnh**: cần quyết định "broker nào cho việc gì".
- **Quyết định**: Kafka chỉ phục vụ event giữa service (bạn bè, ảnh, thanh toán, xoá tài khoản, push). Tin nhắn thời gian thực đi bằng Redis (ADR-004); lịch sử ở MongoDB.
- **Hệ quả**: (+) Kafka tải nhẹ và dễ suy luận; (−) hai hệ thống nhắn tin cần vận hành; `MESSAGE_SENT` chỉ là tín hiệu cho push.

## ADR-006 — Kết quả ẩn mặt đi hai bước: worker → `media.results` → media-service → `PHOTO_READY`

> **Trạng thái: Bị thay thế bởi ADR-014** (face-worker đã gỡ). Giữ lại làm lịch sử.

- **Bối cảnh**: kế hoạch để worker phát thẳng `PHOTO_READY/REJECTED`. Nhưng worker không có DB; media-service mới là nơi giữ trạng thái job (`UPLOADED → READY/REJECTED`) và cần job + event luôn nhất quán; còn phải xử lý timeout khi worker không trả lời.
- **Quyết định**: worker phát `FACE_PROCESSED/FACE_FAILED` (không DB) lên `media.results`; media-service nhận, cập nhật job và phát `PHOTO_READY/REJECTED` qua Outbox. Job kẹt `UPLOADED` quá 10 phút bị media-service tự từ chối.
- **Hệ quả**: (+) trạng thái là nguồn sự thật duy nhất, fail closed khi worker chết, worker thay thế được không ảnh hưởng consumer. (−) thêm một bước/topic, thêm độ trễ nhỏ; ảnh public mồ côi nếu worker xong sau khi job đã hết hạn.

## ADR-007 — Upload bằng presigned POST policy (không phải PUT)

> **Trạng thái: Bị thay thế bởi ADR-014.** Kho ảnh chuyển sang Cloudflare R2, mà R2 không hỗ trợ presigned POST, nên code hiện dùng **presigned PUT** và `complete` kiểm tra lại cỡ + `Content-Type`. Giữ lại làm lịch sử.

- **Bối cảnh**: ảnh phải đi thẳng từ điện thoại vào kho, không qua service; cần ràng buộc kích thước/loại/khoá.
- **Quyết định**: media-service cấp **POST policy** (điều kiện `key`, `Content-Type`, `content-length-range`, hết hạn 5 phút) cho bucket `raw` private. Dùng hai client MinIO: nội bộ để thao tác, `public-endpoint` để ký (chữ ký gắn với host). `complete` xác nhận object tồn tại trước khi phát `PHOTO_UPLOADED`.
- **Hệ quả**: (+) client không thể vượt kích thước hay đổi khoá; không tải qua service. (−) cấu hình `public-endpoint` phải đúng host mà điện thoại truy cập (qua Traefik `files.<domain>`); form có thứ tự trường (`file` cuối cùng). Quét magic-bytes/virus làm ở worker.

## ADR-008 — Discovery: thẻ = "lân cận hoặc online"; vị trí làm tròn và làm nhiễu cố định

- **Bối cảnh**: cần gợi ý kết bạn kiểu Tinder, nhưng vị trí là dữ liệu rủi ro nhất; trẻ vị thành niên cần bảo vệ thêm.
- **Quyết định**: ứng viên = người trong bán kính (10 km; 5 km cho dưới 18) **hoặc** online trong 60 giây, cùng nhóm tuổi, lọc `discoverable` bằng hồ sơ mới. Vị trí lưu = tâm ô 500 m + offset ±250 m từ `HMAC(secret, publicId)`, TTL 30 phút; chỉ trả **mức** khoảng cách (thô hơn cho dưới 18); GEO/online tách theo nhóm tuổi. Lưu trong Redis qua `DiscoveryStore` (Redis / bộ nhớ).
- **Hệ quả**: (+) không lưu/trả toạ độ chính xác, chống lấy trung bình bằng nhiều truy vấn; thẻ luôn có ứng viên khi vùng thưa. (−) người online ở xa vẫn xuất hiện (không kèm khoảng cách); cần giữ bí mật `DISCOVERY_SECRET`; người ở vùng rất thưa vẫn dễ bị định vị; tắt khám phá chưa tự xoá vị trí.

## ADR-009 — Đăng ảnh fail closed

- **Bối cảnh**: ban đầu: một ảnh lọt ra chưa ẩn mặt phá cam kết cốt lõi. Sau ADR-014 không còn ẩn mặt, nhưng vẫn cần: chỉ ảnh đã kiểm tra (đúng chủ, đúng loại, đúng cỡ) mới được đăng, và chỉ bạn bè xem được.
- **Quyết định**: bài ở `PENDING_MEDIA` cho tới khi có `PHOTO_READY` (kèm kiểm tra chủ ảnh trùng tác giả); `PHOTO_REJECTED` dẫn tới `REJECTED` và hoàn lượt; `PostView` không có khoá kho ảnh; xem ảnh qua URL ký 10 phút sau kiểm tra bạn bè/chặn.
- **Hệ quả**: (+) không có đường nào đăng ảnh chưa qua `complete`. (−) khi Kafka/Outbox gián đoạn, bài kẹt `PENDING_MEDIA` (`PendingPostReconciler` gỡ khi đã có kết quả ảnh).

## ADR-010 — Trừu tượng `KeyValueStore` (Redis hoặc bộ nhớ)

- **Bối cảnh**: hạn mức, cache bạn bè, `pro:{id}` cần Redis nhưng test/dev không nên phụ thuộc Redis; kiểm tra hạn mức cần kiểm soát thời gian.
- **Quyết định**: `libs/common` có interface `KeyValueStore` (`increment`, `decrement`, `get/set`, `setIfAbsent`, `delete`) với `RedisKeyValueStore` (mặc định) và `InMemoryKeyValueStore` (`animal.kv.type=memory`); tự cấu hình theo thuộc tính. Cấu trúc đặc thù (GEO, ZSET, pub/sub) có interface riêng (`DiscoveryStore`, `MessageBus`).
- **Hệ quả**: (+) test chạy nhanh, không Docker; logic hạn mức xác định. (−) hành vi hai cài đặt phải khớp — bù bằng bộ test hợp đồng (`DiscoveryStoreContractTest` chạy cho cả hai); Redis `optional` trong `common` nên service tự khai báo dependency.

## ADR-011 — face-worker bằng Python, có sticker dự phòng và AI tuỳ chọn

> **Trạng thái: Bị thay thế bởi ADR-014** (face-worker đã gỡ khỏi repo). Giữ lại làm lịch sử.

- **Bối cảnh**: hệ sinh thái nhận diện mặt/inpainting nằm ở Python (OpenCV, ONNX, diffusers); AI cần GPU, chậm và chưa chắc đạt chất lượng; không được gửi ảnh gốc cho dịch vụ bên thứ ba.
- **Quyết định**: worker Python độc lập (không DB) nghe Kafka. Chế độ mặc định là **sticker 2D che kín** (chạy CPU, kiểm chứng bằng test hình học); AI inpainting tự chạy trên GPU của hệ thống khi `AI_ENABLED=true`, có kiểm tra sau khi sinh và fallback theo từng mặt. Detector là tập hợp (Haar + YuNet) hợp nhất bằng phép hợp để ưu tiên che thừa.
- **Hệ quả**: (+) luôn có đường che an toàn, không phụ thuộc GPU; AI nâng chất lượng khi có. (−) hai ngôn ngữ/vận hành, hợp đồng JSON giữa Java và Python phải được test (`FaceWorkerContractTest`); chất lượng thật chưa đo; sticker kém thẩm mỹ.

## ADR-012 — Tham chiếu giữa service chỉ bằng `publicId`, không khoá ngoại chéo DB

- **Bối cảnh**: mỗi service có DB riêng; cần xoá tài khoản triệt để và không lộ danh tính.
- **Quyết định**: mọi quan hệ chéo service lưu `publicId` (chuỗi ngẫu nhiên 20 ký tự); không FK giữa DB; bản sao dữ liệu cập nhật bằng event (`owner_animals`, `media_states`, `entitlements`, `pro:{id}`). `keycloak_sub` chỉ ở bảng `users`. Xoá tài khoản lan truyền bằng `USER_DELETED`.
- **Hệ quả**: (+) service độc lập, dễ xoá dữ liệu theo người, không rò `sub`. (−) toàn vẹn tham chiếu là *cuối cùng* (dữ liệu mồ côi tạm thời), phải kiểm tra tồn tại ở tầng ứng dụng; cần job đối chiếu cho kho ảnh.

## ADR-013 — Billing: chỉ tin xác minh phía server, sổ cái ví, cập nhật số dư nguyên tử

- **Bối cảnh**: tiền là fail closed; client có thể giả biên lai; không được để người dùng bị trừ tiền mà không có quyền lợi, cũng không được cấp quyền không có biên lai.
- **Quyết định**: client chỉ gửi `(store, sku, token)`; server **luôn hỏi lại store** (`StoreGateway`) rồi mới cấp quyền, ghi `purchases` + phát event trong **một transaction ngắn** (hỏi store xong mới mở transaction). Ràng buộc duy nhất `(store, transactionId)` và `(store, originalTransactionId)` chặn dùng lại/chia sẻ biên lai. Vật phẩm mua lẻ nằm trong `wallet_balances` đổi bằng `UPDATE … WHERE balance >= n` kèm dòng `wallet_ledger` duy nhất theo `(reason, ref, item)`. Webhook khử trùng lặp theo id thông báo; thuê bao hết hạn có thời gian ân hạn (1 giờ). Cổng `DevStoreGateway` (tin client) mặc định **tắt**.
- **Hệ quả**: (+) không cộng/trừ hai lần, số dư không âm, quyền lợi suy ra từ trạng thái hiện tại (`refreshEntitlement`), client chỉ kết thúc giao dịch sau `200`. (−) phụ thuộc store khả dụng (`503 STORE_UNAVAILABLE` → client thử lại); `consume` hiện không idempotent theo yêu cầu gọi; phần webhook/cổng store thật cần hoàn tất và thử sandbox.

## ADR-014 — Gỡ face-worker; ảnh đăng nguyên bản; kho ảnh là Cloudflare R2

- **Bối cảnh**: pipeline ẩn mặt (ADR-006, ADR-011) cần một service Python riêng, thêm hai topic, chất lượng che chưa đo được và nặng vận hành. Ẩn danh được đảm bảo bằng alias và avatar con vật duy nhất cho mỗi người ([19-avatar-mechanism.md](19-avatar-mechanism.md)), không cần sửa ảnh. MinIO tự host được thay bằng Cloudflare R2.
- **Quyết định**: gỡ `face-worker/`. media-service cấp **presigned PUT** tới **một** bucket R2 private; `complete` kiểm tra object tồn tại, cỡ và `Content-Type` thật rồi đánh dấu job `READY` và phát `PHOTO_READY` (`method = "NONE"`, `facesDetected = 0`) qua Outbox; sai thì `PHOTO_REJECTED`. `publicKey` trùng `rawKey`. Client nén lại và xoá EXIF/GPS (`ImagePreparationService`, `keepExif: false`); server **không** kiểm tra EXIF.
- **Hệ quả**: (+) bớt một service, hai topic và một ngôn ngữ; đăng ảnh gần như tức thì. (−) **Khuôn mặt thật trong ảnh hiển thị cho bạn bè**: lời hứa "mọi khuôn mặt được thay bằng mặt con vật" không còn đúng. EXIF chỉ được xoá nếu client tuân thủ (client sửa đổi có thể gửi ảnh kèm GPS). Không quét magic-bytes/virus ở server. Hằng số `PHOTO_UPLOADED`, `FACE_PROCESSED`, `FACE_FAILED`, `Topics.MEDIA_RESULTS/MEDIA_DLQ` và các cột `method/faces_detected/lead_animal` của `media_jobs` còn trong code nhưng không dùng. Chưa chạy thử với R2 thật.

## ADR-015 — Vẽ lại avatar sang origami, giữ nguyên bộ khoá

- **Bối cảnh**: redesign UI theo phong cách sổ ảnh Nhật Bản (`docs/superpowers/specs/2026-11-09-ui-redesign-design.md` §5) cần avatar con vật kiểu giấy gấp. Quy tắc cũ của [19-avatar-mechanism.md](19-avatar-mechanism.md) §3.2 ("phiên bản đã phát hành không bao giờ đổi nghĩa") không cho người đang có `fox:0:none` thấy con cáo mới. Đổi mã của 3.000 avatar đã cấp thì phải migrate kho và mọi dữ liệu chứa mã (bài đăng, discovery, chat).
- **Quyết định**: thêm thư viện **v2** kiểu "gấp đơn giản" với **đúng bộ khoá v1** (50 × 10 × 6), cùng 4 màu gốc mỗi bảng, thêm sắc độ tính sẵn. File v1 giữ nguyên từng byte. Server không đổi code: khoá vẫn thuộc v1 nên mã đã cấp và `avatar_pool` không đổi; `GET /animals/avatar-lib/2` phục vụ v2. App chỉ đóng gói v2 và vẽ mỗi mã bằng thư viện mới nhất có khoá đó. Quy tắc §3.2 đổi thành: khoá không bao giờ mất hay đổi ý nghĩa; hình của khoá được phép vẽ lại ở phiên bản mới.
- **Hệ quả**: (+) mọi người thấy avatar origami ngay khi cập nhật app, không migrate dữ liệu. (−) Cùng một mã ra hai hình khác nhau giữa app cũ (v1) và app mới (v2); ai chụp màn hình avatar cũ sẽ thấy khác. Một phiên bản vẽ lại tương lai phải chứa đủ mọi khoá đang có (`check.mjs` chặn khi bộ khoá khác v1).
