# DigitalOcean Demo Deployment

Runbook này tái tạo Animal Locket trên một DigitalOcean Droplet mới với mục tiêu chạy demo đầy đủ và giữ chi phí thấp.

## Thứ tự thực hiện

| Bước | Tài liệu | Kết quả |
|---|---|---|
| 1 | [Tổng quan và chi phí](01-overview-and-cost.md) | Hiểu phạm vi và giới hạn demo |
| 2 | [Tạo Droplet và SSH](02-create-droplet-and-ssh.md) | Có IP và kết nối SSH |
| 3 | [Bootstrap server](03-bootstrap-server.md) | Docker, swap và firewall sẵn sàng |
| 4 | [Deploy stack](04-deploy-stack.md) | Core và microservice chạy bằng Compose |
| 5 | [HTTPS và Keycloak](05-https-and-keycloak.md) | HTTPS tin cậy, OAuth client sẵn sàng |
| 6 | [Smoke check và Flutter](06-smoke-check-and-flutter.md) | Public boundary hoạt động |
| 7 | [Vận hành và redeploy](07-operations-and-redeploy.md) | Biết restart, destroy và tạo lại |
| 8 | [Agent handoff](08-agent-handoff.md) | Prompt triển khai tự động một lượt |
| 9 | [Prompt copy-paste từ source local](09-recreate-server-copy-paste-prompt.md) | Tạo lại server khi branch chưa push GitHub |
| 10 | [CI/CD backend](10-backend-cicd.md) | Test/build trên GitHub, deploy qua SSH, rollback |
| 11 | [Đối chiếu master ngày 08/11](11-master-review-2026-11-08.md) | Thay đổi code và ảnh hưởng tới deploy |

## Đầu vào bắt buộc

```text
DROPLET_IP=<IPv4 của Droplet>
SSH_PRIVATE_KEY=<đường dẫn private key trên máy điều khiển>
LETSENCRYPT_EMAIL=<email nhận cảnh báo chứng chỉ>
GIT_REPOSITORY=https://github.com/v1etmanh/animal_locket.git
GIT_REF=<branch hoặc commit cần deploy>
```

## Kết quả cuối

Với `PUBLIC_DOMAIN=<IP đổi dấu chấm thành dấu gạch ngang>.nip.io`:

```text
https://api.<PUBLIC_DOMAIN>
https://auth.<PUBLIC_DOMAIN>
https://files.<PUBLIC_DOMAIN>
```

Flutter và Postman chỉ gọi các hostname trên. Database, Kafka, Redis, Eureka và Config Server không được public.
