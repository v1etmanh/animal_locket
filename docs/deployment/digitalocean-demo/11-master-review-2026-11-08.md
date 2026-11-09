# Đối chiếu master: các commit ngày 08/11/2026

Mốc kiểm tra: `master`/`origin/master` tại `af24859` (đã merge PR deploy #5), ngày theo timezone `+07:00`. Các merge được đối chiếu theo thay đổi thực tế, không đếm lặp nội dung commit con.

| Commit | Thay đổi liên quan backend | Ảnh hưởng deploy |
|---|---|---|
| `ca2afeb` | Avatar riêng cho mỗi user; `V2__avatar.sql`, seed/backfill, thư viện JSON vào classpath qua `services/user-service/pom.xml`; thay đổi event/DTO user/post/discovery | Rebuild các service cùng source. Dockerfile Java đã COPY `libs`, Maven resources đã đóng gói JSON. Flyway tự áp dụng V2 khi khởi động; không chạy SQL tay, không cần service/volume mới |
| `f0807bf` | Giới hạn tin nhắn chat theo quyền lợi, thêm tham số cấu hình có mặc định | Rebuild chat-service; không cần port, biến bắt buộc hay migration mới |
| `e03cf92` | Feed/profile phía mobile | Không cần sửa deploy backend |
| `fcc23b3` | `PendingPostReconciler` xử lý race bài PENDING_MEDIA và PHOTO_READY | Rebuild post-service; scheduler chạy trong JVM hiện tại, mặc định 3 giây; không cần cron/container riêng |
| `bad845b` | API danh sách bài theo tác giả và timeout discovery gọi user-service 6 giây; sửa mobile realtime/upload | Rebuild post/discovery. Gateway đã route `/api/v1/posts/**`, timeout gateway 10 giây lớn hơn timeout mới; không phải thêm router Traefik |
| `326d783`, `3bd2607`, `635c59c` | Stack demo, Postman, runbook | Đã nằm trong master qua PR #5 |

Không có worker Python mới hay event topic mới trong các commit này. Giữ nguyên mô hình demo hiện tại: một máy, profile `core,app`, không bật bộ observability chỉ để chạy demo. Chưa có số đo tải mới để đề xuất tăng cấu hình máy.

## Điều chỉnh thực hiện sau đối chiếu

- `deploy/demo/docker-compose.demo.yml`: đặt mặc định return URL thanh toán là HTTPS đúng host API. Trước đó cấu hình gốc fallback HTTP trong khi demo dùng HTTPS; callback thanh toán phải khớp URL tạo chữ ký/đăng ký với nhà cung cấp.
- `deploy/demo/generate-env.sh`: sinh URL HTTPS ngay từ đầu; từ chối ghi đè `.env` đã có để redeploy không vô tình đổi mật khẩu khi database volume vẫn dùng mật khẩu cũ.
- Thêm workflow CI/CD, Dockerfile runtime nhận JAR đã test, overlay release, script validation/deploy/smoke và [hướng dẫn CI/CD](10-backend-cicd.md).
- Docker context runtime chỉ chứa JAR; context MinIO không chứa source/config bí mật.
- `.gitattributes` giữ xuống dòng LF cho script để checkout trên Windows rồi chạy Linux không bị lỗi CRLF.
- `pom.xml`: nâng Testcontainers (chỉ dùng test) lên `1.21.4` tương thích Docker Engine 29. Khi kiểm tra local, bản cũ đã bỏ qua toàn bộ Mongo integration test vì không kết nối được Docker; CI mới kiểm tra report và fail nếu Mongo/Redis test bị skip. Xem [release chính thức](https://github.com/testcontainers/testcontainers-java/releases/tag/1.21.4).

Không cần sửa migration, Kafka topic, init database hay realm Keycloak cho các commit trên. Với dữ liệu cũ, backup trước khi nâng cấp và theo dõi log Flyway/AvatarPoolSeeder/AvatarBackfill. Health check không chứng minh mọi chức năng nghiệp vụ đúng; cần thêm Postman có đăng nhập.

## Kết quả kiểm chứng local ngày 09/11/2026

- `mvn -B -ntp verify`: toàn bộ 13 module build thành công. Máy local có `SPRING_PROFILES_ACTIVE=local`; phải bỏ biến này khỏi tiến trình test để Config Server dùng profile `native` của dự án. Không sửa cấu hình ứng dụng để né biến môi trường local.
- Sau khi nâng Testcontainers, chạy lại Mongo/Redis integration bằng `mvn -pl services/discovery-service,services/chat-service -am -Dtest=ChatMongoIntegrationTest,GlyphMongoIntegrationTest,RedisDiscoveryStoreTest -Dsurefire.failIfNoSpecifiedTests=false verify` với Redis local và Docker thật: 13 test đạt, không skip.
- Tổng hợp report toàn bộ backend sau hai lượt: 397 test, 0 failure, 0 error, 1 skipped (R2 live cần credentials), tức 396 test đã chạy và đạt.
- ShellCheck, Bash syntax, actionlint, Compose base+demo và base+demo+CI đều đạt. Đã kiểm tra sinh `.env` mới có HTTPS và chạy lại không ghi đè credentials.
- Docker build runtime thành công cho Config Server và user-service; image chạy với user `app`, JAR user-service có `BOOT-INF/classes/avatar/avatar-lib.v1.json`.
- Chưa chạy workflow trên GitHub, chưa thực hiện SSH/CD tới Droplet và chưa chạy migration trên database server trong lượt này. Cần cấu hình secret/variable theo bước 10, đưa workflow lên `master`, rồi chạy xác nhận end-to-end.
