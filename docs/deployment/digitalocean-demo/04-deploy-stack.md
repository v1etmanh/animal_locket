# 4. Deploy stack

## Clone source

```bash
git clone https://github.com/v1etmanh/animal_locket.git /opt/animal-locket
cd /opt/animal-locket
git checkout <GIT_REF>
```

`GIT_REF` phải chứa thư mục `deploy/demo/`. Vì vậy phải commit và push các file deployment trước khi destroy server cũ.

## Sinh `.env`

```bash
DROPLET_IP='<DROPLET_IP>'
PUBLIC_DOMAIN="$(printf '%s' "$DROPLET_IP" | tr . -).nip.io"

cd /opt/animal-locket
chmod +x deploy/demo/generate-env.sh
ENV_FILE=/opt/animal-locket/.env deploy/demo/generate-env.sh "$PUBLIC_DOMAIN"
chmod 600 /opt/animal-locket/.env
```

Script sinh mật khẩu ngẫu nhiên cho database, Redis, MinIO, Keycloak, Config Server và internal token. Không in hoặc commit `.env`.

## Đặt email Let's Encrypt

```bash
LETSENCRYPT_EMAIL='<LETSENCRYPT_EMAIL>'
sed -i "s/^[[:space:]]*email: .*/      email: $LETSENCRYPT_EMAIL/" deploy/demo/traefik.demo.yml
```

## Kiểm tra Compose

```bash
docker compose \
  -f docker-compose.yml \
  -f deploy/demo/docker-compose.demo.yml \
  config --quiet
```

## Khởi động core

```bash
COMPOSE_PROFILES=core docker compose \
  -f docker-compose.yml \
  -f deploy/demo/docker-compose.demo.yml \
  up -d --build
```

Core gồm MySQL, PostgreSQL, MongoDB, Redis, Kafka, MinIO, Keycloak và Traefik.

`kafka-init` và `minio-init` hoàn thành với `Exited (0)` là đúng thiết kế.

## Build Java tuần tự

Không build tất cả JVM song song trên máy 8 GB.

```bash
for service in \
  eureka-server config-server api-gateway user-service media-service \
  post-service notification-service discovery-service chat-service billing-service
do
  echo "BUILDING:$service"
  docker compose \
    -f docker-compose.yml \
    -f deploy/demo/docker-compose.demo.yml \
    build "$service" || exit 1
done
```

## Khởi động ứng dụng

```bash
COMPOSE_PROFILES=core,app docker compose \
  -f docker-compose.yml \
  -f deploy/demo/docker-compose.demo.yml \
  up -d --no-build
```

Lần đầu có thể mất 2–4 phút vì Flyway, Hibernate, Eureka và Keycloak cùng khởi động.

## Trường hợp PostgreSQL cũ thiếu schema Keycloak

Droplet mới với volume mới không cần bước này. Chỉ dùng khi log Keycloak báo thiếu schema `keycloak`:

```bash
docker exec -i animal-locket-postgres-1 psql -U animal -d billing_db \
  < deploy/demo/postgres-keycloak-schema.sql

docker compose \
  -f docker-compose.yml \
  -f deploy/demo/docker-compose.demo.yml \
  restart keycloak
```
