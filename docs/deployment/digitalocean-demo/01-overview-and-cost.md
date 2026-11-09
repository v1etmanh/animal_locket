# 1. Tổng quan, kiến trúc và chi phí

## Mục tiêu

- Chạy demo toàn bộ microservice trên một máy.
- Thanh toán theo giờ và không tạo thêm sản phẩm DigitalOcean trả phí.
- Dùng HTTPS được mobile tin cậy.
- Có thể destroy và tái tạo bằng source code cùng runbook.

## Cấu hình máy

```text
Region: Singapore SGP1
OS: Ubuntu 24.04 LTS
CPU: 4 vCPU
RAM: 8 GB
SSD: khoảng 160 GB
Swap: 4 GB
```

Giá tham chiếu tại lần triển khai ngày 2026-11-08 là `$0.071/giờ`, tối đa khoảng `$48/tháng`. Giá có thể thay đổi; kiểm tra lại trong DigitalOcean trước khi tạo.

## Thành phần chạy cùng Droplet

- Traefik, Keycloak.
- Eureka Server, Config Server, API Gateway.
- User, Media, Post, Notification, Discovery, Chat và Billing Service.
- MySQL, PostgreSQL, MongoDB, Redis, Kafka và MinIO.

Profile `obs` không được bật để tiết kiệm RAM. Do đó demo không chạy Grafana, Prometheus, Loki hoặc Tempo.

## Vì sao chọn một Droplet

| Quyết định | Lý do | Giới hạn |
|---|---|---|
| Một Droplet | Chi phí demo thấp nhất | Không có HA |
| Database local | Không trả phí Managed Database | Cùng failure domain với app |
| Build Java tuần tự | Tránh hết RAM | Build đầu tiên lâu hơn |
| `nip.io` | Không mua hoặc cấu hình DNS | Hostname thay đổi theo IP |
| Let's Encrypt | HTTPS miễn phí và tự gia hạn | Cổng 80/443 phải mở |

## Không bật

- Paid Backup.
- Managed Database.
- Load Balancer.
- Kubernetes.
- Block Storage bổ sung.
- Profile `obs`.

## Cảnh báo dữ liệu

Database và MinIO nằm trên Droplet. Destroy Droplet có thể làm mất toàn bộ tài khoản, hồ sơ, bài đăng, chat, billing và file. Cấu hình này chỉ phù hợp demo hoặc dữ liệu có thể tạo lại.
