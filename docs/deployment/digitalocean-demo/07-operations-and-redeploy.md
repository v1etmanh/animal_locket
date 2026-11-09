# 7. Vận hành, destroy và tạo lại

## Xem trạng thái và tài nguyên

```bash
cd /opt/animal-locket

docker compose \
  -f docker-compose.yml \
  -f deploy/demo/docker-compose.demo.yml \
  ps -a

docker stats --no-stream
free -h
df -h /
```

## Xem log

```bash
docker compose \
  -f docker-compose.yml \
  -f deploy/demo/docker-compose.demo.yml \
  logs --tail=200
```

Theo dõi riêng gateway:

```bash
docker logs -f animal-locket-api-gateway-1
```

## Dừng và chạy lại

Dừng nhưng giữ dữ liệu:

```bash
docker compose \
  -f docker-compose.yml \
  -f deploy/demo/docker-compose.demo.yml \
  stop
```

Chạy lại:

```bash
COMPOSE_PROFILES=core,app docker compose \
  -f docker-compose.yml \
  -f deploy/demo/docker-compose.demo.yml \
  start
```

Không dùng `down -v` nếu cần giữ database hoặc chứng chỉ.

## Trước khi destroy

1. Commit và push `deploy/demo/`, `postman/` và tài liệu deployment.
2. Backup dữ liệu cần giữ.
3. Ghi lại branch/commit đã deploy.
4. Xác nhận không cần giữ database hoặc MinIO volume.

Không commit:

- `/opt/animal-locket/.env`.
- Private SSH key.
- Postman access token.
- `acme.json`.
- Database volume.

## Destroy và ngừng tính phí

Trong DigitalOcean chọn Droplet → **Destroy**. Chỉ power off thường không ngừng hoàn toàn chi phí tài nguyên.

## Tạo lại

1. Tạo Droplet mới theo [bước 2](02-create-droplet-and-ssh.md).
2. IP mới tạo ra `PUBLIC_DOMAIN` mới.
3. Chạy [bootstrap](03-bootstrap-server.md).
4. Chạy [deploy stack](04-deploy-stack.md).
5. Cấu hình [HTTPS và Keycloak](05-https-and-keycloak.md).
6. Chạy [smoke check](06-smoke-check-and-flutter.md).
7. Đổi URL trong Postman environment và Flutter.

SSH key có thể tái sử dụng nếu private key còn an toàn. Không cần tạo key mới chỉ vì IP thay đổi.
