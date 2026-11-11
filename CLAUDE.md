# Animal Locket — hướng dẫn cho Claude Code

Monorepo microservice (Java 17 / Spring Boot 3.3 / Spring Cloud 2023.0) + một worker Python. Tài liệu ở `docs/` (tiếng Việt).

## Lệnh thường dùng

- Build + test tất cả Java: `mvn -B install` (một module: `mvn -q -B -pl services/user-service install`)
- Không còn face-worker; ảnh upload xong thì media-service chuyển thẳng raw→public và phát `PHOTO_READY`. EXIF/GPS do client xoá (`ImagePreparationService`, `keepExif: false`), server không kiểm tra.
- Kết quả test nằm ở `<module>/target/surefire-reports/*.txt` (dùng `mvn -q` sẽ không in gì khi thành công)
- Maven thỉnh thoảng lỗi `Could not transfer artifact ... Premature end of Content-Length`: chạy lại.

## Quy ước

- Package gốc `com.animallocket.<service>`; mỗi service có `domain/ repo/ service/ web/ dto/`.
- Định danh người dùng giữa các service luôn là `publicId` (20 ký tự `[a-z2-7]`), tham chiếu bằng chuỗi, **không FK chéo DB**.
- Controller đọc người gọi bằng `@RequestHeader(Headers.PUBLIC_ID)`; thiếu header = `PROFILE_REQUIRED` (403).
- Lỗi nghiệp vụ: ném `ApiException` (mã `code` ổn định) → RFC 7807.
- Event: `outbox.publish(topic, type, key, payload)` trong transaction; consumer gọi `idempotency.firstTime(eventId)`.
- Service không dùng JPA (discovery, chat, notification) phát/nhận Kafka trực tiếp, thao tác phải idempotent.
- Migration Flyway ở `src/main/resources/db/migration`; test dùng H2 `create-drop` nên **entity khớp SQL không được test bắt** — đổi entity thì sửa SQL.
- Mọi cấu hình bí mật qua biến môi trường; không commit `.env`.
- Avatar (docs/19): mỗi avatar thuộc tối đa một người, cấp qua `AvatarAllocator` (UPDATE có điều kiện trên `avatar_pool`). Thư viện sửa ở `libs/avatar-lib/lib-vN.mjs` rồi `node libs/avatar-lib/build-lib.mjs` và `node libs/avatar-lib/check.mjs`; file phiên bản đã phát hành không được đổi một byte; phiên bản mới được vẽ lại hình nhưng phải giữ đủ bộ khoá cũ (ADR-015); app vẽ mọi mã bằng thư viện mới nhất có khoá đó.

## Cạm bẫy đã gặp

- OpenCV phải ghim `<5` (5.x bỏ Haar cascade).
- `@Transactional` không chạy khi gọi qua `this`: tách bean (xem `PurchaseFlow` → `BillingService`).
- Test dùng chung DB/kho key-value trong một Spring context: dọn dữ liệu ở `@BeforeEach`.
- So sánh thời gian với Mongo: độ phân giải mili-giây (xem `ChatService.markRead`).
- chat-service: `@SpringBootTest` phải dùng `RANDOM_PORT` (bean `webSocketContainer` không chạy ở web env MOCK). `ChatService` lưu đè cả document `conversations`, nên đừng đặt bộ đếm cần tăng nguyên tử vào đó: revision glyph = max revision + index unique `(conversationId, revision)` + thử lại (xem `GlyphService`).
- Discovery: bộ thẻ = người ở gần **hoặc** đang online; thẻ không có vị trí thì `distanceBand = null`.
- `ddl-auto` của user/media/post mặc định `none` vì chưa kiểm tra enum `validate` với MySQL thật.

- YAML cấu hình qua Config Server: không dùng `key: {}` (map rỗng → `ConverterNotFoundException`, service không khởi động); gán ít nhất một thuộc tính.
- Docker/Windows: cổng 80 có thể bị chặn (`HTTP_PORT=8080` + đổi `KEYCLOAK_PUBLIC_URL`); ổ ảo Docker không tự co lại (`Optimize-VHD`).
- Không commit `.project` / `.classpath` / `.factorypath` / `.settings/` (đã vào `.gitignore`). Chúng do m2e sinh từ `pom.xml` và chứa đường dẫn theo từng máy. Khi bị commit, PR của người khác ghi đè chúng: PR #7 làm `.factorypath` mất entry annotation processor của `common`/`outbox-jpa`, Lombok ngừng chạy **trong Eclipse** và cả project đỏ, dù `mvn install` vẫn xanh. Project đỏ mà `mvn` xanh thì đó là lỗi IDE: Maven → Update Project (`Alt+F5`), tick Force Update.
- Gateway: không `mutate().headers(h -> h.remove(..))` (spring-web 6.1: `ReadOnlyHttpHeaders`, 500); copy header rồi bọc `ServerHttpRequestDecorator` (xem `IdentityFilter.rewrite`).
- Ảnh nằm trên Cloudflare R2 (một bucket riêng tư, biến `R2_*`). R2 **không hỗ trợ presigned POST**: client `PUT` file tới URL đã ký kèm header `Content-Type`; `complete()` kiểm lại cỡ và Content-Type. Chưa chạy thử với R2 thật.
- Keycloak local: realm dùng email làm username, cookie có `Secure` (client script phải tự gửi cookie), cần `firstName/lastName` (VERIFY_PROFILE). Sau khi restart một service, Eureka giữ bản ghi cũ ~90 giây → 503 từ gateway.

## Chưa kiểm chứng

`ddl-auto=validate`, Redis GEO, profile `obs`, Apple/Google thật. Đừng khẳng định chúng "chạy được" nếu chưa chạy.
