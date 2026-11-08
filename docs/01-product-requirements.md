# 1. Yêu cầu sản phẩm (PRD)

> **Cập nhật (ADR-014)**: yêu cầu "thay mặt người trong ảnh bằng mặt con vật" **đã bị bỏ**. Ảnh được đăng nguyên bản (chỉ bạn bè xem), app xoá EXIF/GPS trước khi upload; "khuôn mặt" con vật của mỗi người giờ là **avatar duy nhất** ([19-avatar-mechanism.md](19-avatar-mechanism.md)). Các mục liên quan bên dưới được đánh dấu ~~gạch ngang~~ hoặc ghi chú.

## 1.1 Tầm nhìn

Một nơi để bạn bè chia sẻ khoảnh khắc ảnh nhanh gọn, mà **không ai phải lộ mặt hay danh tính**. Mặt người trong ảnh được thay bằng mặt con vật, vừa bảo vệ riêng tư vừa tạo nét vui nhộn riêng. Người dùng kết bạn mới bằng cách quẹt thẻ người lân cận hoặc đang online.

## 1.2 Mục tiêu và không mục tiêu

**Mục tiêu**
1. Gửi/nhận ảnh trong vòng bạn bè nhanh như Locket.
2. Không thể suy ra danh tính thật hoặc vị trí chính xác của người dùng từ bất kỳ dữ liệu nào app trả ra.
3. ~~Không có ảnh chứa mặt thật nào đến được người khác (bỏ sót mặt dưới 1% trên bộ test).~~ Đã bỏ (ADR-014): ảnh chỉ đến được bạn bè; không còn ẩn mặt.
4. Kết bạn với người lạ nhanh, nhưng có chặn/báo cáo và mặc định an toàn.

**Không mục tiêu (giai đoạn đầu)**
- Feed công khai, hashtag, khám phá nội dung.
- Video, story nhiều trang, livestream.
- Gọi thoại/video.
- Cơ chế tiết lộ danh tính của hệ thống (tiết lộ là việc của hai người qua tin nhắn).
- Bản web đầy đủ (client chính là mobile).

## 1.3 Persona

| Persona | Mô tả | Nhu cầu |
|---|---|---|
| **Mai, 16 tuổi** | Học sinh, dùng điện thoại nhiều, thích nhóm bạn kín | Gửi ảnh cho bạn thân, không muốn lộ mặt khi người lạ xem; cần an toàn khi gặp người lạ |
| **Khoa, 24 tuổi** | Sinh viên/đi làm, thích kết bạn mới | Tìm người cùng khu vực, chat làm quen, không muốn lộ danh tính ngay |
| **Linh, 30 tuổi** | Quan tâm riêng tư | Dùng app mà không phải đưa email/SĐT cho người lạ; muốn xoá sạch dữ liệu khi rời |
| **Quản trị viên** | Đội vận hành | Xử lý báo cáo, theo dõi hệ thống, ẩn nội dung vi phạm |

## 1.4 Danh sách tính năng và user story

Ưu tiên: **P0** = bắt buộc cho bản đầu, **P1** = sớm sau đó, **P2** = sau.

### A. Tài khoản và danh tính

| ID | User story | Ưu tiên |
|---|---|---|
| A1 | Là người dùng mới, tôi đăng ký/đăng nhập qua Keycloak (email hoặc đăng nhập mạng xã hội) | P0 |
| A2 | Tôi khai ngày sinh khi đăng ký để hệ thống áp mặc định an toàn theo nhóm tuổi | P0 |
| A3 | Hệ thống cấp cho tôi `publicId`, alias gợi ý và một con vật ngẫu nhiên đầu tiên | P0 |
| A4 | Tôi đổi alias (giới hạn tần suất, lọc từ cấm) | P0 |
| A5 | Tôi xem hồ sơ của mình và hồ sơ bạn bè, chỉ thấy alias + con vật | P0 |
| A6 | Tôi xoá tài khoản và toàn bộ dữ liệu của tôi bị xoá khỏi mọi service | P0 |
| A7 | Tôi đăng ký token push cho thiết bị | P0 |

### B. Con vật và sưu tầm

| ID | User story | Ưu tiên |
|---|---|---|
| B1 | Tôi có một avatar con vật duy nhất (không ai trùng); nó là "mặt" của tôi khi người khác thấy tôi ở thẻ, bài đăng, chat | P0 |
| B2 | ~~Tôi quay thưởng để nhận thêm con vật vào bộ sưu tập~~ — đã ngừng (`410 FEATURE_RETIRED`); avatar quay đúng một lần lúc đăng ký, quay thêm sẽ gắn với nạp tiền (docs/19 §8, chưa làm) | P1 |
| B3 | ~~Là người dùng Pro, tôi chọn con vật chủ đạo từ bộ sưu tập~~ — đã ngừng; con vật hiển thị chính là avatar | P1 |
| B4 | Tôi mua gói con vật để mở rộng bộ sưu tập | P2 |

### C. Ảnh và feed

| ID | User story | Ưu tiên |
|---|---|---|
| C1 | Tôi chụp/chọn ảnh và đăng; ảnh (đã xoá EXIF/GPS) hiện với bạn bè ngay sau khi upload xong. ~~Ảnh được xử lý ẩn mặt~~ (đã bỏ) | P0 |
| C2 | Trong lúc upload, tôi thấy ảnh ở trạng thái "đang tải"; bạn bè chưa thấy | P0 |
| C3 | Nếu ảnh bị từ chối (sai định dạng, quá cỡ), tôi nhận thông báo rõ ràng | P0 |
| C4 | Tôi xem feed bài của bạn bè, mới nhất trước | P0 |
| C5 | Tôi thả cảm xúc (like) và bình luận bài của bạn bè | P0 |
| C6 | Tôi xoá bài của mình | P0 |
| C7 | Mọi mặt người khác trong ảnh cũng được che | P0 |
| C8 | EXIF (GPS, thiết bị) bị xoá khỏi mọi ảnh | P0 |
| C9 | Có hạn mức ảnh/ngày theo gói | P0 |

### D. Bạn bè và khám phá

| ID | User story | Ưu tiên |
|---|---|---|
| D1 | Tôi bật/tắt chế độ khám phá (hiện ở lân cận / online) | P0 |
| D2 | Tôi nhận bộ thẻ gợi ý người lân cận hoặc đang online | P0 |
| D3 | Tôi quẹt phải để gửi lời mời; quẹt trái để bỏ qua | P0 |
| D4 | Hai bên cùng quẹt phải thì thành bạn ngay, cả hai được báo | P0 |
| D5 | Tôi xem/chấp nhận/từ chối lời mời đã nhận | P0 |
| D6 | Tôi huỷ kết bạn, chặn, báo cáo một người | P0 |
| D7 | Tôi thấy trạng thái online của bạn bè | P1 |
| D8 | Có giới hạn lượt quẹt phải mỗi ngày theo gói | P0 |
| D9 | Hoàn tác quẹt trái (Pro?) | P2 (câu hỏi mở) |
| D10 | Dùng Boost để được ưu tiên trong bộ thẻ người khác 30 phút | P1 |

### E. Nhắn tin

| ID | User story | Ưu tiên |
|---|---|---|
| E1 | Tôi nhắn tin văn bản thời gian thực với bạn bè | P0 |
| E2 | Tôi gửi ảnh trong chat (cùng luồng upload, không ẩn mặt) | P1 |
| E3 | Tôi chat với người lạ chỉ khi họ đã chấp nhận lời mời | P0 |
| E4 | Khi tôi chặn ai, hội thoại bị cắt ngay | P0 |
| E5 | Tôi thấy tin chưa đọc, đã đọc | P1 |

### F. Thông báo

| ID | User story | Ưu tiên |
|---|---|---|
| F1 | Push khi có bài mới của bạn, like, comment, tin nhắn, lời mời, match | P0 |
| F2 | Tôi tắt từng loại thông báo | P1 |

### G. Thanh toán

| ID | User story | Ưu tiên |
|---|---|---|
| G1 | Tôi mua Pro (thuê bao) qua Apple/Google | P1 |
| G2 | Tôi mua lẻ Boost, lời mời ưu tiên, gói con vật | P2 |
| G3 | Quyền lợi được mở trong vài giây sau khi mua; không bị trừ tiền mà không có quyền lợi | P1 |
| G4 | Tôi khôi phục giao dịch khi đổi máy | P1 |

### H. Quản trị và an toàn

| ID | User story | Ưu tiên |
|---|---|---|
| H1 | Quản trị viên xem hàng đợi báo cáo, xử lý (cảnh báo, khoá tài khoản, gỡ bài) | P1 |
| H2 | Hệ thống tự kiểm duyệt ảnh (nội dung nhạy cảm) trước khi đăng | P1 |
| H3 | Tài khoản dưới 18 chỉ được ghép thẻ với nhóm tuổi của mình | P0 (đề xuất) |

## 1.5 Quy tắc nghiệp vụ chính

1. **Chỉ bạn bè xem bài**: không có feed công khai.
2. **Kết bạn**: quẹt phải tạo lời mời; nếu bên kia đã quẹt phải trước thì thành bạn ngay.
3. **Ảnh chỉ đăng khi upload đã được kiểm tra** (đúng chủ, đúng loại, ≤ 10 MB); sai thì không đăng.
4. ~~Thay hoàn toàn vùng mặt, không blur~~ — đã bỏ (ADR-014).
5. ~~Con vật thay mặt là con vật chủ đạo của người đăng~~ — đã bỏ; người dùng hiện ra bằng avatar duy nhất của họ.
6. **Nhóm tuổi**: dưới 18 chỉ ghép với dưới 18; vị trí hiển thị thô hơn.
7. **Chặn** có hiệu lực hai chiều: không thấy nhau trong thẻ, feed, chat.
8. **Hạn mức** (ảnh, quẹt phải, lời mời) theo gói, đếm bằng Redis theo ngày UTC+7. Bảng số liệu ở [02-business-monetization.md](02-business-monetization.md).

## 1.6 Trạng thái bài đăng

```
PENDING_MEDIA ──PHOTO_READY──► PUBLISHED ──xoá──► DELETED
      │
      └──PHOTO_REJECTED──► REJECTED
```

## 1.7 Yêu cầu phi chức năng

| Hạng mục | Mục tiêu |
|---|---|
| Hiệu năng API | p95 < 300 ms cho đọc thông thường; feed p95 < 500 ms |
| Đăng ảnh | Từ lúc upload xong tới khi bài `PUBLISHED`: p95 dưới 3 s |
| Chat | Độ trễ gửi–nhận p95 < 500 ms trong cùng khu vực |
| Sẵn sàng | 99,5% (giai đoạn đầu); các luồng fail closed ưu tiên đúng hơn sẵn sàng |
| ~~Chất lượng ẩn mặt~~ | Đã bỏ (ADR-014). Thay bằng: ảnh trên kho không còn EXIF/GPS |
| Bảo mật | Không lộ `sub`, email, SĐT, toạ độ chính xác qua bất kỳ API nào |
| Quyền xoá dữ liệu | Hoàn tất xoá tài khoản trong tối đa 30 ngày, dữ liệu truy cập được xoá ngay (đề xuất) |
| Khả năng mở rộng | Chạy nhiều instance mỗi service; chat dùng Redis pub/sub |
| Quan sát | Mọi request có `traceId`; có dashboard và cảnh báo (xem tài liệu 11) |
| Nền tảng | iOS và Android; backend chạy Docker Compose (dev), Kubernetes (sau) |

## 1.8 Tiêu chí chấp nhận (mẫu cho các luồng cốt lõi)

**Đăng ảnh (C1–C3)**
- Ảnh JPEG/PNG/HEIC từ điện thoại: ảnh trên kho có EXIF rỗng (không GPS); bài `PUBLISHED`, chỉ bạn bè xem được.
- File sai định dạng hoặc quá 10 MB: bài `REJECTED`, người đăng nhận thông báo, được hoàn lượt ảnh; object bị xoá khỏi kho.
- Chưa có `PHOTO_READY` (Kafka/Outbox gián đoạn): bài ở `PENDING_MEDIA`, không xuất hiện trong feed bạn bè.
- Yêu cầu upload bị bỏ dở (không gọi `complete`) tự xoá sau tối đa 1 giờ.

**Quẹt thẻ (D2–D4, D8)**
- Bộ thẻ không chứa người đã là bạn, đã bị chặn, đã tắt khám phá, hoặc bị mình quẹt trái trong 30 ngày.
- Thẻ không chứa toạ độ, tên thật, ảnh thật.
- A quẹt phải B rồi B quẹt phải A: tạo quan hệ bạn đúng một lần, phát `FRIEND_ACCEPTED`, cả hai nhận push.
- Vượt hạn mức ngày: trả `429` kèm thời điểm reset.

**Chặn (D6, E4)**
- Sau khi A chặn B: B không thấy A trong thẻ, feed, chat, danh sách bạn; hội thoại đóng trong vòng vài giây.

**Xoá tài khoản (A6)**
- Sau khi xoá: user-service, post-service, media-service, discovery-service, chat-service, billing-service (phần dữ liệu cá nhân) đều ghi nhận đã xoá `publicId`; không còn bài/ảnh/tin nhắn/vị trí của người đó.

**Vị trí**
- Hai truy vấn liên tiếp từ cùng một người cho cùng một mục tiêu trả cùng một mức khoảng cách; không thể thu hẹp bằng cách xê dịch nhỏ.
