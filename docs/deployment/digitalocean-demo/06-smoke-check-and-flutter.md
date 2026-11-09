# 6. Smoke check và Flutter local

## Smoke check tối thiểu

```bash
cd /opt/animal-locket
PUBLIC_DOMAIN="$(grep '^PUBLIC_DOMAIN=' .env | cut -d= -f2-)"

docker compose \
  -f docker-compose.yml \
  -f deploy/demo/docker-compose.demo.yml \
  ps -a

curl -fsS \
  "https://auth.$PUBLIC_DOMAIN/realms/animal-locket/.well-known/openid-configuration" \
  >/dev/null

curl -fsS \
  "https://files.$PUBLIC_DOMAIN/minio/health/live" \
  >/dev/null

api_status=$(curl -sS -o /dev/null -w '%{http_code}' \
  "https://api.$PUBLIC_DOMAIN/api/v1/users/me")
test "$api_status" = 401
```

Điều kiện đạt:

- Container dài hạn là `healthy`.
- `kafka-init` và `minio-init` là `Exited (0)`.
- OIDC và MinIO trả `200`.
- API cần đăng nhập trả `401`.

Traefik cố ý không route `/actuator` ra Internet.

## Kiểm tra đầy đủ bằng Postman

Sau smoke check tối thiểu, dùng [Postman smoke tests](../../../postman/README.md) để kiểm tra user, media, post, discovery, chat và billing service.

## Chạy Flutter local

Trên Windows:

```powershell
cd "D:\ky 8\animal_locket\mobile"

flutter run `
  --dart-define=API_BASE_URL=https://api.<PUBLIC_DOMAIN> `
  --dart-define=WS_URL=wss://api.<PUBLIC_DOMAIN>/ws/chat `
  --dart-define=KEYCLOAK_ISSUER=https://auth.<PUBLIC_DOMAIN>/realms/animal-locket `
  --dart-define=KEYCLOAK_CLIENT_ID=mobile `
  --dart-define=OAUTH_REDIRECT_URL=com.animallocket.app:/oauth2redirect
```

Flutter gọi API Gateway, Keycloak và WebSocket public. Flutter không kết nối trực tiếp tới database, Kafka, Redis hoặc service nội bộ.

Một số màn hình Flutter hiện vẫn dùng dữ liệu demo cố định; server hoạt động không có nghĩa mọi màn hình đã được nối API thật.
