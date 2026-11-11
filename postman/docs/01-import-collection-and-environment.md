# 1. Import collection và environment

## Cài Postman

Dùng Postman Desktop để callback OAuth hoạt động ổn định.

## Import collection

1. Mở Postman.
2. Chọn **Import → Files**.
3. Chọn `postman/Animal-Locket-Demo-Smoke.postman_collection.json`.
4. Xác nhận collection **Animal Locket Demo Smoke** xuất hiện.

## Import environment

1. Chọn **Import → Files** lần nữa.
2. Chọn `postman/Animal-Locket-Demo.postman_environment.json`.
3. Chọn environment **Animal Locket Demo** ở góc trên bên phải.

## Kiểm tra biến

Với server hiện tại:

```text
public_domain = 188-166-218-200.nip.io
api_base_url = https://api.188-166-218-200.nip.io
auth_base_url = https://auth.188-166-218-200.nip.io
files_base_url = https://files.188-166-218-200.nip.io
realm = animal-locket
client_id = postman
access_token = <để trống>
test_alias = postman_demo
test_birth_date = 2000-01-01
```

Nếu tạo Droplet mới, thay `public_domain` và cả ba URL bằng hostname dựa trên IP mới. Nhấn **Save** sau khi sửa.

## Kiểm tra public trước OAuth

Chạy folder `00 - Public edge and TLS`. Kết quả mong đợi:

| Request | Mã đúng |
|---|---:|
| HTTP redirects to HTTPS | 301 hoặc 308 |
| Keycloak OIDC discovery | 200 |
| Keycloak admin is not public | 403 |
| MinIO public health | 200 |
| API rejects an Unauthorized request | 401 |

Các mã `403` và `401` trên là kết quả bảo mật đúng, không phải lỗi deployment.
