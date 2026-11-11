# Animal Locket Postman Smoke Tests

Thư mục này chứa collection, environment và hướng dẫn kiểm tra public deployment boundary của Animal Locket.

## File import vào Postman

- [Collection](Animal-Locket-Demo-Smoke.postman_collection.json)
- [Environment](Animal-Locket-Demo.postman_environment.json)
- [Service tests: billing, chat, discovery, media](Animal-Locket-Service-Tests.postman_collection.json)

## Hướng dẫn theo thứ tự

1. [Import collection và environment](docs/01-import-collection-and-environment.md)
2. [Lấy JWT bằng Keycloak Authorization Code + PKCE](docs/02-keycloak-oauth-pkce.md)
3. [Chạy smoke tests](docs/03-run-smoke-tests.md)
4. [Đọc kết quả và xử lý lỗi](docs/04-troubleshooting.md)
5. [Kiểm thử chức năng billing, chat, discovery, media](docs/05-service-tests.md)

## Phạm vi kiểm tra

Collection kiểm tra:

- HTTPS redirect, chứng chỉ và Keycloak OIDC discovery.
- Keycloak Admin không public.
- MinIO health.
- API Gateway bắt buộc JWT.
- User, Post, Media, Discovery, Chat và Billing Service.

Notification Service, Config Server, Eureka, Kafka, Redis và database không có public API. Kiểm tra chúng bằng Docker health trên server, không mở cổng chỉ để Postman truy cập.

## An toàn

- Không commit `access_token`.
- Không thêm password Keycloak vào collection.
- Không dùng client `mobile` cho callback Postman.
- Không tắt PKCE hoặc bật direct password grant.
