# 7. Danh mục event (Kafka)

Nguồn sự thật: `libs/common` (`Topics`, `EventTypes`, `event/Events`, `event/EventEnvelope`) và các listener của từng service.

## 7.1 Envelope

Mọi message là một chuỗi JSON (key và value đều `String`):

```json
{
  "eventId": "7d9c...-uuid",
  "type": "PHOTO_READY",
  "version": 1,
  "occurredAt": "2026-11-06T03:21:45.123Z",
  "producer": "media-service",
  "correlationId": null,
  "key": "<khoá phân vùng>",
  "payload": { "...": "..." }
}
```

- `eventId` dùng để khử trùng lặp; `producer` = `spring.application.name` (face-worker ghi `face-worker`).
- Payload **chỉ chứa `publicId`** và mã nghiệp vụ; không bao giờ chứa email, SĐT, `sub`, toạ độ.
- `FAIL_ON_UNKNOWN_PROPERTIES` tắt: thêm trường mới vào payload là tương thích ngược.
- `version` hiện luôn là 1; chưa có cơ chế đa phiên bản.

## 7.2 Topic

| Topic | Hằng số | Producer | Khoá message | Ghi chú |
|---|---|---|---|---|
| `user.events` | `Topics.USER` | user-service (Outbox) | `publicId` | |
| `friend.events` | `Topics.FRIEND` | user-service (Outbox) | `toPublicId` (request) / id thấp (accepted) | |
| `media.events` | `Topics.MEDIA` | media-service (Outbox) | `mediaId` | face-worker nghe topic này |
| `media.results` | `Topics.MEDIA_RESULTS` | face-worker | `mediaId` | kết quả thô của worker |
| `media.events.dlq` | `Topics.MEDIA_DLQ` | face-worker | `mediaId` | message xử lý lỗi sau 3 lần thử, hoặc không phải JSON |
| `post.events` | `Topics.POST` | post-service (Outbox) | `postId` | |
| `chat.events` | `Topics.CHAT` | chat-service (**trực tiếp**, không Outbox) | `recipientPublicId` | |
| `billing.events` | `Topics.BILLING` | billing-service (Outbox) | `publicId` | |

Thứ tự được đảm bảo **theo từng khoá** trong một topic; **không** có thứ tự giữa các topic. Ví dụ `PHOTO_READY` (topic media) có thể đến post-service trước khi người dùng tạo bài — đã được xử lý bằng bảng `media_states`.

> Topic phải tồn tại trước (hoặc bật auto-create). Khuyến nghị tạo tường minh với số phân vùng ≥ 3 và đặt `retention.ms` hợp lý vì payload chứa `publicId` (xem [09-privacy-safety-security.md](09-privacy-safety-security.md)).

## 7.3 Các loại event và payload

### Người dùng (`user.events`)

| `type` | Payload (`Events.*`) | Consumer |
|---|---|---|
| `USER_REGISTERED` | `{publicId, ageGroup, leadAnimal}` | media (`owner_animals`) |
| `USER_DELETED` | `{publicId}` | media, post, chat, discovery, billing |
| `USER_BLOCKED` | `{blockerPublicId, blockedPublicId}` | chat (đóng hội thoại), post (xoá cache bạn bè) |
| `LEAD_ANIMAL_CHANGED` | `{publicId, leadAnimal}` | media (`owner_animals`) |

### Bạn bè (`friend.events`)

| `type` | Payload | Consumer |
|---|---|---|
| `FRIEND_REQUEST_RECEIVED` | `{fromPublicId, toPublicId}` | notification |
| `FRIEND_ACCEPTED` | `{userAPublicId, userBPublicId}` (A < B) | chat, post (xoá cache), notification |

> **Không có event "huỷ kết bạn"**: `DELETE /friends/{id}` không phát gì. Cache bạn bè (post 45 giây; chat 30 giây) tự hết hạn; hội thoại chat vẫn `ACTIVE` nhưng gửi tin sẽ bị `403` sau khi cache hết. Nên bổ sung `FRIEND_REMOVED`.

### Ảnh (`media.events`, `media.results`)

| `type` | Topic | Payload | Producer | Consumer |
|---|---|---|---|---|
| `PHOTO_UPLOADED` | media.events | `{mediaId, ownerPublicId, rawKey, leadAnimal, context, refId}` | media-service | face-worker |
| `FACE_PROCESSED` | media.results | `{mediaId, ownerPublicId, publicKey, method, facesDetected}` | face-worker | media-service |
| `FACE_FAILED` | media.results | `{mediaId, ownerPublicId, reason}` | face-worker | media-service |
| `PHOTO_READY` | media.events | `{mediaId, ownerPublicId, publicKey, method, facesDetected, context, refId}` | media-service | post (`context=POST`) |
| `PHOTO_REJECTED` | media.events | `{mediaId, ownerPublicId, reason, context, refId}` | media-service | post (`context=POST`), notification |

`context` là `POST` hoặc `CHAT`; `method` là `AI`, `STICKER` hoặc `NONE` (không có mặt).

**Khác kế hoạch**: kế hoạch để worker phát `PHOTO_READY/REJECTED`. Code dùng hai bước để trạng thái job trong DB của media-service và event phát ra luôn đi cùng một transaction (Outbox). Xem ADR-006.

### Bài đăng (`post.events`)

| `type` | Payload | Consumer |
|---|---|---|
| `POST_PUBLISHED` | `{postId, authorPublicId}` | notification (gửi cho mọi bạn của tác giả) |
| `POST_LIKED` | `{postId, authorPublicId, likerPublicId}` | notification (tác giả; không phát khi tự like) |
| `POST_COMMENTED` | `{postId, authorPublicId, commenterPublicId}` | notification |

### Chat (`chat.events`)

| `type` | Payload | Consumer |
|---|---|---|
| `MESSAGE_SENT` | `{conversationId, senderPublicId, recipientPublicId}` | notification |

Không chứa nội dung tin nhắn.

### Thanh toán (`billing.events`)

| `type` | Payload | Consumer |
|---|---|---|
| `SUBSCRIPTION_ACTIVATED` | `{publicId, plan:"PRO", expiresAt}` | user (`entitlements`), post (`pro:`), discovery (`pro:`), notification |
| `SUBSCRIPTION_EXPIRED` | `{publicId, plan:"FREE", expiresAt:null}` | user, post, discovery |
| `CONSUMABLE_GRANTED` | `{publicId, item, quantity}`; `item` = `BOOST` \| `PRIORITY_INVITE` \| `ANIMAL_PACK:<mã>` | user (chỉ `ANIMAL_PACK:*` → mở con vật) |

`SUBSCRIPTION_ACTIVATED/EXPIRED` được phát lại theo **trạng thái Pro hiện tại** của người dùng mỗi khi có thay đổi (một người có thể có thuê bao ở nhiều store), nên consumer phải coi đây là "đặt trạng thái", không phải "cộng dồn".

## 7.4 Ai nghe topic nào

| Consumer group | Topic | Idempotency |
|---|---|---|
| `user-service` | `billing.events` | `processed_events` |
| `media-service` | `user.events`, `media.results` | `processed_events` |
| `post-service` | `media.events`, `user.events`, `friend.events`, `billing.events` | `processed_events` |
| `billing-service` | `user.events` (chỉ `USER_DELETED`) | `processed_events` |
| `discovery-service` | `user.events`, `billing.events` | thao tác tự idempotent |
| `chat-service` | `user.events`, `friend.events` | thao tác tự idempotent |
| `notification-service` | `user, friend, post, chat, media, billing` | cache `eventId` (best-effort) |
| `face-worker` | `media.events` | kiểm tra `pub/{mediaId}.jpg` đã tồn tại |

Cấu hình consumer: `enable-auto-commit=false`, `ack-mode=record`, `auto-offset-reset=earliest` (riêng notification `latest`).

## 7.5 Cơ chế Outbox

1. Trong transaction nghiệp vụ gọi `OutboxService.publish(topic, type, key, payload)` (`Propagation.MANDATORY`: gọi ngoài transaction sẽ lỗi).
2. `OutboxRelay.relay()` chạy mỗi `animal.outbox.relay.interval-ms` (500 ms): lấy tối đa 100 dòng `published_at IS NULL` theo `created_at`, khoá `PESSIMISTIC_WRITE` kèm `lock.timeout=-2` (**SKIP LOCKED**) để nhiều instance không giẫm nhau, gửi từng dòng và chờ ack ≤ 5 giây, đánh dấu `published_at`. Gặp lỗi đầu tiên thì **dừng** để giữ thứ tự.
3. Đảm bảo **at-least-once**: có thể phát trùng (relay chết giữa chừng) nên mọi consumer phải idempotent.
4. Tắt relay: `animal.outbox.relay.enabled=false` (dùng trong test).

## 7.6 Idempotency phía consumer

```java
@KafkaListener(topics = ..., groupId = "...")
@Transactional
public void onMessage(String json) {
    EventEnvelope e = EventJson.read(json);
    if (!idempotency.firstTime(e.eventId())) return;   // đã xử lý
    ...xử lý...
}
```

`IdempotencyService.firstTime` chạy **cùng transaction** với xử lý: lỗi thì cả dấu vết lẫn thay đổi rollback và event được giao lại. Khi lỗi liên tục, Spring Kafka mặc định thử lại rồi bỏ qua message — **chưa cấu hình DLQ cho consumer Java** (chỉ face-worker có DLQ). Đây là việc cần làm (`DefaultErrorHandler` + `DeadLetterPublishingRecoverer`).

## 7.7 Dead-letter

- face-worker: sau `MAX_ATTEMPTS` (3) lần lỗi hạ tầng hoặc khi nhận chuỗi không phải JSON, gửi nguyên message gốc vào `media.events.dlq` rồi phát `FACE_FAILED(PROCESSING_FAILED)` để ảnh bị `REJECTED` rõ ràng.
- Phát lại từ DLQ: xem runbook trong [11-observability-resilience.md](11-observability-resilience.md). Vì worker idempotent, phát lại message `PHOTO_UPLOADED` gốc vào `media.events` là an toàn (nhưng ảnh gốc đã bị xoá nên thường dẫn tới `RAW_MISSING`; người dùng cần upload lại).

## 7.8 Thêm một event mới

1. Thêm hằng số vào `EventTypes`, record payload vào `Events` (chỉ `publicId`/mã, không dữ liệu định danh), chọn topic (thêm vào `Topics` nếu cần).
2. Producer (service JPA): gọi `outbox.publish(...)` trong transaction nghiệp vụ. Chọn khoá message theo thực thể cần giữ thứ tự.
3. Consumer: thêm `case` vào listener của service, bọc `idempotency.firstTime` nếu service có DB.
4. Test: tạo envelope bằng `EventEnvelope.of(...)`, gọi `listener.onMessage(EventJson.write(env))`; kiểm tra gửi hai lần chỉ có tác dụng một lần.
5. Cập nhật bảng ở file này.
