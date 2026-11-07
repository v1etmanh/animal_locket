# Animal Locket

Ứng dụng chia sẻ ảnh nhanh giữa bạn bè (kiểu Locket) nhưng **ẩn danh hoàn toàn**: mọi khuôn mặt trong ảnh bị thay bằng mặt con vật, kết bạn bằng cách quẹt thẻ người lân cận/đang online.

Tài liệu đầy đủ: [docs/README.md](docs/README.md) (kế hoạch kiến trúc gốc: [docs/ARCHITECTURE_PLAN.md](docs/ARCHITECTURE_PLAN.md)).

## Cấu trúc

```
libs/common          event envelope, KeyValueStore, lỗi RFC 7807, bảo mật dùng chung
libs/outbox-jpa      Outbox pattern + khử trùng lặp event cho service dùng JPA
infra/config-server  Spring Cloud Config (đọc infra/config-repo)
infra/eureka-server  service discovery
infra/api-gateway    JWT, gắn X-Public-Id, circuit breaker, rate limit
services/            user · media · post · notification · discovery · chat · billing
deploy/, docker-compose.yml   hạ tầng chạy bằng Docker Compose (xem deploy/README.md)
```

## Yêu cầu

JDK 17, Maven 3.9, Python 3.12. Docker chỉ cần khi chạy cả hệ thống bằng Compose; **toàn bộ test chạy không cần Docker** (H2 / bộ nhớ).

## Build và test

```bash
mvn -B install
```

Bộ test dùng hạ tầng thật (Redis, MongoDB) được bỏ qua tự động khi thiếu Docker/biến môi trường:

| Test | Điều kiện chạy |
|---|---|
| `RedisDiscoveryStoreTest` | đặt `REDIS_TEST_HOST` (ví dụ `docker run -p 6379:6379 redis:7`) |
| `ChatMongoIntegrationTest` | cần Docker (Testcontainers) |

## Chạy cả hệ thống

```bash
cp .env.example .env        # đổi mọi giá trị mật trước khi dùng thật
docker compose --profile core up -d
docker compose --profile app up -d --build
```

Chi tiết các profile (`core`, `app`, `obs`) ở [deploy/README.md](deploy/README.md).

## Nguyên tắc bắt buộc khi viết code

1. DTO trả ra ngoài **chỉ** chứa `publicId`, alias, con vật. Không bao giờ có `sub` Keycloak, email, ngày sinh, toạ độ.
2. Danh tính người gọi lấy từ header `X-Public-Id` do **gateway** gắn. Endpoint `/internal/**` chỉ nhận request có `X-Internal-Token`.
3. Event đi qua Outbox (cùng transaction với dữ liệu), consumer phải idempotent theo `eventId`.
4. Thanh toán, xác thực, ẩn mặt, vị trí: **fail closed**. Feed, thông báo, gợi ý: **fail soft**.
5. Ảnh upload xong là được đăng ngay (không còn bước ẩn mặt bằng AI).

## Trạng thái

Đã có code và test cho mọi service. **Chưa kiểm chứng** với hạ tầng thật: MySQL/PostgreSQL/Kafka/R2/Keycloak, Docker Compose, và xác thực biên lai thật với Apple/Google. Danh sách đầy đủ ở [docs/14-roadmap-risks.md](docs/14-roadmap-risks.md).

Client mobile chưa nằm trong repo này (API đã sẵn sàng cho client).
