# 10. Triển khai và hạ tầng

Mô tả theo các file đã có: `docker-compose.yml`, `.env.example`, `Makefile`, `deploy/` (Traefik, Keycloak, MySQL/PostgreSQL init, observability, `Dockerfile.java`). Hướng dẫn chạy từng bước: [deploy/README.md](../deploy/README.md).

> **Trạng thái**: các file này **chưa được chạy thử trọn vẹn** trên Docker. Mục 14.5 trong [14-roadmap-risks.md](14-roadmap-risks.md) là checklist kiểm tra lần đầu.

## 10.1 Tổng quan

- Docker Compose, một mạng nội bộ `animal-net`. **Chỉ Traefik publish cổng ra máy chủ** (`HTTP_PORT`/`HTTPS_PORT`, mặc định 80/443; dashboard ở `127.0.0.1:8088`). Mọi thành phần khác chỉ tồn tại trong mạng nội bộ.
- **Cơ sở dữ liệu không chạy trong Compose**: MySQL (Aiven), PostgreSQL (Supabase, cho billing và Keycloak) và MongoDB (Atlas) là dịch vụ ngoài, nối bằng biến trong `.env`. Ảnh nằm trên **Cloudflare R2**.
- Ba **profile** (bật dần theo tài nguyên):

| Profile | Thành phần |
|---|---|
| `core` | Redis 7, Kafka 3.8 KRaft (+ `kafka-init`), Keycloak 26, Traefik v3 |
| `app` | eureka-server, config-server, api-gateway, user/media/post/notification/discovery/chat/billing-service |
| `obs` | Prometheus, kafka-exporter, Loki, Tempo, Alloy, Grafana |

`COMPOSE_PROFILES` trong `.env` mặc định `core,app`. Profile khác luôn cần `core` đi kèm.

```bash
cp .env.example .env        # rồi ĐỔI mọi mật khẩu/khoá (hoặc: make env)
docker compose up -d --build        # = core + app
make obs                    # thêm giám sát
make check                  # docker compose config --quiet
make down | make reset      # reset XOÁ cả dữ liệu (chỉ dev)
```

## 10.2 Sơ đồ phụ thuộc khởi động

```
core: kafka ─► kafka-init (tạo topic)      keycloak (DB PostgreSQL ngoài)      redis      traefik
app : eureka-server ─► config-server ─► {api-gateway, user, media, post, notification, discovery, chat, billing}
      (service chờ redis "healthy" / kafka-init "completed" tương ứng; DB ngoài không có healthcheck trong Compose)
```

`kafka-init` tạo tường minh các topic với **3 phân vùng**: `user.events`, `friend.events`, `media.events`, `media.results`, `post.events`, `chat.events`, `billing.events`; `media.events.dlq` giữ 30 ngày. `media.results` là di sản của face-worker đã gỡ, không ai dùng. Consumer Java ghi lỗi sang `<topic>.dlq` nhưng `kafka-init` mới tạo `media.events.dlq`; các DLQ khác cần thêm (xem [07-event-catalog.md](07-event-catalog.md) §7.7). `KAFKA_AUTO_CREATE_TOPICS_ENABLE=false` nên gõ sai tên topic sẽ lỗi thay vì tạo nhầm.

## 10.3 Traefik và địa chỉ công khai

Host (với `PUBLIC_DOMAIN`, dev mặc định `localhost`):

| Host | Đích | Ghi chú |
|---|---|---|
| `api.<domain>` | api-gateway:8080 | chỉ `PathPrefix` `/api/`, `/ws/`, `/webhooks/`; middleware `security-headers`, `ratelimit` (50 req/s/IP, burst 100) |
| `api.<domain>/pay/` | api-gateway:8080 (→ billing) | trang thanh toán web (router `pay`) |
| `auth.<domain>` | Keycloak:8080 | đăng nhập OIDC; `/admin`, `/realms/master`, `/metrics`, `/health` **chỉ mạng nội bộ** (`admin-only`) |
| `grafana.<domain>` | Grafana:3000 | profile `obs` |

Điểm quan trọng:
- Ảnh **không đi qua Traefik**: điện thoại `PUT`/`GET` thẳng tới URL ký sẵn của R2 (xem [04-service-specs.md](04-service-specs.md) §4.4). Middleware `ratelimit-files` trong `deploy/traefik/dynamic/middlewares.yml` còn lại từ thời MinIO, không router nào dùng.
- `KEYCLOAK_PUBLIC_URL` là `iss` trong JWT; service chỉ dùng JWKS nội bộ (`http://keycloak:8080/realms/animal-locket/protocol/openid-connect/certs`) nên không phụ thuộc hostname công khai.
- TLS: dev tự ký (cổng 443) hoặc dùng HTTP trên điện thoại. Production: bật Let's Encrypt (đoạn bình luận trong `traefik.yml`), chuyển hướng 80 → 443, đặt Docker socket sau `docker-socket-proxy`.
- `accessLog` bỏ qua mọi header (có `Authorization`, `X-Public-Id`).
- Windows: cổng 80 có thể bị chặn, đặt `HTTP_PORT=8080` và sửa `KEYCLOAK_PUBLIC_URL` theo.
- Điện thoại thật cùng Wi-Fi: đặt `PUBLIC_DOMAIN=192-168-1-20.nip.io` (IP máy) và `KEYCLOAK_PUBLIC_URL` tương ứng.

## 10.4 Dockerfile

- **`deploy/docker/Dockerfile.java`** dùng chung cho mọi module Spring Boot, build từ gốc repo với `--build-arg MODULE_PATH=services/user-service --build-arg APP_PORT=8101` (compose đã khai báo sẵn). Hai giai đoạn: `maven:3.9-eclipse-temurin-17` (`mvn -pl $MODULE_PATH -am -DskipTests package`, cache `~/.m2`) → `eclipse-temurin:17-jre`, chạy bằng user không phải root (uid 10001), `JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"`, `HEALTHCHECK` gọi `/actuator/health`, `exec java` để nhận SIGTERM (tắt êm).
- Image chưa ghim bằng digest; nên ghim và quét lỗ hổng (Trivy) trong CI.

## 10.5 Cơ sở dữ liệu và kho

| Thành phần | Cấu hình | Ghi chú |
|---|---|---|
| MySQL (ngoài, Aiven) | 3 schema `user_db`, `media_db`, `post_db` (`deploy/mysql/init.sql`); kết nối `sslMode=REQUIRED`, pool Hikari 5 | Production: user riêng cho từng schema |
| PostgreSQL (ngoài, Supabase) | billing (`BILLING_DB_URL`) và Keycloak (`KEYCLOAK_DB_URL`), `sslmode=require`; `deploy/supabase/init.sql` (chạy tay một lần) tạo hai role + hai schema `billing`, `keycloak`. `deploy/postgres/init.sql` dành cho PostgreSQL tự chạy, Compose hiện không dùng | Production: tách Keycloak |
| MongoDB (ngoài, Atlas) | `MONGO_URI`, DB `chat_db` | |
| Redis | `requirepass`, `appendonly yes`, **`maxmemory-policy noeviction`** (giữ hạn mức/vị trí; thà báo lỗi còn hơn lặng lẽ xoá) | Service nhận mật khẩu qua `SPRING_DATA_REDIS_PASSWORD` |
| Cloudflare R2 | **một** bucket private (`R2_BUCKET`); token chỉ cần *Object Read & Write* trên bucket đó | Không có lifecycle rule; `MediaJanitor` xoá job `PENDING_UPLOAD` quá 1 giờ. Chưa chạy thử với R2 thật |
| Kafka | KRaft một node, `replication-factor=1` (**dev**) | Production: ≥ 3 broker, RF 3, `min.insync.replicas=2` |
| Keycloak | realm `animal-locket` import từ `deploy/keycloak/animal-locket-realm.json`; client `mobile` (public, PKCE S256, redirect `com.animallocket.app:/oauth2redirect`), client `user-service-admin` (service account, dùng xoá user); đăng ký tự do, `verifyEmail=false`, brute-force protection, mật khẩu ≥ 10 ký tự, access token 10 phút | Xem dưới |

Về Keycloak: `verifyEmail=false` ở dev; production nên bật xác minh email/SĐT để giảm tài khoản rác. Quyền của `user-service-admin` phải giới hạn ở việc quản lý user (kiểm tra role trong realm file).

## 10.6 Bảng biến môi trường

### `.env` (Compose)

Danh sách đầy đủ và giá trị mẫu: `.env.example`.

| Biến | Mục đích | Ghi chú |
|---|---|---|
| `COMPOSE_PROJECT_NAME`, `COMPOSE_PROFILES` | Tên dự án; profile mặc định | `core,app` |
| `PUBLIC_DOMAIN`, `HTTP_PORT`, `HTTPS_PORT` | Host công khai và cổng Traefik | |
| `KEYCLOAK_PUBLIC_URL` | URL công khai Keycloak (`iss`) | |
| `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD` | MySQL ngoài | |
| `BILLING_DB_URL/USER/PASSWORD`, `KEYCLOAK_DB_URL/USER/PASSWORD` | PostgreSQL ngoài | |
| `MONGO_URI` | MongoDB ngoài | |
| `REDIS_PASSWORD` | Mật khẩu Redis | |
| `R2_ENDPOINT`, `R2_ACCESS_KEY`, `R2_SECRET_KEY`, `R2_BUCKET` | Kho ảnh Cloudflare R2 | bắt buộc khi chạy media-service |
| `JPA_DDL_AUTO` | `none` hoặc `validate` | mặc định `none`; xem 05 |
| `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`, `KEYCLOAK_ADMIN_CLIENT_SECRET` | Quản trị Keycloak; secret của `user-service-admin` | |
| `INTERNAL_TOKEN` | Khoá gọi nội bộ | ≥ 32 ký tự ngẫu nhiên |
| `DISCOVERY_SECRET` | Khoá offset vị trí | ≥ 32 ký tự; **đổi sẽ dịch toàn bộ vị trí đã lưu** |
| `CONFIG_USER`, `CONFIG_PASSWORD` | Basic auth Config Server | |
| `DEV_BUDDY_PUBLIC_ID` | Tài khoản dev tự là bạn của mọi người | **để trống ở production** |
| `FCM_CREDENTIALS_FILE` | Đường dẫn trong container, ví dụ `/secrets/fcm.json` | rỗng = chỉ ghi log |
| `BILLING_DEV_STORE` | Tin biên lai client | **`false` ở production** |
| `PAYPAL_*`, `PAYOS_*` | Thanh toán web | để trống = tắt |
| `GLYPH_WRITE_ENABLED`, `GLYPH_MAX_ACTIVE`, `GLYPH_MAX_CREATES_PER_DAY` | Hạn mức glyph chat | |
| `GRAFANA_ADMIN_USER/PASSWORD` | | |
| `TRACE_SAMPLING` | 0.0–1.0 | production 0.05–0.1 |
| `TRAEFIK_IMAGE`, `KEYCLOAK_IMAGE` | Phiên bản image | |

### Biến của từng service (Compose truyền vào)

| Service | Biến chính |
|---|---|
| Tất cả service Java | `CONFIG_SERVER_URL`, `CONFIG_USER/PASSWORD`, `EUREKA_URL`, `INTERNAL_TOKEN`, `KAFKA_BOOTSTRAP`, `KEYCLOAK_JWK_URI`, `OTLP_TRACING_ENDPOINT`, `TRACE_SAMPLING`, `JPA_DDL_AUTO`, `MANAGEMENT_METRICS_DISTRIBUTION_PERCENTILESHISTOGRAM_HTTP_SERVER_REQUESTS=true` |
| api-gateway, post, discovery, chat | `REDIS_HOST`, `REDIS_PORT`, `SPRING_DATA_REDIS_PASSWORD` |
| user, media, post | `DB_URL` (MySQL), `DB_USER`, `DB_PASSWORD` |
| user | `KEYCLOAK_ADMIN_URL`, `KEYCLOAK_ADMIN_CLIENT_ID`, `KEYCLOAK_ADMIN_CLIENT_SECRET`, `DEV_BUDDY_PUBLIC_ID` |
| media | `R2_ENDPOINT`, `R2_ACCESS_KEY`, `R2_SECRET_KEY`, `R2_BUCKET` |
| discovery | `DISCOVERY_SECRET` |
| chat | `MONGO_URI`, `GLYPH_WRITE_ENABLED`, `ANIMAL_CHAT_GLYPH_*` |
| billing | `DB_URL` (PostgreSQL), `DB_USER`, `DB_PASSWORD`, `BILLING_DEV_STORE`, `PAYPAL_*`, `PAYOS_*`; file khoá store ở `/secrets` |
| notification | `FCM_CREDENTIALS_FILE`; `/secrets` |

> Redis có `requirepass` nên mọi service dùng Redis phải nhận `SPRING_DATA_REDIS_PASSWORD`. Compose đã làm điều này cho gateway, post, discovery, chat.

## 10.7 Tài nguyên

Compose **chưa đặt `mem_limit`/`cpus`**; nên đặt khi lên máy chủ thật. Ước lượng thô (cần đo lại):

| Nhóm | RAM | Ghi chú |
|---|---|---|
| 10 JVM (gateway, config, eureka, 7 service) | ≈ 0.4–0.6 GB mỗi cái → 4–6 GB | `MaxRAMPercentage=75` nên đặt giới hạn container để heap có ý nghĩa |
| Redis + Kafka (một node) + Keycloak + Traefik | ≈ 2–3 GB | Keycloak ≈ 1 GB |
| Observability (profile `obs`) | ≈ 2 GB | Loki/Tempo/Prometheus tăng theo retention |
| **Tổng dev** | **16 GB tối thiểu, 24–32 GB thoải mái** | DB chạy ngoài nên không tính |

Máy nhỏ: chỉ `core` rồi chạy từng service bằng Maven (10.8); hoặc bật `app` mà không bật `obs`.

## 10.8 Chạy cục bộ không cần Docker

Cần tự có hạ tầng tương ứng (DB ngoài hoặc cài sẵn, Kafka/Redis/Keycloak chạy riêng từng container). Mỗi service có mặc định `localhost`.

```bash
# Ví dụ chỉ phát triển user-service + gateway
docker compose up -d kafka kafka-init keycloak redis      # tuỳ chọn: chỉ vài thành phần cần dùng
mvn -pl infra/eureka-server spring-boot:run &
mvn -pl services/user-service spring-boot:run &
mvn -pl infra/api-gateway spring-boot:run &
```

- Không cần Config Server (`optional:configserver:`); không cần Keycloak nếu đặt `--animal.security.enabled=false` (chỉ dev).
- **Test không cần hạ tầng**: toàn bộ test Java dùng H2/bộ nhớ ([12-testing-strategy.md](12-testing-strategy.md)).
- Cổng mặc định: gateway 8080, user 8101, post 8102, media 8103, discovery 8104, chat 8105, billing 8106, notification 8107; Keycloak 8081 (cấu hình mặc định của `KEYCLOAK_JWK_URI`) — khác cổng 8080 bên trong container.

## 10.9 Production: việc cần làm trước khi mở ra Internet

- [ ] Đổi **mọi** mật khẩu/khoá trong `.env` (tối thiểu 32 ký tự ngẫu nhiên cho `INTERNAL_TOKEN`, `DISCOVERY_SECRET`); không commit `.env`; dùng Vault/secret manager.
- [ ] TLS thật (Let's Encrypt), chuyển hướng HTTP → HTTPS, HSTS; `admin-only` đổi sang VPN/IP vận hành; Traefik dashboard không public.
- [ ] Đặt `mem_limit`, `cpus`, `restart`, giới hạn kích thước body ở Traefik; theo dõi `ExitOnOutOfMemoryError`.
- [ ] Kafka ≥ 3 broker, RF 3; `retention.ms` ngắn hợp lý (payload chứa `publicId`).
- [ ] DB: user riêng cho từng service, backup có mã hoá, kiểm thử khôi phục; Redis bật mật khẩu + `noeviction` (đã có); token R2 chỉ có quyền trên đúng bucket.
- [ ] Config Server dùng profile `git`; không để bí mật trong repo cấu hình.
- [ ] `JPA_DDL_AUTO=validate` sau khi đã kiểm chứng với MySQL thật.
- [ ] `BILLING_DEV_STORE=false`, `PAYPAL_MODE=live` chỉ trên server thật; `DEV_BUDDY_PUBLIC_ID` để trống; khoá App Store/Google Play đặt ở `deploy/secrets` (mount read-only).
- [ ] Giám sát + cảnh báo (profile `obs`, [11-observability-resilience.md](11-observability-resilience.md)); `TRACE_SAMPLING` 0.05–0.1.
- [ ] Nâng lên Kubernetes khi cần (Eureka/Config có thể bỏ khi dùng K8s service discovery/ConfigMap — đừng đầu tư quá sâu, như kế hoạch gốc đã nêu).

## 10.10 Quan sát trong Compose

Prometheus scrape: gateway và 7 service ở `/actuator/prometheus`, Traefik (`:8080`), kafka-exporter (`:9308`), Keycloak (`:9000/metrics`), Loki, Tempo. Config Server và Eureka **không** được scrape (chỉ `health,info`). `prometheus.yml` vẫn còn job `minio` (di sản, sẽ báo target down). Alloy gom log mọi container Docker vào Loki với nhãn `service` = tên service Compose. Dashboard Grafana: `service-overview`, `photo-pipeline` (dashboard ảnh dựa trên metric của face-worker cũ, phần lớn sẽ trống). Quy tắc cảnh báo ở `deploy/observability/prometheus/alerts.yml`: `ServiceDown`, `High5xxRate`, `HighLatencyP95`, `CircuitBreakerOpen`, `KafkaConsumerLagHigh`, `JvmHeapNearLimit`, `OutboxStuck`, `OutboxBacklogHigh` — xem [11-observability-resilience.md](11-observability-resilience.md).
