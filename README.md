# Animal Locket

Ứng dụng chia sẻ ảnh nhanh giữa bạn bè (kiểu Locket) với danh tính **ẩn danh**: mỗi người hiện ra bằng alias và một avatar con vật **duy nhất** (không ai trùng), kết bạn bằng cách quẹt thẻ người lân cận/đang online. Ảnh được đăng **nguyên bản** (không còn ẩn mặt), chỉ bạn bè xem được; app tự xoá EXIF/GPS trước khi upload.

Tài liệu đầy đủ: [docs/README.md](docs/README.md) (kế hoạch kiến trúc gốc: [docs/ARCHITECTURE_PLAN.md](docs/ARCHITECTURE_PLAN.md)).

## Cấu trúc

```
libs/common          event envelope, KeyValueStore, lỗi RFC 7807, bảo mật dùng chung, DLQ Kafka
libs/outbox-jpa      Outbox pattern + khử trùng lặp event cho service dùng JPA
libs/avatar-lib      build-lib.mjs sinh thư viện avatar con vật (docs/19)
infra/config-server  Spring Cloud Config (đọc infra/config-repo)
infra/eureka-server  service discovery
infra/api-gateway    JWT, gắn X-Public-Id, circuit breaker, rate limit
services/            user · media · post · notification · discovery · chat · billing
mobile/              app Flutter
deploy/, docker-compose.yml   hạ tầng chạy bằng Docker Compose (xem deploy/README.md)
```

## Yêu cầu

JDK 17, Maven 3.9. Flutter SDK nếu làm `mobile/`; Node.js nếu sinh lại thư viện avatar. Docker chỉ cần khi chạy cả hệ thống bằng Compose; **toàn bộ test Java chạy không cần Docker** (H2 / bộ nhớ).

## Build và test

```bash
mvn -B install
cd mobile && flutter test     # app mobile
```

Bộ test dùng hạ tầng thật được bỏ qua tự động khi thiếu Docker/biến môi trường:

| Test | Điều kiện chạy |
|---|---|
| `RedisDiscoveryStoreTest` | đặt `REDIS_TEST_HOST` (ví dụ `docker run -p 6379:6379 redis:7`) |
| `ChatMongoIntegrationTest`, `GlyphMongoIntegrationTest` | cần Docker (Testcontainers) |
| `S3ObjectStorageLiveTest` | đặt `R2_ENDPOINT` (+ `R2_ACCESS_KEY`, `R2_SECRET_KEY`, `R2_BUCKET`) |

## Chạy cả hệ thống

DB là dịch vụ ngoài (MySQL, PostgreSQL, MongoDB) và ảnh nằm trên Cloudflare R2; điền thông tin kết nối vào `.env`.

```bash
cp .env.example .env        # điền DB/R2 và đổi mọi giá trị mật trước khi dùng thật
docker compose --profile core up -d
docker compose --profile core --profile app up -d --build
```

Chi tiết các profile (`core`, `app`, `obs`) ở [deploy/README.md](deploy/README.md).

## Nguyên tắc bắt buộc khi viết code

1. DTO trả ra ngoài **chỉ** chứa `publicId`, alias, con vật/avatar. Không bao giờ có `sub` Keycloak, email, ngày sinh, toạ độ.
2. Danh tính người gọi lấy từ header `X-Public-Id` do **gateway** gắn. Endpoint `/internal/**` chỉ nhận request có `X-Internal-Token`.
3. Event đi qua Outbox (cùng transaction với dữ liệu), consumer phải idempotent theo `eventId`.
4. Thanh toán, xác thực, quan hệ bạn bè (xem ảnh, chat), vị trí: **fail closed**. Feed, thông báo, gợi ý: **fail soft**.
5. Ảnh upload xong (`complete` kiểm tra cỡ và `Content-Type`) là được đăng ngay; không có bước ẩn mặt (xem ADR-014 trong [docs/15-adr.md](docs/15-adr.md)).

## Trạng thái

Đã có code và test cho mọi service và app mobile. **Chưa kiểm chứng** với hạ tầng thật: MySQL/PostgreSQL/Kafka/R2/Keycloak, Docker Compose sau khi chuyển sang R2 + DB ngoài, và xác thực biên lai thật với Apple/Google. Danh sách đầy đủ ở [docs/14-roadmap-risks.md](docs/14-roadmap-risks.md).
