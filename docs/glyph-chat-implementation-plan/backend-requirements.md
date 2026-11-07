# Glyph Chat Backend Requirements

## 1. Mục tiêu

Chat service phải hỗ trợ:

- Từ điển ký hiệu dùng chung theo từng hội thoại.
- Tin nhắn loại `GLYPH` chứa danh sách `glyphIds`.
- Đồng bộ từ điển bằng REST và thông báo thay đổi bằng WebSocket.
- Giữ tương thích với client cũ bằng `text` fallback do server tạo.
- Không thay đổi cơ chế xác thực hiện tại: JWT và `X-Public-Id` do gateway gắn.

## 2. Quyết định kiến trúc

- Chat service là nguồn dữ liệu chuẩn cho glyph đã chia sẻ.
- MongoDB lưu glyph, revision và tin nhắn `GLYPH`.
- Redis Pub/Sub chỉ phát thông báo realtime, không phải nguồn đồng bộ bền vững.
- REST delta sync là cơ chế khôi phục sau offline hoặc mất sự kiện WebSocket.
- Glyph đã xuất bản là bất biến. Muốn đổi hình hoặc nghĩa phải tạo glyph mới.
- Archive là xóa mềm để tin nhắn cũ vẫn hiển thị chính xác.
- Server không nhận SVG, HTML hoặc ảnh Base64 của glyph.

## 3. Mô hình dữ liệu

### 3.1 Collection `conversation_glyphs`

```text
id                  String
conversationId      String
creatorPublicId     String
clientMutationId    UUID String
meaning             String
color               String
normalizedPoints    Integer[128]
shapeHash           String
status              ACTIVE | ARCHIVED
revision            Long
createdAt           Instant
archivedAt          Instant nullable
```

Yêu cầu index:

```text
UNIQUE conversationId + creatorPublicId + clientMutationId
INDEX  conversationId + revision
INDEX  conversationId + status
INDEX  conversationId + shapeHash
```

### 3.2 Mở rộng `conversations`

Thêm:

```text
glyphRevision Long default 0
```

Mỗi lần tạo hoặc archive glyph phải tăng `glyphRevision` bằng thao tác nguyên tử.

### 3.3 Mở rộng `messages`

```text
type                 TEXT | IMAGE | GLYPH
glyphIds             String[] nullable
dictionaryRevision   Long nullable
```

Với tin `GLYPH`, trường `text` phải chứa fallback do server tạo từ nghĩa của các glyph. Client không được tự gửi fallback.

## 4. REST API

### 4.1 Đồng bộ từ điển

```http
GET /api/v1/chat/conversations/{conversationId}/glyphs
    ?afterRevision=0
    &limit=100
```

Response:

```json
{
  "conversationId": "conv-1",
  "revision": 29,
  "items": [],
  "hasMore": false,
  "nextAfterRevision": 29
}
```

Yêu cầu:

- `limit` từ 1 đến 100.
- Trả cả glyph `ACTIVE` và tombstone `ARCHIVED` sau `afterRevision`.
- Sắp xếp tăng dần theo `revision`.
- Chỉ participant của conversation được truy cập.

### 4.2 Lấy glyph bị thiếu

```http
GET /api/v1/chat/conversations/{conversationId}/glyphs/{glyphId}
```

Dùng khi message đến trước khi client kịp đồng bộ từ điển.

### 4.3 Xuất bản glyph

```http
POST /api/v1/chat/conversations/{conversationId}/glyphs
```

Request:

```json
{
  "clientMutationId": "uuid-v4",
  "meaning": "Đi cà phê không?",
  "color": "#F472B6",
  "points": [120, -45, 118, -40],
  "pointCount": 64
}
```

Yêu cầu:

- `clientMutationId` bảo đảm idempotency.
- Request lặp lại phải trả đúng glyph cũ và không tăng revision lần hai.
- Server tự canonicalize points và tính `shapeHash`.
- Không tin `shapeHash` do client gửi.
- Response `201` khi tạo mới, `200` khi trả kết quả idempotent.

### 4.4 Archive glyph

```http
DELETE /api/v1/chat/conversations/{conversationId}/glyphs/{glyphId}
```

Yêu cầu:

- Chỉ người tạo glyph được archive.
- Lần gọi lặp lại vẫn trả `204`.
- Không xóa `meaning` và `normalizedPoints`.
- Tăng revision và phát sự kiện `dictionary_changed`.

### 4.5 Gửi tin glyph bằng REST

```http
POST /api/v1/chat/conversations/{conversationId}/messages
```

```json
{
  "type": "GLYPH",
  "glyphIds": ["glyph-101", "glyph-205"],
  "clientId": "uuid-v4"
}
```

Server phải:

- Kiểm tra glyph thuộc đúng conversation.
- Kiểm tra glyph đang `ACTIVE`.
- Giữ nguyên thứ tự `glyphIds`.
- Tạo `text` fallback từ `meaning`.
- Lưu `dictionaryRevision`.
- Khuyến nghị unique index `senderId + clientId` để retry message không gửi trùng.

## 5. WebSocket

### 5.1 Gửi tin glyph

```json
{
  "type": "send",
  "conversationId": "conv-1",
  "messageType": "GLYPH",
  "glyphIds": ["glyph-101", "glyph-205"],
  "clientId": "uuid-v4"
}
```

Ack giữ contract hiện tại:

```json
{
  "type": "ack",
  "data": {
    "clientId": "uuid-v4",
    "messageId": "message-1"
  }
}
```

### 5.2 Thay đổi từ điển

```json
{
  "type": "dictionary_changed",
  "data": {
    "conversationId": "conv-1",
    "revision": 29,
    "glyphId": "glyph-101",
    "change": "UPSERT"
  }
}
```

Client nhận sự kiện này phải chạy REST delta sync. Không gửi toàn bộ dictionary trong WebSocket frame.

## 6. Validation và giới hạn

| Yêu cầu | Giới hạn |
|---|---:|
| Số điểm | Đúng 64 cặp, 128 số nguyên |
| Miền tọa độ | `-1000..1000` |
| Nghĩa glyph | 1 đến 64 ký tự |
| Glyph active | Tối đa 100 mỗi conversation |
| Glyph trong một message | 1 đến 12 |
| Tạo glyph | Tối đa 20 mỗi ngày mỗi user |
| WebSocket frame | Giữ giới hạn 16 KB hiện tại |

Màu phải thuộc palette cấu hình trên server.

## 7. Mã lỗi

| Code | HTTP | Ý nghĩa |
|---|---:|---|
| `GLYPH_INVALID_POINTS` | 400 | Sai số lượng hoặc miền tọa độ |
| `GLYPH_INVALID_COLOR` | 400 | Màu không hợp lệ |
| `GLYPH_DUPLICATE` | 409 | Hình canonical đã tồn tại |
| `GLYPH_LIMIT` | 409 | Đã đạt giới hạn dictionary |
| `GLYPH_NOT_FOUND` | 404 | Không tìm thấy glyph trong conversation |
| `GLYPH_NOT_ACTIVE` | 409 | Glyph đã archived |
| `GLYPH_NOT_OWNER` | 403 | Không có quyền archive |
| `GLYPH_SEQUENCE_TOO_LONG` | 400 | Message có quá nhiều glyph |
| `INVALID_GLYPH_MESSAGE` | 400 | Payload message không hợp lệ |
| `GLYPH_CREATE_RATE_LIMIT` | 429 | Vượt hạn mức tạo glyph |

Mọi lỗi phải theo RFC 7807 và client chỉ map theo `code`.

## 8. Bảo mật và riêng tư

- Chỉ participant của conversation được đọc hoặc thay đổi dictionary.
- Phải kiểm tra friendship và blocked như luồng chat hiện tại.
- Không tin `X-Public-Id` từ client trực tiếp.
- Không log `meaning`, points, `glyphIds`, fallback text, JWT hoặc nội dung chat.
- Không nhận hoặc render SVG và HTML.
- `USER_DELETED` phải xóa glyph theo chính sách xóa conversation hiện tại.
- `BLOCKED` và `UNFRIENDED` phải chặn create, archive và send.

## 9. Tương thích

- `TEXT` và `IMAGE` không thay đổi contract.
- Message `GLYPH` luôn trả `text` fallback để client cũ vẫn đọc được.
- Backend phải được deploy trước mobile send feature.
- Rollback phải tắt create và send nhưng vẫn giữ read path cho lịch sử.

## 10. Kiểm thử bắt buộc

- Unit test point validation, canonical hash và fallback text.
- Repository test revision, tombstone và idempotency.
- REST integration test create, retry, sync, archive và permissions.
- WebSocket test send, ack, error và `dictionary_changed`.
- Concurrency test hai create trùng nhau.
- Compatibility test với `TEXT`, `IMAGE` và client cũ.
- Security test conversation khác, spoof ID và payload độc hại.
- Multi-instance test qua Redis Pub/Sub.

## 11. Tiêu chí hoàn thành

- Create retry không tạo glyph trùng.
- Delta sync phục hồi đầy đủ sau offline.
- Archive không làm hỏng message lịch sử.
- Tin `GLYPH` có `glyphIds` và fallback do server tạo.
- Client cũ vẫn hiện được fallback text.
- Mọi lỗi có stable code.
- Không có dữ liệu nhạy cảm trong log.
- Toàn bộ test chat-service và contract test đạt.

