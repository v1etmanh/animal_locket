# 8. Giao triển khai cho Agent

## Thông tin phải cung cấp

```text
DROPLET_IP=<IP mới>
SSH_PRIVATE_KEY=<đường dẫn private key>
LETSENCRYPT_EMAIL=<email>
GIT_REF=<branch hoặc commit>
```

## Prompt hoàn chỉnh

```text
Hãy triển khai Animal Locket theo tài liệu:
docs/deployment/digitalocean-demo/README.md

Thông tin:
- DROPLET_IP: <IP>
- SSH_PRIVATE_KEY: <path>
- LETSENCRYPT_EMAIL: <email>
- GIT_REF: <branch-or-commit>

Thực hiện trọn quy trình theo đúng thứ tự tài liệu.
Dùng profile core,app; build Java tuần tự; không bật profile obs.
Không tạo thêm Managed Database, Load Balancer, Volume, Backup trả phí hoặc Kubernetes.
Không in secret hoặc nội dung .env ra output.
Không hạ sslRequired của Keycloak xuống none.

Chỉ chạy smoke check tối thiểu trong 06-smoke-check-and-flutter.md;
không lặp lại kiểm tra SSH hoặc kiểm tra thủ công chi tiết nếu tất cả đều đạt.

Cuối cùng báo:
1. URL API, Auth và Files.
2. Trạng thái container.
3. Kết quả ba smoke checks.
4. Giá Droplet theo giờ và mức tối đa tháng.
5. File local hoặc server đã thay đổi.
```

## Tiêu chí hoàn thành

- SSH hoạt động.
- Compose hợp lệ.
- Container dài hạn healthy.
- OIDC discovery `200`.
- MinIO health `200`.
- API protected endpoint `401` khi không có JWT.
- HTTP redirect sang HTTPS.
- Postman client tồn tại.

Nếu một điều kiện không đạt, Agent phải báo lỗi cụ thể và log liên quan; không tự tăng cấu hình Droplet hoặc tạo sản phẩm trả phí.
