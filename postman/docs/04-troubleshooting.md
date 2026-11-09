# 4. Đọc kết quả và xử lý lỗi

## `401 Unauthorized`

Nguyên nhân thường gặp:

- `access_token` trống.
- Token hết hạn.
- Chưa chọn environment.
- Token thuộc realm/client khác.

Cách xử lý: lấy token mới theo [hướng dẫn PKCE](02-keycloak-oauth-pkce.md), dán vào `access_token` và lưu environment.

## `403 PROFILE_REQUIRED`

JWT hợp lệ nhưng tài khoản chưa có hồ sơ ứng dụng. Chạy `01 - User bootstrap → Register profile` trước các business test.

## Callback URL không hợp lệ

Kiểm tra chính xác:

```text
Client ID: postman
Callback URL: https://oauth.pstmn.io/v1/callback
```

Không dùng client `mobile`.

## `404` ở media smoke

Đây là kết quả mong đợi cho UUID cố ý không tồn tại. Chỉ coi là lỗi nếu response là `502`, `503` hoặc timeout.

## `503 Service Unavailable`

SSH vào server và kiểm tra container:

```powershell
ssh -i "<SSH_PRIVATE_KEY>" -o IdentitiesOnly=yes root@<DROPLET_IP>
```

```bash
cd /opt/animal-locket
docker compose \
  -f docker-compose.yml \
  -f deploy/demo/docker-compose.demo.yml \
  ps -a
```

Xem log service liên quan:

```bash
docker logs --tail=200 animal-locket-api-gateway-1
docker logs --tail=200 animal-locket-user-service-1
```

## Lỗi chứng chỉ

Kiểm tra hostname trong environment phải khớp IP Droplet hiện tại. Không dùng hostname cũ sau khi destroy/recreate.

Xem log ACME:

```bash
docker logs --tail=200 animal-locket-traefik-1
```

Cổng 80 và 443 phải mở. DNS `nip.io` phải trả đúng public IP.

## Alias không hợp lệ

`test_alias` phải dài 3–20 ký tự và tuân thủ validation backend. Dùng giá trị đơn giản như:

```text
postman_demo
```

## Sau khi tạo Droplet mới

1. Đổi `public_domain`, `api_base_url`, `auth_base_url`, `files_base_url`.
2. Xóa token cũ.
3. Lấy token từ Keycloak mới.
4. Chạy lại folder `00`, sau đó `01` và `02`.
