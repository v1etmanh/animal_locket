# 3. Bootstrap Ubuntu

Chạy các lệnh sau trong phiên SSH `root`.

## Cài công cụ

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-v2 git rsync ufw openssl
systemctl enable --now docker
```

## Tạo swap 4 GB

```bash
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

Swap giảm nguy cơ OOM lúc build nhiều JVM nhưng không thay thế RAM.

## Cấu hình firewall

```bash
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
```

Không mở public các cổng:

```text
3306  MySQL
5432  PostgreSQL
27017 MongoDB
6379  Redis
9092  Kafka
8080  Gateway/Keycloak nội bộ
8761  Eureka
8888  Config Server
```

## Kiểm tra tối thiểu

```bash
docker --version
docker compose version
free -h
swapon --show
ufw status
```

Chỉ cần các lệnh chạy thành công; không cần kiểm tra thủ công sâu ở bước này.
