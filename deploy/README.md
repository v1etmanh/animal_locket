# Triển khai Animal Locket bằng Docker Compose

> **Trạng thái kiểm chứng:** bộ file này mới được kiểm tra **tĩnh** (cú pháp YAML/JSON, tham chiếu `depends_on`, biến môi trường,
> cổng, file mount, khớp với `application.yml` của từng service). **Chưa được chạy thật với Docker.** Xem mục
> [Chưa kiểm chứng](#chưa-kiểm-chứng-với-docker-thật) trước khi tin vào bất cứ điều gì ở đây.

## 1. Cấu trúc

| Đường dẫn | Nội dung |
|---|---|
| `docker-compose.yml` | Toàn bộ stack, chia theo profile |
| `.env.example` | Biến môi trường mẫu (sao chép thành `.env`, **đổi mật khẩu**) |
| `deploy/docker/Dockerfile.java` | Dockerfile dùng chung cho mọi service Java (`MODULE_PATH`, `APP_PORT`) |
| `deploy/traefik/` | Cấu hình tĩnh + middleware + TLS của Traefik |
| `deploy/keycloak/animal-locket-realm.json` | Realm `animal-locket` (import khi Keycloak khởi động lần đầu) |
| `deploy/mysql/init.sql`, `deploy/supabase/init.sql` | Tạo schema/role trên DB ngoài (chạy tay một lần). `deploy/postgres/init.sql` dành cho PostgreSQL tự chạy, Compose hiện không dùng |
| `deploy/observability/` | Prometheus (+ luật cảnh báo), Loki, Tempo, Alloy, Grafana (datasource + 2 dashboard) |
| `deploy/secrets/` | Nơi đặt khoá FCM, `.p8` của Apple, service account Google. **Không commit** (đã nằm trong `.gitignore`) |

## 2. Profile

| Profile | Gồm | Ghi chú |
|---|---|---|
| `core` | Redis, Kafka (+`kafka-init`), Keycloak, Traefik | Luôn cần. MySQL (Aiven), PostgreSQL (Supabase), MongoDB (Atlas) là **dịch vụ ngoài**, nối qua `.env` |
| `app` | eureka, config-server, api-gateway, user/media/post/notification/discovery/chat/billing | Cần `core` |
| `obs` | Prometheus, Loki, Tempo, Alloy, Grafana, kafka-exporter | Tuỳ chọn |

`.env.example` đặt sẵn `COMPOSE_PROFILES=core,app` nên `docker compose up -d` là đủ cho dev thông thường.

## 3. Chạy lần đầu

```bash
cp .env.example .env            # rồi MỞ .env VÀ ĐỔI MẬT KHẨU
docker compose --profile core up -d            # 1) hạ tầng; chờ keycloak healthy (~1–2 phút lần đầu)
docker compose --profile core --profile app up -d --build   # 2) service (build Maven lần đầu mất vài phút)
docker compose --profile core --profile obs up -d           # 3) (tuỳ chọn) giám sát
```

Máy cấu hình thấp: dựng dần (core → vài service) thay vì cả stack. Khuyến nghị **tối thiểu 16 GB RAM**, 24–32 GB thì thoải mái.

Dùng `make` nếu có: `make env`, `make core`, `make up`, `make obs`, `make logs S=user-service`.

### Địa chỉ (qua Traefik)

| URL (mặc định `PUBLIC_DOMAIN=localhost`) | Dịch vụ |
|---|---|
| `http://api.localhost` | API gateway (REST + WebSocket `/ws/chat`) |
| `http://auth.localhost` | Keycloak (đăng nhập). `/admin` và `realm master` **chỉ** mạng nội bộ |
| `http://grafana.localhost` | Grafana (profile `obs`) |
| `http://127.0.0.1:8088` | Dashboard Traefik, chỉ loopback |

`*.localhost` tự trỏ về 127.0.0.1 trên trình duyệt hiện đại; nếu `curl`/máy của bạn không phân giải được, thêm vào file hosts:
`127.0.0.1 api.localhost auth.localhost grafana.localhost`.

## 4. Kho ảnh: Cloudflare R2

Ảnh nằm trong **một bucket riêng tư** trên Cloudflare R2. Điện thoại **upload thẳng** vào R2 bằng URL `PUT` do `media-service` ký
(R2 không hỗ trợ presigned POST) và **xem** ảnh qua URL `GET` ngắn hạn. Không cần Traefik/MinIO ở giữa nên không còn chuyện
chữ ký gắn với host nội bộ.

Cần các biến trong `.env`: `R2_ENDPOINT` (`https://<account-id>.r2.cloudflarestorage.com`), `R2_ACCESS_KEY`, `R2_SECRET_KEY`,
`R2_BUCKET`. Token R2 chỉ cần quyền *Object Read & Write* trên đúng bucket đó. Chưa kiểm chứng với R2 thật.

## 5. Face-worker (đã gỡ)

face-worker đã bị gỡ khỏi repo. Khi client báo upload xong (`complete`), media-service kiểm tra cỡ và `Content-Type` của object trên R2 rồi đánh dấu `READY` và phát `PHOTO_READY`; không sao chép object, không che mặt. Xem ADR-014 trong [docs/15-adr.md](../docs/15-adr.md).

## 6. Quan sát

Grafana (`grafana.localhost`, tài khoản trong `.env`) có sẵn thư mục **Animal Locket** với 2 dashboard:
*Tổng quan service (RED)* và *Pipeline ẩn mặt* (dựa trên metric `facework_*` của face-worker đã gỡ nên sẽ trống). Trace → log: từ một span nhảy sang log của đúng service lọc theo `traceId`
(dựa trên mẫu log `[tên-service,traceId,spanId]` trong `infra/config-repo/application.yml`).

Khi **không** bật profile `obs`, các service vẫn cố gửi trace tới `tempo:4318` và ghi cảnh báo lỗi kết nối; đặt `TRACE_SAMPLING=0` để yên log.

Cảnh báo (`deploy/observability/prometheus/alerts.yml`): service down, 5xx cao, p95 chậm, circuit breaker mở, lag Kafka,
heap JVM, outbox kẹt (`OutboxStuck`) và tồn đọng (`OutboxBacklogHigh`) dựa trên metric `outbox_*` của `libs/outbox-jpa`.
`prometheus.yml` còn job `minio` (di sản, target sẽ down). Prometheus chưa gắn Alertmanager:
luật chỉ hiện ở UI Prometheus/Grafana; nối kênh thông báo (Slack/email) là bước riêng.

## 7. Checklist trước khi lên production

- [ ] Đổi **mọi** giá trị `CHANGE_ME_*` trong `.env`; sinh ngẫu nhiên ≥ 32 ký tự cho `INTERNAL_TOKEN`, `DISCOVERY_SECRET`. Lưu bí mật trong Vault/secret manager, không để file `.env` trên đĩa dùng chung.
- [ ] `DISCOVERY_SECRET` giữ cố định (đổi sẽ dịch chuyển toàn bộ vị trí đã lưu) và bí mật tuyệt đối: lộ khoá là phá được lớp làm nhiễu vị trí.
- [ ] `BILLING_DEV_STORE=false` (bắt buộc). Cấu hình khoá Apple/Google trong `deploy/secrets/` và kiểm thử webhook với môi trường sandbox.
- [ ] TLS thật: bật `certificatesResolvers` (Let's Encrypt) trong `traefik.yml`, chuyển entrypoint `web` sang redirect HTTPS, thêm `tls.certresolver` vào router. Keycloak URL chuyển sang `https://`.
- [ ] Keycloak: bật `verifyEmail` + cấu hình SMTP, đổi `sslRequired` theo môi trường, bỏ tài khoản admin bootstrap sau khi tạo admin thật, đặt `KC_HOSTNAME` HTTPS; chạy ở chế độ `start --optimized` với image đã build sẵn.
- [ ] Hạn chế `admin-only` (hiện cho phép mọi dải IP riêng tư) xuống VPN/IP cố định của đội vận hành; bỏ publish dashboard Traefik hoặc đặt sau xác thực.
- [ ] Không mount trực tiếp Docker socket vào Traefik/Alloy: dùng `docker-socket-proxy` chỉ đọc (hoặc chuyển sang Kubernetes).
- [ ] Tách tài khoản DB: mỗi service một user chỉ có quyền trên schema của mình; tách Keycloak sang instance PostgreSQL riêng; bật replication/backup + thử khôi phục.
- [ ] R2: token chỉ có quyền trên đúng bucket; bucket không bật public access; cân nhắc lifecycle/backup theo chính sách lưu ảnh.
- [ ] `DEV_BUDDY_PUBLIC_ID` để trống (tài khoản dev tự là bạn của mọi người).
- [ ] Kafka: ≥ 3 broker, `replication.factor=3`, `min.insync.replicas=2`; thêm xác thực/ACL.
- [ ] Redis: đặt persistence phù hợp; vì chứa hạn mức/vị trí nên cân nhắc replica/Sentinel.
- [ ] Ghim phiên bản image bằng digest/tag cố định (đặc biệt `TRAEFIK_IMAGE=traefik:v3`, hiện là tag trôi).
- [ ] Đặt giới hạn tài nguyên (`mem_limit`/`cpus`) cho từng container; kích hoạt `restart` hợp lý và probe thật ở orchestrator.
- [ ] Giảm `TRACE_SAMPLING` (0.05–0.1) và bật alert đến Slack/PagerDuty.
- [ ] Chạy thử xoá tài khoản end-to-end (xoá ở user-service → event → mọi service dọn dữ liệu → xoá user trong Keycloak).

## 8. Xử lý sự cố

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| Service Java thoát ngay với `Schema-validation: wrong column type ... expecting [enum ...]` | `JPA_DDL_AUTO=validate` với Hibernate 6.5 + MySQL (cột enum lưu `VARCHAR`) | Đặt `JPA_DDL_AUTO=none` (mặc định) |
| Keycloak không khởi động, log nói về `${KEYCLOAK_ADMIN_CLIENT_SECRET}` | Phiên bản không thay biến môi trường trong file realm | Sửa `secret` trực tiếp trong `animal-locket-realm.json` (chỉ cho dev) hoặc đặt secret trong console sau khi import |
| Traefik log: `client version 1.24 is too old` | Docker Engine mới yêu cầu API cao hơn bản Traefik cũ | Dùng `TRAEFIK_IMAGE=traefik:v3` mới nhất (≥ 3.6) |
| Service chờ mãi ở `waiting` | `kafka-init` chưa xong | `docker compose logs kafka-init` |

## 9. Chưa kiểm chứng với Docker thật

Những điểm dưới đây được viết theo tài liệu/kinh nghiệm nhưng **chưa ai chạy thử**:

1. Toàn bộ `docker compose up` (chưa có lần chạy nào, kể cả `docker compose config`). Thứ tự khởi động, healthcheck, thời gian `start_period`.
2. Tag image: `apache/kafka:3.8.0`, `traefik:v3`, `quay.io/keycloak/keycloak:26.0`, `grafana/alloy:v1.4.3`, `danielqsj/kafka-exporter:v1.8.0` — hãy `docker compose pull` để xác nhận.
3. Keycloak: thay `${KEYCLOAK_ADMIN_CLIENT_SECRET}` trong file realm lúc import; healthcheck cổng quản lý 9000; claim `sub` có trong token với scope mặc định; service account có đủ quyền `manage-users` để xoá user.
4. Traefik: một router gắn cả `web` và `websecure` (TLS bật ở entrypoint) hoạt động đúng; WebSocket qua gateway; cặp router `auth`/`auth-admin` ưu tiên đúng.
5. R2: upload `PUT` bằng URL ký sẵn, `statObject`, Content-Type lưu đúng.
6. Biến `MANAGEMENT_METRICS_DISTRIBUTION_PERCENTILESHISTOGRAM_HTTP_SERVER_REQUESTS` có bật được histogram hay không (nếu không, chỉ panel/alert p95 của API rỗng; phần còn lại vẫn chạy).
7. Metric `resilience4j_circuitbreaker_state` có được xuất hay không (nếu không, cảnh báo `CircuitBreakerOpen` im lặng).
9. Flyway chạy migration trên MySQL/PostgreSQL thật (mới được test bằng H2).
