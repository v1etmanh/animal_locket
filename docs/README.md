# Animal Locket — Bộ tài liệu dự án

Animal Locket là ứng dụng chia sẻ ảnh nhanh giữa bạn bè (kiểu Locket) với hai điểm khác biệt: **danh tính ẩn danh** (alias + avatar con vật duy nhất cho mỗi người) và **kết bạn online kiểu Tinder** (quẹt thẻ, tìm người lân cận).

> **Thay đổi lớn so với kế hoạch gốc**: tính năng "thay mọi khuôn mặt trong ảnh bằng mặt con vật" (face-worker) **đã bị gỡ**. Ảnh được đăng nguyên bản, chỉ bạn bè xem; app xoá EXIF/GPS trước khi upload; kho ảnh là Cloudflare R2. Xem ADR-014 trong [15-adr.md](15-adr.md).

> Quy ước: mục ghi **Đề xuất** là quyết định tác giả tài liệu đưa ra để lấp chỗ trống, chưa được chủ dự án xác nhận. Mục còn lại bám theo [ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md) (bản v2), vốn là nguồn gốc của các quyết định kiến trúc ban đầu; chỗ code đã khác kế hoạch được ghi trong 03 và 15.

## Mục lục

| # | Tài liệu | Nội dung | Đối tượng đọc |
|---|---|---|---|
| 0 | [ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md) | Kế hoạch kiến trúc gốc (v2), các quyết định đã chốt | Mọi người |
| 1 | [01-product-requirements.md](01-product-requirements.md) | Yêu cầu sản phẩm: persona, user story, phạm vi, tiêu chí chấp nhận | PM, dev, QA |
| 2 | [02-business-monetization.md](02-business-monetization.md) | Mô hình kinh doanh, gói, kinh tế đơn vị, chỉ số | PM, chủ dự án |
| 3 | [03-architecture.md](03-architecture.md) | Kiến trúc tổng thể, công nghệ, luồng chính, nguyên tắc | Dev, kiến trúc sư |
| 4 | [04-service-specs.md](04-service-specs.md) | Đặc tả từng service: trách nhiệm, ranh giới, logic nghiệp vụ | Dev |
| 5 | [05-data-model.md](05-data-model.md) | Lược đồ MySQL, PostgreSQL, MongoDB, khoá Redis, kho ảnh R2 | Dev |
| 6 | [06-api-reference.md](06-api-reference.md) | Quy ước API và danh sách endpoint REST/WebSocket | Dev, client |
| 7 | [07-event-catalog.md](07-event-catalog.md) | Kafka topic, envelope, danh sách event, Outbox, idempotency | Dev |
| 8 | [08-face-anonymization-pipeline.md](08-face-anonymization-pipeline.md) | **Đã ngừng dùng** — lịch sử thiết kế pipeline ẩn mặt | Tham khảo |
| 9 | [09-privacy-safety-security.md](09-privacy-safety-security.md) | Ẩn danh, vị trí, an toàn người lạ, bảo mật, tuân thủ | Mọi người |
| 10 | [10-deployment-infrastructure.md](10-deployment-infrastructure.md) | Docker Compose, profile, cổng, biến môi trường, tài nguyên | DevOps, dev |
| 11 | [11-observability-resilience.md](11-observability-resilience.md) | Giám sát, log, trace, SLO, cảnh báo, chính sách chịu lỗi | DevOps, dev |
| 12 | [12-testing-strategy.md](12-testing-strategy.md) | Chiến lược kiểm thử, bộ ảnh test, tải, bảo mật | QA, dev |
| 13 | [13-development-guide.md](13-development-guide.md) | Cấu trúc repo, quy ước code, git, CI/CD, onboarding | Dev |
| 14 | [14-roadmap-risks.md](14-roadmap-risks.md) | Lộ trình theo giai đoạn, rủi ro, câu hỏi còn mở | PM, chủ dự án |
| 15 | [15-adr.md](15-adr.md) | Nhật ký quyết định kiến trúc (ADR) | Dev, kiến trúc sư |
| 16 | [16-glossary.md](16-glossary.md) | Thuật ngữ | Mọi người |
| 17 | [17-flutter-app-requirements.md](17-flutter-app-requirements.md) | Requirement app Flutter (iOS + Android) | Dev mobile |
| 18 | [18-mobile-integration-brief.md](18-mobile-integration-brief.md) | Brief nối app với backend thật | Dev mobile |
| 19 | [19-avatar-mechanism.md](19-avatar-mechanism.md) | Cơ chế avatar con vật duy nhất | Dev, PM |
| — | [architecture/](architecture/README.md) | Sơ đồ lớp và tuần tự cho backend và frontend | Dev |
| — | [glyph-chat-implementation-plan/](glyph-chat-implementation-plan/) | Kế hoạch glyph chat (backend + mobile) | Dev |

`architecture.html` trong thư mục này là bản trình bày trực quan của kế hoạch kiến trúc **gốc** (còn face-worker/MinIO).

## Đọc theo vai trò

- **Mới vào dự án**: README → 01 → 03 → 16.
- **Dev backend**: 03 → 04 → 05 → 06 → 07 → 13.
- **Dev mobile**: 17 → 18 → 06 → 19.
- **DevOps**: 10 → 11 → 09 (mục bảo mật).
- **QA**: 01 (tiêu chí chấp nhận) → 12.

## Tóm tắt một trang

- **Danh tính**: người dùng chỉ lộ `publicId` ngẫu nhiên + alias + avatar con vật duy nhất. Không lộ tên thật, email, SĐT.
- **Ảnh**: app nén lại và xoá EXIF → PUT thẳng lên R2 bằng URL ký sẵn → `complete` kiểm tra cỡ/loại → đăng. Ảnh **giữ nguyên khuôn mặt**, chỉ bạn bè xem được.
- **Bạn bè**: quẹt phải để gửi lời mời, hai bên cùng quẹt phải thì thành bạn. Feed chỉ có bài của bạn bè.
- **Lân cận**: vị trí làm tròn lưới ~500 m, chỉ trả khoảng cách theo mức, có chống dò vị trí.
- **Chat**: WebSocket, MongoDB, chỉ với bạn bè hoặc người lạ đã chấp nhận lời mời.
- **Tiền**: Freemium. Pro mở quyền chọn con vật chủ đạo và nới hạn mức; mua lẻ Boost, lời mời ưu tiên, gói con vật.
- **Hạ tầng**: Java/Spring Boot + app Flutter; Kafka, Redis, MySQL, PostgreSQL, MongoDB (DB là dịch vụ ngoài), Cloudflare R2; Traefik, Keycloak, Eureka, Config Server; Grafana stack.
