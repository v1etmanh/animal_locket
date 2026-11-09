# 3. Chạy smoke tests

Chọn environment **Animal Locket Demo** và bảo đảm `access_token` đã có giá trị.

## Folder 00 — Public edge and TLS

Folder này không cần JWT và kiểm tra:

- HTTP redirect sang HTTPS.
- OIDC issuer và endpoint dùng HTTPS.
- Keycloak Admin bị chặn từ Internet.
- MinIO hoạt động.
- Gateway từ chối request thiếu JWT.

## Folder 01 — User bootstrap

Chạy đúng thứ tự:

### Register profile

Body mặc định:

```json
{
  "alias": "postman_demo",
  "birthDate": "2000-01-01"
}
```

Mong đợi `201`. Request idempotent theo tài khoản Keycloak và tự lưu `public_id` vào environment.

### Get my profile

Mong đợi `200` và JSON hồ sơ.

### List animals

Mong đợi `200` và một JSON array.

### List friends

Mong đợi `200`. Tài khoản mới có thể trả `[]`.

## Folder 02 — Business service smoke

| Request | Service | Mã đúng | Ghi chú |
|---|---|---:|---|
| Feed | Post | 200 | Có thể rỗng |
| My posts | Post | 200 | Tài khoản mới có thể `[]` |
| Missing media | Media | 404 | UUID cố ý không tồn tại; không tạo dữ liệu rác |
| Heartbeat | Discovery | 204 | Ghi nhận online |
| Conversations | Chat | 200 | Có thể `[]` |
| Products | Billing | 200 | JSON array |
| My plan | Billing | 200 | Có `plan` và `wallet` |

`404` của media là assertion thành công vì chứng minh gateway đã route tới media-service mà không phải tạo upload giả.

## Chạy toàn bộ collection

1. Chọn dấu `...` cạnh collection.
2. Chọn **Run collection**.
3. Giữ thứ tự folder `00 → 01 → 02`.
4. Chọn **Run Animal Locket Demo Smoke**.

Kết quả đạt khi mọi assertion màu xanh. Không yêu cầu mọi response đều là `200`; collection có chủ ý kiểm tra `301/308`, `401`, `403`, `404` và `204`.

## Service không kiểm tra bằng Postman

Notification Service, Eureka, Config Server, Kafka, Redis và database không có public endpoint. Trên server kiểm tra bằng:

```bash
cd /opt/animal-locket
docker compose \
  -f docker-compose.yml \
  -f deploy/demo/docker-compose.demo.yml \
  ps -a
```

Container dài hạn phải `healthy`; `kafka-init` và `minio-init` là `Exited (0)`.
