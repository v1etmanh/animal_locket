# 16. Thuật ngữ

| Thuật ngữ | Nghĩa trong dự án |
|---|---|
| **Alias** | Tên hiển thị tự chọn của người dùng. Không phải tên thật, có thể đổi (có giới hạn tần suất). |
| **publicId** | Mã định danh công khai, ngẫu nhiên (ULID/UUIDv4), không suy ra được từ `sub` Keycloak. Là định danh duy nhất được phép xuất hiện trong API, event gửi ra ngoài và URL. |
| **sub** | Subject trong JWT Keycloak. Chỉ ánh xạ sang `publicId` bên trong user-service, không bao giờ trả ra ngoài. |
| **Con vật chủ đạo (lead animal)** | Con vật người dùng đang dùng làm danh tính và là **khuôn mặt thay thế** trên ảnh của họ. |
| **Bộ sưu tập con vật** | Các con vật người dùng sở hữu (qua quay thưởng, mua gói). |
| **Quay thưởng (spin)** | Cơ chế nhận con vật mới ngẫu nhiên, có giới hạn lượt. |
| **Thẻ (card)** | Một gợi ý kết bạn trong bộ thẻ quẹt: alias, con vật, khoảng cách theo mức. |
| **Quẹt phải / trái** | Phải = gửi lời mời kết bạn (hoặc chấp nhận nếu bên kia đã quẹt phải). Trái = bỏ qua, ẩn thẻ trong một thời gian. |
| **Match** | Hai người cùng quẹt phải, thành bạn ngay. |
| **Boost** | Vật phẩm mua lẻ: được ưu tiên xuất hiện trong bộ thẻ của người khác 30 phút. |
| **Lời mời ưu tiên** | Vật phẩm mua lẻ: lời mời kết bạn được đẩy lên đầu hàng đợi của người nhận. |
| **Gói con vật (animal pack)** | Vật phẩm mua lẻ: nhóm con vật thêm vào bộ sưu tập. |
| **Pro** | Gói thuê bao: chọn con vật chủ đạo, nới hạn mức. |
| **Entitlement (quyền lợi)** | Bản sao trạng thái Pro và vật phẩm đang có hiệu lực, cập nhật bằng event, cache ở Redis. |
| **Raw bucket** | Bucket MinIO private chứa ảnh gốc chưa xử lý, tự xoá sau tối đa 1 giờ. |
| **Public bucket** | Bucket chứa ảnh đã ẩn mặt, được phép phát cho bạn bè. |
| **Face-worker** | Worker Python xử lý ảnh: xoá EXIF, phát hiện mặt, thay mặt. |
| **Inpainting** | Kỹ thuật AI sinh lại một vùng ảnh (ở đây là vùng mặt) theo mặt nạ. |
| **Sticker fallback** | Phương án dự phòng: chèn sticker 2D con vật lên bounding box của mặt. |
| **Fail closed** | Khi lỗi thì từ chối/không đăng (áp dụng cho thanh toán, xác thực, ẩn mặt, vị trí). |
| **Fail soft** | Khi lỗi thì suy giảm nhẹ nhàng, app vẫn dùng được (feed, thông báo, gợi ý). |
| **Outbox pattern** | Ghi event vào bảng `outbox` cùng transaction với dữ liệu nghiệp vụ, tiến trình riêng đẩy lên Kafka. Tránh mất event hoặc ghi đôi. |
| **Idempotent consumer** | Consumer xử lý cùng một event nhiều lần vẫn cho kết quả như một lần (dựa vào `eventId`). |
| **DLQ** | Dead-letter queue: nơi chứa message xử lý lỗi sau số lần retry tối đa. |
| **Geohash / ô lưới** | Cách chia bản đồ thành ô, dùng để làm tròn vị trí về ~500 m. |
| **Trilateration** | Kỹ thuật kẻ tấn công dò vị trí thật bằng cách truy vấn từ nhiều điểm. Hệ thống có biện pháp chống. |
| **Nhóm tuổi** | `MINOR` (dưới 18) hoặc `ADULT` (từ 18). Quyết định ghép thẻ và độ thô của vị trí. |
| **Presigned URL** | URL upload/download có chữ ký, hết hạn ngắn, cho client truyền thẳng với MinIO. |
| **Troik** | Cách gọi "Traefik" trong yêu cầu gốc. |
