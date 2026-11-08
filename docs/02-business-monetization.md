# 2. Mô hình kinh doanh và kiếm tiền

> Kế hoạch gốc (mục 12 trong bảng điều chỉnh) chỉ nêu hướng: freemium, bậc thang gói, mua lẻ, kinh tế đơn vị có GPU. Các con số trong tài liệu này là **Đề xuất** để làm điểm xuất phát, cần hiệu chỉnh sau khi có dữ liệu thật.

## 2.1 Nguyên tắc

1. **Miễn phí đủ dùng**: giá trị cốt lõi (đăng ảnh cho bạn bè, kết bạn, chat với bạn) luôn miễn phí để mạng lưới lớn lên.
2. **Trả tiền để có thêm quyền chọn và hạn mức**, không trả tiền để mua sự an toàn: chặn, báo cáo không bao giờ bị khoá sau paywall.
3. **Không bán dữ liệu người dùng**, không quảng cáo nhắm theo vị trí chính xác.
4. **Chi phí GPU là khoản biến đổi lớn nhất**, nên hạn mức ảnh/ngày gắn với chi phí này.

## 2.2 Các gói

| Tính năng | Miễn phí | Pro |
|---|---|---|
| Đăng ảnh / ngày | 10 | 50 |
| Quẹt phải / ngày | 30 | 150 |
| Lời mời kết bạn / ngày | 20 | 80 |
| Con vật chủ đạo | Ngẫu nhiên được cấp lúc đăng ký | Chọn từ bộ sưu tập |
| Quay thưởng | 1 lượt/tuần | 1 lượt/ngày |
| Hoàn tác quẹt trái | Không | Có (câu hỏi mở) |
| Quảng cáo | Không (đề xuất giữ app sạch) | Không |

Giá tham khảo (đề xuất): Pro tháng 49.000đ, năm 399.000đ.

## 2.3 Mua lẻ (consumable)

| Vật phẩm | Tác dụng | Cách tính |
|---|---|---|
| **Boost** | Ưu tiên xuất hiện trong bộ thẻ người khác 30 phút | 1 đơn vị = 1 lần dùng |
| **Lời mời ưu tiên** | Lời mời được đẩy lên đầu danh sách người nhận | 1 đơn vị = 1 lời mời |
| **Gói con vật** | Thêm một nhóm con vật vào bộ sưu tập (theo chủ đề, độ hiếm) | Mua một lần, vĩnh viễn |

Số dư vật phẩm ghi trong **sổ cái** của billing-service (mỗi lần cộng/trừ là một dòng, không sửa số dư trực tiếp).

## 2.4 Kinh tế đơn vị (khung tính)

Từ khi bỏ ẩn mặt (ADR-014) không còn chi phí GPU; chi phí ảnh chủ yếu là lưu trữ và thao tác trên Cloudflare R2 (R2 không tính phí băng thông ra).

```
Chi phí lưu trữ / người dùng hoạt động / tháng
   = ảnh trung bình/ngày × 30 × cỡ ảnh trung bình × giá lưu trữ R2 (cộng dồn vì ảnh giữ tới khi xoá tài khoản)
Chi phí thao tác / người dùng / tháng = (số PUT + số GET ký sẵn) × giá thao tác R2
Chi phí hạ tầng / người dùng = lưu trữ + thao tác + chi phí cố định chia đầu người (DB, máy chủ)
Biên lợi nhuận Pro = giá Pro (sau phí store 15–30%) − chi phí hạ tầng người dùng Pro
```

Đòn bẩy giảm chi phí:
- Client nén ảnh trước khi upload (đã làm).
- Xoá ảnh khỏi R2 khi xoá bài (chưa làm, xem 14.4).
- Hạn mức ảnh/ngày theo gói.

## 2.5 Phí store và thanh toán

- Apple/Google lấy 15–30% phí; giá niêm yết phải tính cả khoản này.
- Quyền lợi chỉ được mở sau khi billing-service **xác thực chữ ký webhook / hoá đơn**. Không mở quyền chỉ dựa vào tuyên bố của client.
- Hoàn tiền/huỷ: nhận thông báo từ store, phát `SUBSCRIPTION_EXPIRED` hoặc thu hồi vật phẩm.
- **Thanh toán web** (đã có code, chưa chạy với tài khoản thật): PayPal (USD) và VietQR qua payOS (VND) trên trang `/pay/**`. Giá web lưu riêng trong `products` (`price_usd_cents`, `price_vnd`) và hiện là **giá tạm** (ví dụ Pro tháng 2,99 USD / 79.000 VND). Thuê bao web trả trước theo kỳ, không tự gia hạn. Phí cổng web thấp hơn store nhưng **app phát hành trên App Store/Google Play vẫn phải dùng thanh toán trong ứng dụng** cho hàng hoá số; dẫn người dùng sang trang web có thể bị từ chối khi duyệt. payOS không có sandbox.

## 2.6 Chỉ số theo dõi

| Nhóm | Chỉ số |
|---|---|
| Tăng trưởng | Đăng ký mới/ngày, DAU/MAU, retention D1/D7/D30 |
| Mạng lưới | Số bạn trung bình/người, tỉ lệ match trên số lượt quẹt phải, thời gian đến lần kết bạn đầu |
| Tương tác | Ảnh đăng/DAU, like và comment/ảnh, tin nhắn/DAU |
| Ẩn mặt | Tỉ lệ bỏ sót mặt (bộ test), % ảnh dùng AI so với sticker, p95 thời gian xử lý, chi phí GPU/ảnh |
| An toàn | Báo cáo/1000 người dùng, thời gian xử lý báo cáo, tỉ lệ chặn |
| Doanh thu | Tỉ lệ chuyển đổi Pro, ARPU, ARPPU, churn thuê bao, doanh thu mua lẻ |
| Chi phí | Chi phí hạ tầng/DAU, chi phí GPU/tháng |

## 2.7 Thử nghiệm giá và gói

- Thử nghiệm A/B hạn mức (số lượt quẹt, số ảnh) để tìm điểm chuyển đổi mà không làm hỏng trải nghiệm miễn phí.
- Chỉ thử trên nhóm người trưởng thành. Không thử nghiệm nút mua/ưu đãi gây áp lực với tài khoản dưới 18.

## 2.8 Lưu ý với tài khoản dưới 18

- Việc mua bán trong app phải theo chính sách store về trẻ vị thành niên (xác nhận phụ huynh theo nền tảng).
- Không có vật phẩm mua lẻ nào tăng khả năng tiếp cận người lớn; Boost của tài khoản dưới 18 chỉ có hiệu lực trong nhóm tuổi của họ.
