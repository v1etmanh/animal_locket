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
| face-worker | `prometheus_client` trên cổng `HTTP_PORT` (8110); log Python dạng văn bản | `facework_*` (xem [08-face-anonymization-pipeline.md](08-face-anonymization-pipeline.md)) |
| Metric tự định nghĩa | notification-service: `push.sent{type}`, `push.invalid_token`, `push.dropped{type}`, `push.skipped{reason}` (Prometheus: `push_sent_total`…) | `NotificationDispatcher` |

### Khoảng trống cần bổ sung

| Thiếu | Hệ quả | Đề xuất |
|---|---|---|
| Metric độ trễ Outbox (số dòng `published_at IS NULL`, tuổi dòng cũ nhất) | Không phát hiện được event kẹt (xem runbook R5) | `Gauge` đọc từ `OutboxRepository` trong `libs/outbox-jpa` |
| Trace không đi xuyên Kafka | Không nối được request → event → worker thành một trace | Bật `spring.kafka.template.observation-enabled` / `listener.observation-enabled`; thêm header `traceparent` cho worker Python |
| Metric nghiệp vụ (đăng ký, đăng ảnh, match, tin nhắn, doanh thu) | Không có dashboard sản phẩm | Thêm `MeterRegistry` counter ở các điểm chính |
| `correlationId` trong envelope luôn `null` | Khó lần theo một luồng | Lấy từ `traceId` khi phát event |
| Log có thể chứa `publicId` | Rủi ro riêng tư | Review log; không log kèm toạ độ/nội dung |

## 11.2 SLO đề xuất

Lấy từ yêu cầu phi chức năng ([01-product-requirements.md](01-product-requirements.md) mục 1.7). Đo trên cửa sổ 28 ngày.

| SLI | SLO | Nguồn đo |
|---|---|---|
| Tỉ lệ request thành công (không 5xx) qua gateway | ≥ 99.5% | `http_server_requests_seconds_count{application="api-gateway"}` |
| Độ trễ đọc p95 | < 300 ms (feed < 500 ms) | `http_server_requests_seconds` |
| Thời gian xử lý ảnh p95 | < 20 s (AI), < 3 s (sticker) | `facework_duration_seconds` + `media_jobs` (thời gian `UPLOADED → READY`) |
| Ảnh kẹt (không có kết quả sau 10 phút) | < 0.5% ảnh | số `REJECTED/PROCESSING_TIMEOUT` / tổng |
| Độ trễ chat gửi → nhận p95 | < 500 ms | đo đầu-cuối bằng khung `ack` |
| Trễ Kafka consumer | < 30 giây ở p95 | exporter Kafka (`kafka_consumergroup_lag`) |
| Push gửi thành công | ≥ 95% | `push_sent_total / (push_sent + push_dropped)` |

## 11.3 Cảnh báo đề xuất

Các cảnh báo đã cấu hình sẵn trong `deploy/observability/prometheus/alerts.yml`: `ServiceDown`, `FaceWorkerAllDown`, `High5xxRate` (> 5%), `HighLatencyP95` (> 1.5 s), `CircuitBreakerOpen`, `KafkaConsumerLagHigh` (> 1000, 10 phút), `DeadLetterTopicGrowing`, `FaceWorkerFailureRateHigh` (> 5%), `PhotoProcessingSlow` (p95 > 20 s), `PhotoStickerFallbackHigh` (> 50% khi có GPU), `FaceWorkerRetriesHigh`, `JvmHeapNearLimit` (> 90%). Bảng dưới là danh sách đề xuất đầy đủ hơn; các dòng **chưa có trong `alerts.yml`** là: Outbox kẹt, Redis không truy cập được, DB pool cạn, webhook thanh toán lỗi, disk MinIO, ảnh quá hạn đột biến, push thất bại.

| Cảnh báo | Điều kiện | Mức |
|---|---|---|
| Gateway 5xx cao | 5xx > 2% trong 5 phút | Cao |
| Mạch mở | `resilience4j_circuitbreaker_state{state="open"}` = 1 quá 2 phút | Cao |
| Hàng đợi ảnh tồn | lag consumer `face-worker` > 100 hoặc > 2 phút | Cao |
| Tỉ lệ ảnh thất bại | `facework_failed_total` > 5% trong 15 phút | Cao |
| Worker không xử lý | `rate(facework_processed_total[10m]) = 0` trong khi có upload | Cao |
| Ảnh quá hạn | tăng đột biến `REJECTED/PROCESSING_TIMEOUT` | Trung bình |
| DLQ có message | `media.events.dlq` tăng | Cao |
| Outbox kẹt | dòng chưa đẩy cũ hơn 2 phút | Cao |
| Kafka consumer lag | > 1000 trong 10 phút (bất kỳ group) | Trung bình |
| Redis không truy cập được | lỗi `RedisConnectionFailure` / health `down` | Cao |
| DB pool cạn | `hikaricp_connections_pending` > 0 kéo dài | Trung bình |
| Tỉ lệ AI→sticker cao | `facework_processed_total{method="STICKER"}` / tổng tăng khi AI bật | Trung bình |
| JVM | heap > 85%, GC pause dài | Trung bình |
| Webhook thanh toán lỗi | 5xx ở `/webhooks/**` | Cao |
| Disk MinIO | > 80% | Trung bình |

## 11.4 Resilience4j: cấu hình thực tế

| Nơi | Cấu hình |
|---|---|
| Gateway | `circuitbreaker.configs.default`: cửa sổ 20, tối thiểu 10 lời gọi, ngưỡng lỗi 50%, mở 10 giây, half-open 5; `timelimiter.default`: 3 giây; HTTP connect 2 giây, response 3 giây |
| media, post, discovery, chat | `circuitbreaker.configs.default` như gateway (mở 10 giây); `timelimiter.default` 2 giây; `RestClient` qua `CircuitBreakerFactory.create("user-service" \| "media-service" \| "billing-service")` |
| chat | thêm `bulkhead.instances.chat.max-concurrent-calls=50` — **chỉ khai báo, chưa được dùng** |
| billing | `circuitbreaker.configs.default` (mở 30 giây), instance `store-apple`, `store-google`; `retry` 3 lần, 500 ms, backoff luỹ thừa — dành cho gateway store (chưa có trong code lúc viết) |
| notification | Không dùng Resilience4j: retry tự cài (3 lần, `500 ms × lần`) + thread pool riêng làm bulkhead |
| face-worker | Retry tự cài + DLQ |

> **Cần kiểm chứng**: giá trị `resilience4j.*` trong YAML có áp dụng cho `CircuitBreakerFactory` của Spring Cloud CircuitBreaker hay không. Nếu không, time limiter mặc định chỉ 1 giây và lời gọi sang user-service có thể bị hết hạn sớm khi tải cao. Cách chắc chắn là khai báo `Customizer<Resilience4JCircuitBreakerFactory>` rõ ràng.

## 11.5 Runbook

### R1. Hàng đợi ảnh tồn (face-worker chậm hoặc chết)

**Triệu chứng**: bài kẹt `PENDING_MEDIA`, người dùng báo "đang xử lý" lâu; lag của group `face-worker`.
1. `docker compose ps face-worker`; xem log: lỗi MinIO? thiếu mô hình YuNet? hết VRAM?
2. Nếu chậm do AI: đặt tạm `AI_ENABLED=false` (sticker nhanh gần như tức thì) rồi khởi động lại worker — ảnh vẫn được che kín.
3. Mở rộng: chạy thêm instance worker (cùng `KAFKA_GROUP`; số phân vùng `media.events` ≥ số worker).
4. Sau 10 phút không có kết quả, `MediaJanitor` tự `REJECTED/PROCESSING_TIMEOUT` và hoàn lượt ảnh; người dùng có thể đăng lại. **Không bao giờ** tự đăng ảnh chưa ẩn mặt.

### R2. Message trong DLQ `media.events.dlq`

1. Đọc message (`kafka-console-consumer --topic media.events.dlq --from-beginning`); xác định `mediaId`.
2. Ảnh gốc đã bị xoá khi hết lượt retry, nên không phát lại được; người dùng nhận `PHOTO_REJECTED(PROCESSING_FAILED)` và upload lại.
3. Tìm nguyên nhân chung (cùng loại lỗi nhiều lần?) trước khi bỏ qua. Message không phải JSON thì kiểm tra producer nào gửi sai vào `media.events`.

### R3. Kafka lag tăng ở consumer Java

1. Xác định group/topic bị lag, xem log service (lỗi deserialize, lỗi DB).
2. Consumer không có DLQ: lỗi lặp lại làm Spring Kafka bỏ qua message sau số lần thử mặc định. Kiểm tra nghiệp vụ bị bỏ sót (ví dụ `PHOTO_READY` không tới post-service → bài kẹt) và phát lại bằng cách đặt lại offset của group (`kafka-consumer-groups --reset-offsets`) — an toàn nhờ idempotency.
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
- Upload ảnh: dùng bản sao con vật của media-service; tạo job mới vẫn hoạt động nếu có bản sao.
- Quẹt, chat, xem ảnh: `503` (fail closed).
- Khôi phục: không cần thao tác; mạch tự đóng sau 10 giây khi gọi thành công.

### R7. Thanh toán: giao dịch không có quyền lợi

1. Người dùng báo đã trả tiền nhưng không có Pro: kiểm tra `purchases` theo `public_id`/`store_transaction_id`; nếu chưa có, nhờ người dùng mở app (client gửi lại `verify` — "khôi phục giao dịch").
2. `503 STORE_UNAVAILABLE`: lỗi gọi store; client giữ giao dịch chưa kết thúc và thử lại.
3. Có `purchases` nhưng thiếu hiệu lực ở service khác: kiểm tra `outbox_events` của billing và lag `billing.events` (R3/R5).
