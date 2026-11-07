# Animal Locket — Kế hoạch kiến trúc microservice (bản điều chỉnh v2)

Ý tưởng sản phẩm: giống Locket (chia sẻ ảnh nhanh với bạn bè), nhưng mọi người đều **ẩn danh**, mọi khuôn mặt trong ảnh **được thay bằng mặt con vật**, có **kết bạn online** và **tìm người lân cận**.

## 0. Bản cũ sai/thiếu gì, đã sửa thế nào

| # | Vấn đề ở bản cũ | Điều chỉnh |
|---|---|---|
| 1 | Không có chỗ nào xử lý **ẩn mặt**, trong khi đây là tính năng cốt lõi. Kiểm duyệt ảnh chỉ ghi "nếu có" | Thêm `media-service` + `face-worker` (Python). Ảnh chỉ được đăng sau khi xử lý xong (fail closed) |
| 2 | Thiếu **tìm lân cận** và **trạng thái online** | Thêm `discovery-service` dùng Redis GEO + presence |
| 3 | "Ẩn danh" chưa có thiết kế cụ thể | Dùng `publicId` + alias + avatar con vật. Không bao giờ trả `sub` Keycloak, email, SĐT ra ngoài |
| 4 | Chưa tính rủi ro của chat/kết bạn với người lạ | Thêm chặn, báo cáo, rate limit, giới hạn theo độ tuổi |
| 5 | Con vật chủ đạo chỉ là tính năng sưu tầm | Cho nó vai trò thật: con vật chủ đạo là **khuôn mặt thay thế** trên ảnh của bạn |
| 6 | Thứ tự dựng để phần khó nhất (ẩn mặt) cuối cùng | Làm **spike ẩn mặt trước**. Nếu chất lượng không đạt thì đổi hướng sớm |
| 7 | 18–20 container | Thực tế khoảng 23. Dùng Docker Compose profiles, bật dần |
| 8 | Chat đa instance "broker hoặc Redis" chưa chốt; có câu tham chiếu "repo mẫu" | Chốt Redis pub/sub cho chat, Kafka cho event nghiệp vụ. Bỏ tham chiếu cũ |
| 9 | Chưa có cơ chế quẹt kết bạn kiểu Tinder | discovery-service tạo bộ thẻ gợi ý, quẹt phải gửi lời mời qua user-service |
| 10 | Ẩn mặt bằng AI cần GPU, nặng hơn nhiều so với sticker | face-worker tự chạy trên GPU (không gửi ảnh gốc ra dịch vụ ngoài), có profile Compose riêng và dự phòng sticker |
| 11 | Chưa có mô hình kinh doanh, chưa tính chi phí GPU trên mỗi ảnh | Thêm mục 12: học từ Tinder (freemium, bậc thang gói, mua lẻ), kinh tế đơn vị có GPU, chỉ số theo dõi |

## 1. Các quyết định đã chốt

- Bạn bè = người quen **trong app**, nên danh tính hiển thị luôn là alias + con vật, không lộ tên thật.
- Feed chỉ hiện bài của bạn bè (kiểu Locket), không có feed công khai.
- Kết bạn kiểu **Tinder**: app đưa ra bộ thẻ gợi ý (lân cận, đang online), người dùng **quẹt phải** để gửi lời kết bạn, **quẹt trái** để bỏ qua. Hai bên cùng quẹt phải thì thành bạn.
- Tiết lộ danh tính thật là việc của hai người, tự quyết qua tin nhắn. Hệ thống không có cơ chế tiết lộ riêng.
- Mọi lứa tuổi đều dùng được (không chặn theo tuổi). Vì có tìm lân cận và nhắn tin người lạ, tài khoản chưa đủ 18 vẫn có **mặc định an toàn hơn** (xem mục 5).
- Ẩn mặt bằng **ảnh sinh bằng AI**, có sticker 2D làm phương án dự phòng (mục 6).
- "troik" = Traefik.

## 2. Sơ đồ tổng thể

```
Client (mobile)
   │ HTTPS/WSS
Traefik (TLS, 80/443)
   │
API Gateway (Spring Cloud Gateway: JWT, Resilience4j, rate limit)
   │ lb://  (Eureka)         Config Server (Git)   Keycloak (+PG riêng)
   ├── user-service ──── MySQL (user_db)
   ├── post-service ──── MySQL (post_db) + Redis
   ├── media-service ─── MySQL (media_db) + MinIO (raw / public)
   ├── discovery-service ─ Redis (GEO + presence)
   ├── chat-service ──── MongoDB + Redis pub/sub
   ├── billing-service ─ PostgreSQL
   └── notification-service (không DB)
            Kafka  ◄──►  tất cả service (Outbox)
            face-worker (Python) ◄── Kafka, MinIO
   Prometheus / Loki / Tempo → Grafana
```

## 3. Đáp ứng yêu cầu công nghệ

| Yêu cầu | Cách làm |
|---|---|
| MongoDB cho tin nhắn | chat-service |
| PostgreSQL cho thanh toán | billing-service (Keycloak dùng database riêng, có thể cùng server PG khi dev) |
| MySQL cho bài đăng, bình luận | post-service. user-service và media-service dùng schema riêng, không truy cập chéo |
| Circuit breaker | Resilience4j ở gateway và mọi lời gọi đồng bộ |
| Config Server | Spring Cloud Config, lưu cấu hình không nhạy cảm trong Git |
| Eureka | Gateway định tuyến `lb://tên-service` |
| Grafana | Prometheus + Loki + Tempo |
| Message broker | Kafka (KRaft, không cần Zookeeper) |
| Traefik | Cổng ngoài cùng: TLS, chuyển vào gateway (giả định "troik" = Traefik) |
| Keycloak | Đăng nhập, cấp JWT (OIDC) |

Java + Spring Boot cho các service nghiệp vụ. Riêng `face-worker` dùng **Python** vì hệ sinh thái nhận diện mặt (OpenCV, MediaPipe, ONNX) nằm ở đó.

## 4. Các service

**user-service (MySQL `user_db`)**: hồ sơ ẩn danh (`publicId`, alias, con vật chủ đạo), kết bạn, chặn, báo cáo, bộ sưu tập con vật, quay thưởng, device token, cài đặt riêng tư (bật/tắt hiện ở lân cận). Bảng ánh xạ `sub` Keycloak ↔ `publicId` chỉ tồn tại ở đây và không bao giờ trả ra API.

**post-service (MySQL `post_db`)**: bài đăng, like, comment, feed bạn bè. Bài mới ở trạng thái `PENDING_MEDIA`, chỉ chuyển `PUBLISHED` khi nhận `PHOTO_READY`. Hạn mức ảnh/ngày đếm bằng Redis. DB chỉ giữ đường dẫn ảnh đã xử lý.

**media-service (MySQL `media_db` + MinIO)**: cấp presigned URL ngắn hạn, theo dõi trạng thái job (`UPLOADED → PROCESSING → READY / REJECTED`), phát và nhận event với face-worker.

**face-worker (Python, không DB)**: xem mục 6.

**discovery-service (Redis)**: vị trí gần đúng, trạng thái online, và **bộ thẻ quẹt**. Xem mục 5.
- Bộ thẻ gồm người lân cận hoặc đang online, đã bật chế độ khám phá, chưa là bạn, chưa chặn, chưa bị bạn quẹt trái gần đây.
- Mỗi thẻ chỉ có alias, con vật, khoảng cách theo mức. Không có ảnh thật hay thông tin định danh.
- Quẹt trái: lưu vào Redis với TTL (ví dụ 30 ngày) để không hiện lại ngay.
- Quẹt phải: gọi user-service tạo lời mời kết bạn. Nếu bên kia đã quẹt phải trước thì thành bạn ngay và phát `FRIEND_ACCEPTED`.
- Giới hạn số lượt quẹt phải mỗi ngày (Redis), mức giới hạn theo gói (miễn phí / Pro) lấy từ bản sao quyền lợi cập nhật bằng event.
- Boost: người dùng đang boost được ưu tiên xuất hiện trong bộ thẻ của người khác trong 30 phút (key Redis có TTL).

**chat-service (MongoDB)**: hội thoại và tin nhắn qua WebSocket, index `(conversationId, createdAt)`. Chỉ chat với bạn bè, hoặc người lạ đã chấp nhận lời mời. Nhận event `USER_BLOCKED` để cắt hội thoại ngay. Ảnh trong chat cũng đi qua media pipeline. Nhiều instance: dùng Redis pub/sub.

**billing-service (PostgreSQL)**: gói Pro, giao dịch, subscription, **mua lẻ** (Boost, lời mời ưu tiên, gói con vật) và sổ cái số dư vật phẩm. Nhận webhook Apple/Google, xác thực chữ ký rồi phát event. Pro mở quyền chọn con vật chủ đạo và nới hạn mức (xem mục 12).

**notification-service**: nghe Kafka, gửi push FCM/APNs.

Ngoài ra cần Redis (hạn mức, rate limit, cache bạn bè, cache trạng thái Pro, presence) và PostgreSQL riêng cho Keycloak.

## 5. Ẩn danh và riêng tư

- **Danh tính công khai** chỉ gồm `publicId` (ngẫu nhiên, không suy ra được từ `sub`), alias, con vật. Mọi DTO trả ra cho người khác đều không có email, SĐT, tên thật.
- **Xóa tài khoản**: phát `USER_DELETED`, mọi service xóa dữ liệu liên quan (cần cho yêu cầu của App Store/Google Play).
- **Vị trí** (rủi ro cao nhất của tính năng lân cận):
  - Chỉ lưu khi người dùng bật; toạ độ làm tròn về lưới khoảng 500 m ngay ở server, có TTL.
  - API chỉ trả **khoảng cách theo mức** ("dưới 1 km", "1–3 km"), không bao giờ trả toạ độ.
  - Chống dò vị trí bằng nhiều điểm (trilateration): làm tròn phía server, rate limit số lần tìm, thêm độ lệch cố định theo từng người.
  - Online: key `online:{publicId}` TTL khoảng 60 giây, gia hạn bằng heartbeat.
  - Redis GEO không có TTL cho từng member, nên dùng job dọn member hết hạn hoặc chia key theo ô geohash có TTL.
- **An toàn người lạ**: chặn và báo cáo ngay trong app (cũng là yêu cầu của store với nội dung người dùng tạo), giới hạn lượt quẹt phải và lời mời kết bạn mỗi ngày.
- **Tài khoản chưa đủ 18** (dùng ngày sinh người dùng khai khi đăng ký): vẫn dùng đầy đủ, nhưng bộ thẻ quẹt chỉ ghép với người cùng nhóm tuổi (dưới 18 với dưới 18), và vị trí hiển thị thô hơn (mức khoảng cách lớn hơn). Nên có từ đầu vì người lớn nhắn tin với trẻ vị thành niên là rủi ro pháp lý và an toàn lớn nhất của kiểu app này. Dễ nới ra sau, khó siết lại khi đã có người dùng.

## 6. Pipeline ẩn mặt

1. Client xin presigned URL từ media-service, upload thẳng vào bucket `raw` (private, mã hóa, tự xóa sau tối đa 1 giờ).
2. media-service phát `PHOTO_UPLOADED` (kèm con vật chủ đạo của người đăng tại thời điểm đó).
3. face-worker: **xóa EXIF** (có GPS), phát hiện mặt, tạo mặt nạ cho từng khuôn mặt (mở rộng ra quanh mặt và tóc), **sinh lại vùng đó thành mặt con vật bằng AI**, ghi vào bucket `public`.
4. Phát `PHOTO_READY` (hoặc `PHOTO_REJECTED`). post-service chuyển bài sang `PUBLISHED`.
5. Ảnh gốc xóa ngay sau khi xử lý thành công. Không backup bucket `raw`.

Quy tắc xử lý:
- Mặt người khác trong ảnh cũng bị che (dùng con vật ngẫu nhiên hoặc cùng con vật).
- **Thay hoàn toàn vùng mặt**, không dùng blur nhẹ vì có thể khôi phục.
- Mặt nhỏ, nghiêng, bị che một phần: để ngưỡng phát hiện thấp, thà che thừa còn hơn sót.
- Không có mặt: vẫn đăng, vẫn xóa EXIF.
- Worker lỗi hoặc timeout: retry tối đa 3 lần, rồi vào dead-letter queue. Chưa xử lý xong thì **không đăng**.

**Về AI:**
- Hướng làm: phát hiện mặt, tạo mặt nạ, rồi dùng mô hình inpainting (ví dụ Stable Diffusion inpainting kèm ControlNet hoặc IP-Adapter để giữ tư thế và hướng nhìn) sinh mặt con vật theo loài của người đăng.
- Cần **GPU** (khoảng 8–12 GB VRAM). Mỗi ảnh mất vài giây đến vài chục giây, nên app hiện ảnh "đang xử lý" cho người đăng, bạn bè chỉ thấy khi xong.
- **Dự phòng sticker 2D**: nếu AI lỗi, quá chậm hoặc kết quả không đạt kiểm tra thì chuyển sang chèn sticker con vật theo bounding box. Sticker vẫn che kín mặt nên không lộ danh tính, và người dùng không phải chờ vô hạn. Đây cũng là bản dùng khi dev trên máy không có GPU.
- Kiểm tra sau khi sinh: so vùng mặt nạ với ảnh gốc. Nếu vùng đó gần như không đổi thì coi là thất bại và dùng sticker.
- Không gửi ảnh gốc sang dịch vụ AI của bên thứ ba (OpenAI, Replicate, ...), vì phá cam kết ẩn danh: ảnh có mặt thật sẽ nằm ở server người khác. Tự chạy mô hình, hoặc thuê máy GPU của riêng bạn.

Chất lượng cần đo bằng số: bộ ảnh test tự gán nhãn, mục tiêu tỉ lệ **bỏ sót mặt dưới 1%**. Server là nơi quyết định; xử lý thêm trên máy người dùng chỉ để xem trước.

## 7. Giao tiếp đồng bộ / bất đồng bộ

| Việc | Cách | Lý do |
|---|---|---|
| Client → gateway → service | REST/WebSocket | Cần phản hồi ngay |
| Post kiểm tra "A, B là bạn bè" | REST sang user-service, cache Redis | Cần ngay khi xem feed |
| Upload ảnh → ẩn mặt → đăng | `PHOTO_UPLOADED`, `PHOTO_READY/REJECTED` | Xử lý ảnh chậm, không chặn người dùng |
| Mua Pro xong mở quyền | `SUBSCRIPTION_ACTIVATED/EXPIRED` | Billing không phụ thuộc ai |
| Mua lẻ (Boost, gói con vật) | `CONSUMABLE_GRANTED` | discovery và user-service cập nhật số dư/hiệu lực |
| Đổi con vật chủ đạo | `LEAD_ANIMAL_CHANGED` | media-service giữ bản sao |
| Like, comment, tin nhắn mới | Event cho notification-service | Push không làm chậm nghiệp vụ |
| Quẹt phải người khác | REST discovery → user-service | Cần biết ngay có thành bạn (match) không |
| Kết bạn thành công | `FRIEND_ACCEPTED` | Post, chat, notification cập nhật quan hệ |
| Chặn người dùng | `USER_BLOCKED` | Chat, post, discovery cắt ngay |
| Xóa tài khoản | `USER_DELETED` | Mọi service dọn dữ liệu |

Mọi event phát từ service có DB đi qua **Outbox pattern**, consumer phải **idempotent**.

## 8. Resilience

| Chỗ áp dụng | Chính sách |
|---|---|
| Gateway → mọi service | Timeout 2–3 giây, circuit breaker, lỗi rõ ràng khi mở mạch |
| post → user (bạn bè) | Cache 30–60 giây. user-service chết thì dùng cache, không có cache thì ẩn bài |
| Trạng thái Pro | Giữ bản sao cập nhật bằng event, không gọi billing mỗi request |
| Apple/Google xác thực hóa đơn | Retry backoff, circuit breaker, hàng đợi thử lại. Không để user bị trừ tiền mà không có Pro |
| face-worker | Timeout, retry giới hạn, DLQ. AI lỗi hoặc quá chậm thì dùng sticker. Không đăng ảnh khi chưa xử lý |
| discovery | Lỗi thì trả danh sách rỗng, app vẫn dùng được |
| Push FCM/APNs | Retry bất đồng bộ, lỗi bỏ qua |
| Chat | Bulkhead riêng |

Quy tắc chung: thanh toán, xác thực, **ẩn mặt** và vị trí dùng **fail closed**. Feed, thông báo, gợi ý dùng **fail soft**.

## 9. Bảo mật

- Traefik chỉ mở 80/443, các service nằm trong mạng nội bộ.
- Gateway kiểm tra JWT bằng public key Keycloak, mỗi service kiểm tra lại quyền nghiệp vụ.
- Bí mật (mật khẩu DB, khóa API) dùng biến môi trường hoặc Vault, không để trong Git của Config Server.
- Webhook Apple/Google xác thực chữ ký trước.
- Upload: presigned URL ngắn hạn, giới hạn kích thước và MIME, bucket `raw` không public.
- WebSocket: xác thực token ngay lúc handshake.
- Rate limit tại gateway (Redis) cho đăng ảnh, kết bạn, tìm lân cận.

## 10. Triển khai và tài nguyên

Dev bằng Docker Compose, khoảng 23 container: Traefik; Gateway, Config, Eureka, Keycloak; 7 service nghiệp vụ; face-worker; MySQL, MongoDB, PostgreSQL, Redis, MinIO, Kafka; Prometheus, Loki, Tempo, Grafana.

- Cần khoảng 16 GB RAM tối thiểu, 24–32 GB thì thoải mái.
- Chia Compose profiles: `core` (hạ tầng + DB), `app` (service), `ai` (face-worker chạy mô hình AI, cần GPU), `obs` (Grafana stack). Loki và Tempo bật sau cùng.
- Máy dev không có GPU: chạy face-worker ở chế độ sticker. Mô hình AI chạy trên máy có GPU NVIDIA (hoặc thuê máy GPU theo giờ để thử). Chi phí GPU là khoản lớn nhất khi lên production, nên tính trước giá mỗi ảnh.
- Dev dùng 1 MySQL server với 3 schema, 1 PostgreSQL server với 2 database. Production nên tách instance.
- Eureka và Config Server hữu ích khi chạy VM/Compose. Nếu sau này lên Kubernetes thì K8s đã lo discovery và config, nên đừng đầu tư quá sâu.

## 11. Thứ tự dựng

0. **Spike ẩn mặt (3–5 ngày)**: script Python chạy trên bộ ảnh test. Làm sticker trước (làm nền và dự phòng), rồi thử AI inpainting. Đo tỉ lệ bỏ sót mặt, thời gian mỗi ảnh, chi phí GPU mỗi ảnh. Chưa cần microservice.
1. Hạ tầng lõi: Config Server, Eureka, Gateway, Keycloak, Traefik.
2. user-service: đăng ký, `publicId`/alias, random con vật đầu tiên, kết bạn, chặn.
3. Kafka + Outbox + MinIO + media-service + face-worker.
4. post-service + feed (PENDING_MEDIA → PUBLISHED).
5. notification-service.
6. discovery-service (lân cận + online + bộ thẻ quẹt kết bạn).
7. chat-service.
8. billing-service + Pro + chọn con vật chủ đạo + quay thưởng + mua lẻ (Boost) + hạn mức theo gói.
9. Hoàn thiện Resilience4j (thêm timeout/circuit breaker ngay khi viết mỗi lời gọi đồng bộ, bước này để tinh chỉnh), rồi Grafana stack.

## 12. Câu hỏi còn mở

1. Tài khoản chưa đủ 18 chỉ ghép với nhóm tuổi của mình: bạn đồng ý mặc định này không, hay muốn bỏ?
2. Ngân sách GPU cho production: tự thuê máy GPU hay chạy theo yêu cầu (serverless GPU)? Quyết định sau khi có số liệu từ spike.
3. Có cho người dùng quẹt lại thẻ đã bỏ qua (hoàn tác) không, và đó có phải tính năng Pro không?
