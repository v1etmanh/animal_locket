# 11. Quan sát và chịu lỗi

## 11.1 Những gì đã được cấu hình trong code

| Mảng | Cấu hình | Nguồn |
|---|---|---|
| Metrics | Mọi service Java có `micrometer-registry-prometheus`; endpoint `/actuator/prometheus` (cùng `health`, `info`) | `management.endpoints.web.exposure.include: health,info,prometheus` |
| Nhãn metric | `management.metrics.tags.application=${spring.application.name}` | **chỉ có trong `infra/config-repo/application.yml`** — service chỉ nhận khi kết nối được Config Server; chạy độc lập thì không có nhãn này |
| Health | `/actuator/health` (+ probes `liveness`/`readiness` từ config-repo) | công khai (`permitAll`) |
| Tracing | `micrometer-tracing-bridge-otel` + `opentelemetry-exporter-otlp`; `management.otlp.tracing.endpoint=${OTLP_TRACING_ENDPOINT}` (mặc định `http://localhost:4318/v1/traces`, trong config-repo `http://tempo:4318/v1/traces`) | |
| Lấy mẫu trace | `management.tracing.sampling.probability=${TRACE_SAMPLING:1.0}` | **Đặt 0.05–0.1 ở production** |
| Log | `logging.pattern.level="%5p [${spring.application.name},%X{traceId:-},%X{spanId:-}]"` (config-repo) | để tìm log theo trace trong Loki/Grafana |
| Metric tự định nghĩa | notification-service: `push.sent{type}`, `push.invalid_token`, `push.dropped{type}`, `push.skipped{reason}` (Prometheus: `push_sent_total`…) | `NotificationDispatcher` |
| Metric Outbox | `outbox.pending` (số dòng chưa đẩy), `outbox.oldest.pending.age` (giây) — Prometheus: `outbox_pending`, `outbox_oldest_pending_age_seconds` | `libs/outbox-jpa` `OutboxMetrics` |

### Khoảng trống cần bổ sung

| Thiếu | Hệ quả | Đề xuất |
|---|---|---|
| Trace không đi xuyên Kafka | Không nối được request → event → consumer thành một trace | Bật `spring.kafka.template.observation-enabled` / `listener.observation-enabled` |
| Dashboard `photo-pipeline` dùng metric `facework_*` của face-worker đã gỡ | Dashboard trống | Thay bằng metric HTTP của media-service hoặc xoá dashboard |
| Metric nghiệp vụ (đăng ký, đăng ảnh, match, tin nhắn, doanh thu) | Không có dashboard sản phẩm | Thêm `MeterRegistry` counter ở các điểm chính |
| `correlationId` trong envelope luôn `null` | Khó lần theo một luồng | Lấy từ `traceId` khi phát event |
| Log có thể chứa `publicId` | Rủi ro riêng tư | Review log; không log kèm toạ độ/nội dung |

## 11.2 SLO đề xuất

Lấy từ yêu cầu phi chức năng ([01-product-requirements.md](01-product-requirements.md) mục 1.7). Đo trên cửa sổ 28 ngày.

| SLI | SLO | Nguồn đo |
|---|---|---|
| Tỉ lệ request thành công (không 5xx) qua gateway | ≥ 99.5% | `http_server_requests_seconds_count{application="api-gateway"}` |
| Độ trễ đọc p95 | < 300 ms (feed < 500 ms) | `http_server_requests_seconds` |
| `POST /media/{id}/complete` p95 | < 500 ms (gồm `stat` object trên R2) | `http_server_requests_seconds{application="media-service"}` |
| Bài kẹt `PENDING_MEDIA` quá 1 phút | < 0.5% bài | truy vấn `posts` + metric Outbox |
| Độ trễ chat gửi → nhận p95 | < 500 ms | đo đầu-cuối bằng khung `ack` |
| Trễ Kafka consumer | < 30 giây ở p95 | exporter Kafka (`kafka_consumergroup_lag`) |
| Push gửi thành công | ≥ 95% | `push_sent_total / (push_sent + push_dropped)` |

## 11.3 Cảnh báo đề xuất

Các cảnh báo đã cấu hình sẵn trong `deploy/observability/prometheus/alerts.yml`: `ServiceDown`, `High5xxRate` (> 5%), `HighLatencyP95` (> 1.5 s), `CircuitBreakerOpen`, `KafkaConsumerLagHigh` (> 1000, 10 phút), `JvmHeapNearLimit` (> 90%), `OutboxStuck` (event cũ nhất > 2 phút), `OutboxBacklogHigh` (> 1000 event). Bảng dưới là danh sách đề xuất đầy đủ hơn; các dòng **chưa có trong `alerts.yml`** là: Redis không truy cập được, DB pool cạn, webhook thanh toán lỗi, ảnh bị từ chối đột biến, push thất bại.

| Cảnh báo | Điều kiện | Mức |
|---|---|---|
| Gateway 5xx cao | 5xx > 2% trong 5 phút | Cao |
| Mạch mở | `resilience4j_circuitbreaker_state{state="open"}` = 1 quá 2 phút | Cao |
| Ảnh bị từ chối đột biến | `PHOTO_REJECTED` tăng (client gửi sai loại/cỡ) | Trung bình |
| Outbox kẹt | dòng chưa đẩy cũ hơn 2 phút | Cao |
| Kafka consumer lag | > 1000 trong 10 phút (bất kỳ group) | Trung bình |
| Redis không truy cập được | lỗi `RedisConnectionFailure` / health `down` | Cao |
| DB pool cạn | `hikaricp_connections_pending` > 0 kéo dài | Trung bình |
| JVM | heap > 85%, GC pause dài | Trung bình |
| Webhook thanh toán lỗi | 5xx ở `/webhooks/**` | Cao |

## 11.4 Resilience4j: cấu hình thực tế

| Nơi | Cấu hình |
|---|---|
| Gateway | `circuitbreaker.configs.default`: cửa sổ 20, tối thiểu 10 lời gọi, ngưỡng lỗi 50%, mở 10 giây, half-open 5; `timelimiter.default`: 3 giây; HTTP connect 2 giây, response 3 giây |
| media, post, discovery, chat | `circuitbreaker.configs.default` như gateway (mở 10 giây); `timelimiter.default` 2 giây; `RestClient` qua `CircuitBreakerFactory.create("user-service" \| "media-service" \| "billing-service")` |
| chat | thêm `bulkhead.instances.chat.max-concurrent-calls=50` — **chỉ khai báo, chưa được dùng** |
| billing | `circuitbreaker.configs.default` (mở 30 giây), instance `store-apple`, `store-google`; `retry` 3 lần, 500 ms, backoff luỹ thừa — dành cho gateway store (chưa có trong code lúc viết) |
| notification | Không dùng Resilience4j: retry tự cài (3 lần, `500 ms × lần`) + thread pool riêng làm bulkhead |

> **Cần kiểm chứng**: giá trị `resilience4j.*` trong YAML có áp dụng cho `CircuitBreakerFactory` của Spring Cloud CircuitBreaker hay không. Nếu không, time limiter mặc định chỉ 1 giây và lời gọi sang user-service có thể bị hết hạn sớm khi tải cao. Cách chắc chắn là khai báo `Customizer<Resilience4JCircuitBreakerFactory>` rõ ràng.

## 11.5 Runbook

### R1. Bài kẹt `PENDING_MEDIA`

**Triệu chứng**: người dùng đăng ảnh nhưng bài không hiện.
1. Job ảnh: `SELECT status, reject_reason FROM media_db.media_jobs WHERE id = ?`. Còn `PENDING_UPLOAD` → client chưa gọi `complete` (hoặc `complete` trả `409 NOT_UPLOADED` vì PUT lên R2 thất bại); job tự bị xoá sau 1 giờ.
2. Job `READY` mà bài vẫn kẹt → event `PHOTO_READY` chưa tới post-service: xem Outbox của media-service (R5) và lag group `post-service` (R3).
3. `PendingPostReconciler` của post-service tự gỡ bài kẹt khi đã có kết quả ảnh trong `media_states`.

### R2. Lỗi R2 khi upload/xem ảnh

1. Log media-service: lỗi ký URL, `stat`, `delete` trên R2 (sai `R2_ENDPOINT`/khoá, token thiếu quyền, bucket sai tên).
2. Điện thoại nhận `403` khi `PUT`: thường do URL đã quá 5 phút. Sai `Content-Type` không bị R2 chặn (chữ ký không ràng buộc header này) mà bị `complete` từ chối với `UNSUPPORTED_MEDIA_TYPE`.
3. `complete` idempotent nên client gọi lại an toàn. Nếu post-service xử lý `PHOTO_READY` lỗi liên tục, message vào `media.events.dlq` ([07-event-catalog.md](07-event-catalog.md) §7.7).

### R3. Kafka lag tăng ở consumer Java

1. Xác định group/topic bị lag, xem log service (lỗi deserialize, lỗi DB).
2. Lỗi lặp lại: sau 3 lần thử message chuyển sang `<topic>.dlq` (đọc bằng `kafka-console-consumer --topic <topic>.dlq --from-beginning`). DLQ chưa được tạo trong `kafka-init` (trừ `media.events.dlq`) thì việc chuyển sẽ lỗi — xem [07-event-catalog.md](07-event-catalog.md) §7.7. Sửa nguyên nhân rồi phát lại message vào topic gốc, hoặc đặt lại offset của group (`kafka-consumer-groups --reset-offsets`) — an toàn nhờ idempotency.
3. Mở rộng số instance (không vượt số phân vùng).

### R4. Redis không khả dụng

| Chức năng | Hành vi |
|---|---|
| Gateway rate limit | Lỗi Redis có thể làm request thất bại hoặc bỏ qua giới hạn tuỳ cấu hình — kiểm chứng; cân nhắc `deny-empty-key`/fail-open |
| post-service | Không đọc được hạn mức/cache bạn bè: đăng ảnh lỗi; feed dùng danh sách bạn từ user-service nếu gọi được |
| discovery | Bộ thẻ trả rỗng `degraded`; quẹt/boost lỗi |
| chat | Không phân phối giữa các instance được; kiểm tra quan hệ lỗi → gửi tin lỗi (fail closed) |
Hành động: khôi phục Redis (dữ liệu là cache/tạm, mất cũng chấp nhận được; vị trí sẽ tự đầy lại sau vài phút do client cập nhật).

### R5. Outbox kẹt (event không ra Kafka)

**Triệu chứng**: `outbox_events.published_at IS NULL` tồn dài; post không `PUBLISHED`, kết bạn không có push.
1. `SELECT count(*), min(created_at) FROM outbox_events WHERE published_at IS NULL;`
2. Kafka có sống không? Log `Đẩy event … thất bại` từ `OutboxRelay`. Relay dừng ở lỗi đầu tiên để giữ thứ tự: một message hỏng (quá lớn, topic không tồn tại) **chặn cả hàng đợi** — sửa nguyên nhân (tạo topic, tăng `max.request.size`).
3. Khi Kafka phục hồi, relay tự đẩy tiếp; có thể phát trùng → consumer idempotent.
4. `animal.outbox.relay.enabled` phải là `true` (mặc định).

### R6. user-service ngừng

- Gateway: request chưa có cache danh tính → `503 IDENTITY_UNAVAILABLE`; người đã có cache (5 phút) vẫn đi tiếp.
- Feed: dùng danh sách bạn cũ (≤ 1 giờ) nếu có; nếu không có, trả rỗng `degraded`.
- Upload ảnh: không phụ thuộc user-service (xin URL và `complete` vẫn chạy).
- Quẹt, chat, xem ảnh của người khác: `503` (fail closed).
- Khôi phục: không cần thao tác; mạch tự đóng sau 10 giây khi gọi thành công.

### R7. Thanh toán: giao dịch không có quyền lợi

1. Người dùng báo đã trả tiền nhưng không có Pro: kiểm tra `purchases` theo `public_id`/`store_transaction_id`; nếu chưa có, nhờ người dùng mở app (client gửi lại `verify` — "khôi phục giao dịch").
2. `503 STORE_UNAVAILABLE`: lỗi gọi store; client giữ giao dịch chưa kết thúc và thử lại.
3. Có `purchases` nhưng thiếu hiệu lực ở service khác: kiểm tra `outbox_events` của billing và lag `billing.events` (R3/R5).
