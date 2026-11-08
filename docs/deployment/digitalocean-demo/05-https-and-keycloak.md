# 5. HTTPS và Keycloak

## Cơ chế HTTPS

Traefik dùng Let's Encrypt HTTP-01 và tự tạo chứng chỉ cho:

```text
https://api.<PUBLIC_DOMAIN>
https://auth.<PUBLIC_DOMAIN>
https://files.<PUBLIC_DOMAIN>
```

Cổng 80 được giữ để xử lý ACME challenge và redirect sang HTTPS. Cổng 443 phục vụ API, Keycloak và file storage.

## Lưu chứng chỉ

Tài khoản ACME và chứng chỉ nằm trong volume:

```text
animal-locket_letsencrypt-data
```

Traefik tự gia hạn. Không xóa volume này khi chỉ restart hoặc update ứng dụng.

## Keycloak hostname

Demo giữ:

```text
sslRequired = external
KC_HOSTNAME = https://auth.<PUBLIC_DOMAIN>
```

Không chuyển `sslRequired` thành `none`; việc đó cho phép gửi thông tin đăng nhập qua HTTP.

## Mobile client

Client `mobile` dùng:

```text
Authorization Code + PKCE S256
Client secret: không có
Redirect: com.animallocket.app:/oauth2redirect
Direct password grant: tắt
```

## Postman client

Realm import đã chứa client `postman`. Để bảo đảm client tồn tại trên realm đang chạy, dùng script idempotent:

```bash
cd /opt/animal-locket
chmod +x deploy/demo/install-postman-client.sh
deploy/demo/install-postman-client.sh
```

Client `postman` dùng:

```text
Authorization Code + PKCE S256
Callback: https://oauth.pstmn.io/v1/callback
Client secret: không có
Direct password grant: tắt
Service account: tắt
```

## Dấu hiệu cấp chứng chỉ thành công

```bash
docker logs --tail=100 animal-locket-traefik-1
```

Tìm các dòng tương tự:

```text
The server validated our request
Server responded with a certificate
```

Không cần chạy lại thủ công; Traefik quản lý việc gia hạn.
