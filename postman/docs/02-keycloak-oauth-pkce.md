# 2. Lấy JWT bằng Authorization Code + PKCE

## Mở cấu hình OAuth

1. Chọn collection **Animal Locket Demo Smoke**.
2. Mở tab **Authorization**.
3. Chọn type **OAuth 2.0**.
4. Chọn **Get New Access Token**.

## Giá trị cấu hình

```text
Token Name:
Animal Locket Demo

Grant Type:
Authorization Code (With PKCE)

Callback URL:
https://oauth.pstmn.io/v1/callback

Auth URL:
https://auth.<PUBLIC_DOMAIN>/realms/animal-locket/protocol/openid-connect/auth

Access Token URL:
https://auth.<PUBLIC_DOMAIN>/realms/animal-locket/protocol/openid-connect/token

Client ID:
postman

Client Secret:
để trống

Code Challenge Method:
SHA-256

Scope:
openid profile email

Client Authentication:
Send client credentials in body
```

Postman tự sinh code verifier và code challenge. Không nhập password vào collection hoặc environment.

## Đăng ký hoặc đăng nhập

Sau khi chọn **Get New Access Token**, Postman mở trang Keycloak:

- Tài khoản mới: chọn đăng ký, dùng password ít nhất 10 ký tự và không giống email/username.
- Tài khoản đã có: đăng nhập bình thường.

Keycloak redirect về callback chính thức của Postman và trả authorization code. Postman đổi code lấy access token.

## Lưu token

1. Copy access token vừa nhận.
2. Mở environment **Animal Locket Demo**.
3. Dán vào biến `access_token` ở current/local value.
4. Nhấn **Save**.

Token demo có thời hạn ngắn. Nếu request trả `401`, lấy token mới.

## Vì sao dùng client riêng

Client `postman` chỉ chấp nhận callback `https://oauth.pstmn.io/v1/callback`, dùng PKCE S256, không có secret, không có service account và tắt direct password grant. Client `mobile` giữ callback custom scheme của ứng dụng nên không dùng cho Postman.
