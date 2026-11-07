# 10. Triển khai và hạ tầng

Mô tả theo các file đã có: `docker-compose.yml`, `.env.example`, `Makefile`, `deploy/` (Traefik, Keycloak, MinIO, MySQL/PostgreSQL init, observability, `Dockerfile.java`) và `face-worker/Dockerfile`.

> **Trạng thái**: các file này **chưa được chạy thử** (chưa có Docker daemon khi viết). Mục 14.5 trong [14-roadmap-risks.md](14-roadmap-risks.md) là checklist kiểm tra lần đầu.

## 10.1 Tổng quan

- Docker Compose, một mạng nội bộ `animal-net`. **Chỉ Traefik publish cổng ra máy chủ** (80/443; dashboard ở `127.0.0.1:8088`). Mọi thành phần khác chỉ tồn tại trong mạng nội bộ.
- Bốn **profile** (bật dần theo tài nguyên):

| Profile | Thành phần |
|---|---|
| `core` | MySQL 8.4, PostgreSQL 16, MongoDB 7, Redis 7, MinIO (+ `minio-init`), Kafka 3.8 KRaft (+ `kafka-init`), Keycloak 26, Traefik v3 |
| `app` | eureka-server, config-server, api-gateway, user/media/post/notification/discovery/chat/billing-service, **face-worker (CPU, sticker)** |
| `ai` | `face-worker-gpu` (AI inpainting, cần NVIDIA GPU + NVIDIA Container Toolkit) + `hf-cache-init` |
| `obs` | Prometheus, kafka-exporter, Loki, Tempo, Alloy, Grafana |

`COMPOSE_PROFILES` trong `.env` mặc định `core,app`. Profile khác luôn cần `core` đi kèm.

```bash
cp .env.example .env        # rồi ĐỔI mọi mật khẩu/khoá (hoặc: make env)
docker compose up -d --build        # = core + app
make obs                    # thêm giám sát
make ai                     # thêm face-worker GPU và dừng worker CPU (cùng consumer group)
make check                  # docker compose config --quiet
make down | make reset      # reset XOÁ cả dữ liệu (chỉ dev)
```

## 10.2 Sơ đồ phụ thuộc khởi động

```
core: mysql ─┐   postgres ─► keycloak      kafka ─► kafka-init (tạo topic)      minio ─► minio-init (bucket, tài khoản app)
app : eureka-server ─► config-server ─► {api-gateway, user, media, post, notification, discovery, chat, billing}
      (mỗi service chờ DB/Redis/Kafka-init/MinIO-init tương ứng "healthy/completed")
      face-worker chờ kafka-init + minio-init
```

`kafka-init` tạo tường minh các topic với **3 phân vùng**: `user.events`, `friend.events`, `media.events`, `media.results`, `post.events`, `chat.events`, `billing.events`; `media.events.dlq` giữ 30 ngày. `KAFKA_AUTO_CREATE_TOPICS_ENABLE=false` nên gõ sai tên topic sẽ lỗi thay vì tạo nhầm.

## 10.3 Traefik và địa chỉ công khai

Host (với `PUBLIC_DOMAIN`, dev mặc định `localhost`):

| Host | Đích | Ghi chú |
|---|---|---|
| `api.<domain>` | api-gateway:8080 | REST + WebSocket `/ws/chat`; middleware `security-headers`, `ratelimit` (50 req/s/IP, burst 100) |
| `files.<domain>` | MinIO:9000 (S3) | upload/tải ảnh bằng URL ký sẵn; `ratelimit-files` (200/s); `/minio/*` bị chặn |
| `auth.<domain>` | Keycloak:8080 | đăng nhập OIDC; `/admin`, `/realms/master`, `/metrics`, `/health` **chỉ mạng nội bộ** (`admin-only`) |
| `grafana.<domain>` | Grafana:3000 | |
| `minio.<domain>` | MinIO console:9001 | `admin-only` |

Điểm quan trọng:
- **`MINIO_PUBLIC_ENDPOINT` phải khớp chính xác host (và cổng nếu khác 80/443) mà điện thoại truy cập**, vì chữ ký presigned URL gắn với header `Host`. media-service dùng `MINIO_ENDPOINT` (nội bộ, `http://minio:9000`) để thao tác và `MINIO_PUBLIC_ENDPOINT` (`http://files.localhost`) để **ký** URL.
- `KEYCLOAK_PUBLIC_URL` là `iss` trong JWT; service chỉ dùng JWKS nội bộ (`http://keycloak:8080/realms/animal-locket/protocol/openid-connect/certs`) nên không phụ thuộc hostname công khai.
- TLS: dev tự ký (cổng 443) hoặc dùng HTTP cổng 80 trên điện thoại. Production: bật Let's Encrypt (đoạn bình luận trong `traefik.yml`), chuyển hướng 80 → 443, đặt Docker socket sau `docker-socket-proxy`.
- `accessLog` bỏ qua mọi header (có `Authorization`, `X-Public-Id`).
- Điện thoại thật cùng Wi-Fi: đặt `PUBLIC_DOMAIN=192-168-1-20.nip.io` (IP máy) và `MINIO_PUBLIC_ENDPOINT`/`KEYCLOAK_PUBLIC_URL` tương ứng.

> **Cần siết**: router `api` hiện chuyển **mọi đường dẫn** tới gateway, bao gồm `/actuator/prometheus` và `/actuator/health` (gateway để `permitAll`). Nên thêm điều kiện `PathPrefix(`/api/`) || PathPrefix(`/ws/`) || PathPrefix(`/webhooks/`)` cho router `api`, hoặc router chặn `/actuator` như đã làm với MinIO/Keycloak. Xem threat T3 trong [09-privacy-safety-security.md](09-privacy-safety-security.md).

## 10.4 Dockerfile

- **`deploy/docker/Dockerfile.java`** dùng chung cho mọi module Spring Boot, build từ gốc repo với `--build-arg MODULE_PATH=services/user-service --build-arg APP_PORT=8101` (compose đã khai báo sẵn). Hai giai đoạn: `maven:3.9-eclipse-temurin-17` (`mvn -pl $MODULE_PATH -am -DskipTests package`, cache `~/.m2`) → `eclipse-temurin:17-jre`, chạy bằng user không phải root (uid 10001), `JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"`, `HEALTHCHECK` gọi `/actuator/health`, `exec java` để nhận SIGTERM (tắt êm).
- **`face-worker/Dockerfile`**: `ARG BASE=python:3.12-slim`, `ARG REQS=requirements.txt`; tải mô hình YuNet vào `/models` (nếu không tải được thì chỉ dùng Haar); user `worker`; `HEALTHCHECK` `curl http://localhost:8110/`. Bản GPU: `BASE=nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04`, `REQS=requirements-ai.txt`.
- Image chưa ghim bằng digest; nên ghim và quét lỗ hổng (Trivy) trong CI.

## 10.5 Cơ sở dữ liệu và kho

| Thành phần | Cấu hình | Ghi chú |
|---|---|---|
| MySQL | 3 schema `user_db`, `media_db`, `post_db`, một user `animal` (`deploy/mysql/init.sql`) | Production: user riêng cho từng schema hoặc tách instance |
| PostgreSQL | `billing_db` (tạo bởi image) + `keycloak_db` (`init.sql`) | Production: tách Keycloak |
| MongoDB | user `animal`, auth DB `admin`, DB `chat_db` | |
| Redis | `requirepass`, `appendonly yes`, **`maxmemory-policy noeviction`** (giữ hạn mức/vị trí; thà báo lỗi còn hơn lặng lẽ xoá) | Service nhận mật khẩu qua `SPRING_DATA_REDIS_PASSWORD` |
| MinIO | `minio-init` tạo bucket `raw`, `public` (anonymous = none), tài khoản `MINIO_ACCESS_KEY` với policy chỉ trên hai bucket (`deploy/minio/app-policy.json`), lifecycle `raw` xoá sau 1 ngày (lớp phòng thủ phụ; `MediaJanitor` xoá ảnh gốc > 1 giờ) | |
| Kafka | KRaft một node, `replication-factor=1` (**dev**) | Production: ≥ 3 broker, RF 3, `min.insync.replicas=2` |
| Keycloak | realm `animal-locket` import từ `deploy/keycloak/animal-locket-realm.json`; client `mobile` (public, PKCE S256, redirect `com.animallocket.app:/oauth2redirect`), client `user-service-admin` (service account, dùng xoá user); đăng ký tự do, `verifyEmail=false`, brute-force protection, mật khẩu ≥ 10 ký tự, access token 10 phút | Xem dưới |

Về Keycloak: `verifyEmail=false` ở dev; production nên bật xác minh email/SĐT để giảm tài khoản rác. Quyền của `user-service-admin` phải giới hạn ở việc quản lý user (kiểm tra role trong realm file).

## 10.6 Bảng biến môi trường

### `.env` (Compose)

| Biến | Mục đích | Ghi chú |
|---|---|---|
| `COMPOSE_PROJECT_NAME`, `COMPOSE_PROFILES` | Tên dự án; profile mặc định | `core,app` |
| `PUBLIC_DOMAIN`, `HTTP_PORT`, `HTTPS_PORT` | Host công khai và cổng Traefik | |
| `MINIO_PUBLIC_ENDPOINT` | URL điện thoại dùng cho MinIO | phải khớp host+cổng |
| `KEYCLOAK_PUBLIC_URL` | URL công khai Keycloak (`iss`) | |
| `MYSQL_ROOT_PASSWORD`, `MYSQL_APP_PASSWORD`, `POSTGRES_PASSWORD`, `MONGO_PASSWORD`, `REDIS_PASSWORD` | Mật khẩu DB | chỉ chữ và số (vào chuỗi kết nối) |
| `JPA_DDL_AUTO` | `none` hoặc `validate` | mặc định `none`; xem 05 |
| `MINIO_ROOT_USER/PASSWORD`, `MINIO_ACCESS_KEY/SECRET_KEY` | Quản trị MinIO; tài khoản ứng dụng | |
| `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`, `KEYCLOAK_ADMIN_CLIENT_SECRET` | Quản trị Keycloak; secret của `user-service-admin` | |
| `INTERNAL_TOKEN` | Khoá gọi nội bộ | ≥ 32 ký tự ngẫu nhiên |
| `DISCOVERY_SECRET` | Khoá offset vị trí | ≥ 32 ký tự; **đổi sẽ dịch toàn bộ vị trí đã lưu** |
| `CONFIG_USER`, `CONFIG_PASSWORD` | Basic auth Config Server | |
| `FCM_CREDENTIALS_FILE` | Đường dẫn trong container, ví dụ `/secrets/fcm.json` | rỗng = chỉ ghi log |
| `BILLING_DEV_STORE` | Tin biên lai client | **`false` ở production** |
| `GRAFANA_ADMIN_USER/PASSWORD` | | |
| `TRACE_SAMPLING` | 0.0–1.0 | production 0.05–0.1 |
| `*_IMAGE` | Phiên bản image Traefik/MinIO/mc/Keycloak | |

### Biến của từng service (Compose truyền vào)

| Service | Biến chính |
|---|---|
| Tất cả service Java | `CONFIG_SERVER_URL`, `CONFIG_USER/PASSWORD`, `EUREKA_URL`, `INTERNAL_TOKEN`, `KAFKA_BOOTSTRAP`, `KEYCLOAK_JWK_URI`, `OTLP_TRACING_ENDPOINT`, `TRACE_SAMPLING`, `JPA_DDL_AUTO`, `MANAGEMENT_METRICS_DISTRIBUTION_PERCENTILESHISTOGRAM_HTTP_SERVER_REQUESTS=true` |
| api-gateway, post, discovery, chat | `REDIS_HOST`, `REDIS_PORT`, `SPRING_DATA_REDIS_PASSWORD` |
| user, media, post | `DB_URL` (MySQL), `DB_USER`, `DB_PASSWORD` |
| user | `KEYCLOAK_ADMIN_URL`, `KEYCLOAK_ADMIN_CLIENT_ID`, `KEYCLOAK_ADMIN_CLIENT_SECRET` |
| media | `MINIO_ENDPOINT`, `MINIO_PUBLIC_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY` |
| discovery | `DISCOVERY_SECRET` |
| chat | `MONGO_URI` |
| billing | `DB_URL` (PostgreSQL), `DB_USER`, `DB_PASSWORD`, `BILLING_DEV_STORE`; file khoá store ở `/secrets` |
| notification | `FCM_CREDENTIALS_FILE`; `/secrets` |
| face-worker | `KAFKA_BOOTSTRAP`, `MINIO_ENDPOINT`, `MINIO_SECURE`, `MINIO_ACCESS_KEY/SECRET_KEY`, `AI_ENABLED`, `HTTP_PORT`, (GPU: `HF_HOME`) — danh sách đầy đủ ở [08-face-anonymization-pipeline.md](08-face-anonymization-pipeline.md) |

> Redis có `requirepass` nên mọi service dùng Redis phải nhận `SPRING_DATA_REDIS_PASSWORD`. Compose đã làm điều này cho gateway, post, discovery, chat.

## 10.7 Tài nguyên

Compose **chưa đặt `mem_limit`/`cpus`**; nên đặt khi lên máy chủ thật. Ước lượng thô (cần đo lại):

| Nhóm | RAM | Ghi chú |
|---|---|---|
| 10 JVM (gateway, config, eureka, 7 service) | ≈ 0.4–0.6 GB mỗi cái → 4–6 GB | `MaxRAMPercentage=75` nên đặt giới hạn container để heap có ý nghĩa |
| MySQL + PostgreSQL + MongoDB + Redis | ≈ 2–3 GB | |
| Kafka (một node) + Keycloak + MinIO + Traefik | ≈ 2–3 GB | Keycloak ≈ 1 GB |
| face-worker CPU | ≈ 0.5–1 GB (OpenCV + Pillow) | |
| Observability (profile `obs`) | ≈ 2 GB | Loki/Tempo/Prometheus tăng theo retention |
| **Tổng dev** | **16 GB tối thiểu, 24–32 GB thoải mái** (đúng kế hoạch) | |
| face-worker GPU | 8–12 GB VRAM + ≈ 8 GB RAM; lần đầu tải mô hình vài GB vào volume `hf-cache` | cần Internet lần đầu |

Máy nhỏ: chỉ `core` rồi chạy từng service bằng Maven (10.8); hoặc bật `app` mà không bật `obs`.

## 10.8 Chạy cục bộ không cần Docker

Cần tự chạy hạ tầng tương ứng (cài sẵn hoặc chỉ chạy riêng từng container). Mỗi service có mặc định `localhost`.

```bash
# Ví dụ chỉ phát triển user-service + gateway
docker compose up -d mysql kafka kafka-init keycloak redis      # tuỳ chọn: chỉ vài thành phần cần dùng
mvn -pl infra/eureka-server spring-boot:run &
mvn -pl services/user-service spring-boot:run &
mvn -pl infra/api-gateway spring-boot:run &
```

- Không cần Config Server (`optional:configserver:`); không cần Keycloak nếu đặt `--animal.security.enabled=false` (chỉ dev).
- **Test không cần hạ tầng**: toàn bộ test Java dùng H2/bộ nhớ ([12-testing-strategy.md](12-testing-strategy.md)); face-worker `pytest` không cần Kafka/MinIO.
- Cổng mặc định: gateway 8080, user 8101, post 8102, media 8103, discovery 8104, chat 8105, billing 8106, notification 8107; Keycloak 8081 (cấu hình mặc định của `KEYCLOAK_JWK_URI`) — khác cổng 8080 bên trong container.

## 10.9 Production: việc cần làm trước khi mở ra Internet

- [ ] Đổi **mọi** mật khẩu/khoá trong `.env` (tối thiểu 32 ký tự ngẫu nhiên cho `INTERNAL_TOKEN`, `DISCOVERY_SECRET`); không commit `.env`; dùng Vault/secret manager.
- [ ] TLS thật (Let's Encrypt), chuyển hướng HTTP → HTTPS, HSTS; `admin-only` đổi sang VPN/IP vận hành; Traefik dashboard không public.
- [ ] Chặn `/actuator/*` ở router `api` (xem 10.3); chỉ Prometheus truy cập metrics qua mạng nội bộ.
- [ ] Đặt `mem_limit`, `cpus`, `restart`, giới hạn kích thước body ở Traefik; theo dõi `ExitOnOutOfMemoryError`.
- [ ] Kafka ≥ 3 broker, RF 3; `retention.ms` ngắn hợp lý (payload chứa `publicId`).
- [ ] DB: user riêng cho từng service, backup có mã hoá, kiểm thử khôi phục; Redis bật mật khẩu + `noeviction` (đã có); MinIO tài khoản riêng theo bucket, **không** sao lưu bucket `raw`.
- [ ] Config Server dùng profile `git`; không để bí mật trong repo cấu hình.
- [ ] `JPA_DDL_AUTO=validate` sau khi đã kiểm chứng với MySQL thật.
- [ ] `BILLING_DEV_STORE=false` (xác nhận khi khởi động); khoá App Store/Google Play đặt ở `deploy/secrets` (mount read-only).
- [ ] Giám sát + cảnh báo (profile `obs`, [11-observability-resilience.md](11-observability-resilience.md)); `TRACE_SAMPLING` 0.05–0.1.
- [ ] Face-worker: bắt buộc có YuNet (kiểm tra log "Detector: ['haar', 'yunet']"); bộ ảnh đánh giá đạt miss rate < 1%; quyết định AI hay sticker cho từng nhóm người dùng.
- [ ] Nâng lên Kubernetes khi cần (Eureka/Config có thể bỏ khi dùng K8s service discovery/ConfigMap — đừng đầu tư quá sâu, như kế hoạch gốc đã nêu).

## 10.10 Quan sát trong Compose

Prometheus scrape: gateway và 7 service ở `/actuator/prometheus`, face-worker (`face-worker:8110` nhãn `variant=cpu`, `face-worker-gpu:8110` nhãn `variant=gpu`), Traefik (`:8080`), kafka-exporter (`:9308`), Keycloak (`:9000/metrics`), MinIO (`/minio/v2/metrics/cluster`), Loki, Tempo. Config Server và Eureka **không** được scrape (chỉ `health,info`). Alloy gom log mọi container Docker vào Loki với nhãn `service` = tên service Compose. Dashboard Grafana: `service-overview`, `photo-pipeline`. Quy tắc cảnh báo ở `deploy/observability/prometheus/alerts.yml` (ServiceDown, FaceWorkerAllDown, High5xxRate, HighLatencyP95, CircuitBreakerOpen, KafkaConsumerLagHigh, DeadLetterTopicGrowing, FaceWorkerFailureRateHigh, PhotoProcessingSlow, PhotoStickerFallbackHigh, FaceWorkerRetriesHigh, JvmHeapNearLimit) — xem [11-observability-resilience.md](11-observability-resilience.md).
