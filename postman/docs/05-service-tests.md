# 05 - Kiểm thử chức năng billing, chat, discovery, media

Collection [Animal-Locket-Service-Tests](../Animal-Locket-Service-Tests.postman_collection.json) kiểm tra hành vi nghiệp vụ của bốn service qua API Gateway, gồm cả trường hợp đúng và trường hợp phải bị từ chối. User, post và notification service do phần test khác phụ trách.

| Thư mục | Nội dung chính |
|---|---|
| 00 - Setup | Gateway chặn request thiếu JWT; lấy `my_public_id` và `friend_public_id` |
| 01 - media-service | Từ chối định dạng/kích thước sai; xin URL ký sẵn → `complete` trước khi upload bị 409 → `PUT` ảnh lên R2 → `complete` → trạng thái `READY` và URL xem; 404; `/internal` không lộ ra ngoài |
| 02 - discovery-service | Khi tắt khám phá thì vị trí, bộ thẻ, Boost bị 403; bật lên rồi kiểm tra vị trí, heartbeat, presence (chỉ trả bạn bè), bộ thẻ không lộ toạ độ, quẹt chính mình bị chặn, quẹt trái/phải, Boost; cuối cùng tắt khám phá lại |
| 03 - chat-service | Không mở hội thoại với chính mình/người lạ; mở hội thoại với bạn (idempotent); glyph: sai số điểm, sai màu, nghĩa rỗng, `clientMutationId` sai, tạo mới, gửi lại cùng mã trả 200, trùng hình bị 409; tin GLYPH, gửi lại cùng `clientId` không nhân đôi, tin TEXT theo cấu hình server; lịch sử, đánh dấu đã đọc, lưu trữ glyph rồi không gửi được |
| 04 - billing-service | Danh mục sản phẩm, ví, xác minh biên lai sai/giả không được cấp, phiên thanh toán web và trang `/pay` công khai, token lạ 404, webhook không chữ ký bị từ chối, `/internal/wallet` không lộ ra ngoài |

## Chuẩn bị tài khoản test

1. Lấy JWT theo [02 - Keycloak PKCE](02-keycloak-oauth-pkce.md). Tài khoản phải đã đăng ký hồ sơ (`POST /api/v1/users/register`, thư mục bootstrap của collection smoke).
2. Tài khoản test cần **ít nhất một bạn** để chạy chat và quẹt phải. Nếu server bật `DEV_BUDDY_PUBLIC_ID` thì có sẵn; nếu không, tạo tài khoản thứ hai, gửi `POST /api/v1/friends/requests {"toPublicId": "..."}` từ tài khoản test và chấp nhận bằng `POST /api/v1/friends/requests/{id}/accept` từ tài khoản kia.

## Chạy

Postman app: import collection cùng environment `Animal Locket Demo`, dán token vào `access_token`, chọn **Run collection** với **Delay 600 ms**. Ở request `PUT image to signed URL`, chọn lại file `postman/fixtures/test-image.png` nếu Postman báo thiếu file.

Newman (từ thư mục `postman/`):

```bash
npx newman run Animal-Locket-Service-Tests.postman_collection.json -e Animal-Locket-Demo.postman_environment.json --env-var access_token=<JWT> --working-dir . --delay-request 600
```

Cần delay vì gateway giới hạn discovery 2 request/giây (burst 10); chạy không delay sẽ gặp 429. Token Keycloak sống 10 phút; cả collection chạy khoảng một phút.

Collection có thể chạy lặp lại: mỗi lần tạo glyph với hình ngẫu nhiên và mã idempotency mới.

## Sửa collection

Không sửa file JSON trực tiếp. Sửa `postman/tools/build_service_tests.py` rồi chạy:

```bash
python3 postman/tools/build_service_tests.py
```

## Kết quả trên server demo (09/11/2026)

74 request, 145 assertion, 1 lỗi:

- `GET /api/v1/discovery/presence` thiếu `ids` trả **500** thay vì 400. `ApiExceptionHandler` trong `libs/common` chưa xử lý `MissingServletRequestParameterException`, nên lỗi rơi vào nhánh `Exception` chung. Lỗi này ảnh hưởng mọi endpoint có `@RequestParam` bắt buộc ở tất cả service.
