# Glyph Chat Mobile Requirements

## 1. Mục tiêu

Flutter mobile phải hỗ trợ:

- Bộ từ điển hệ thống.
- Bộ từ điển cá nhân lưu local bằng SQLite.
- Bộ từ điển hội thoại được mirror từ server.
- Vẽ và nhận diện ký hiệu một nét trên thiết bị.
- Ghép nhiều glyph thành message.
- Đồng bộ offline, retry và phục hồi sau app restart.

Chức năng phải giữ nguyên luồng `TEXT`, `IMAGE`, ack, retry, read receipt và closed conversation hiện tại.

## 2. Nguồn dữ liệu

| Loại | Nguồn chuẩn | Offline | Đồng bộ thiết bị khác |
|---|---|---|---|
| System glyph | Asset ứng dụng | Có | Theo phiên bản app |
| Personal glyph | SQLite theo account | Có | Không trong MVP |
| Conversation glyph | Server, SQLite là mirror | Đọc được cache | REST delta sync |
| Pending mutation | SQLite outbox | Có | Không |
| Pending message | SQLite chat outbox | Có | Không |

## 3. Cấu trúc feature

```text
lib/features/chat/
  data/
    glyph_database.dart
    glyph_local_data_source.dart
    glyph_remote_data_source.dart
    glyph_sync_service.dart
    glyph_repository_impl.dart
  domain/
    glyph.dart
    glyph_repository.dart
    glyph_recognizer.dart
    glyph_point_codec.dart
    glyph_message.dart
  presentation/
    glyph_dictionary_controller.dart
    glyph_composer_controller.dart
    glyph_sync_controller.dart
    widgets/
      glyph_drawing_pad.dart
      glyph_token.dart
      glyph_message_bubble.dart
      glyph_dictionary_sheet.dart
```

## 4. SQLite schema

Database hiện tại phải nâng từ version 1 lên version 2 bằng `onUpgrade`. Không xóa bảng `cache_entries` hiện có.

### 4.1 `glyph_library`

```sql
CREATE TABLE glyph_library (
  local_id TEXT PRIMARY KEY,
  account_public_id TEXT,
  kind TEXT NOT NULL,
  meaning TEXT NOT NULL,
  color_argb INTEGER NOT NULL,
  points_blob BLOB NOT NULL,
  shape_hash TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  last_used_at INTEGER
);
```

`kind` nhận `SYSTEM` hoặc `PERSONAL`.

### 4.2 `conversation_glyphs`

```sql
CREATE TABLE conversation_glyphs (
  server_id TEXT PRIMARY KEY,
  account_public_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL,
  creator_public_id TEXT NOT NULL,
  source_local_id TEXT,
  meaning TEXT NOT NULL,
  color_argb INTEGER NOT NULL,
  points_blob BLOB NOT NULL,
  shape_hash TEXT NOT NULL,
  status TEXT NOT NULL,
  server_revision INTEGER NOT NULL,
  hidden_locally INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

Index bắt buộc:

```sql
CREATE INDEX idx_conv_glyph_active
ON conversation_glyphs(account_public_id, conversation_id, status);

CREATE INDEX idx_conv_glyph_revision
ON conversation_glyphs(account_public_id, conversation_id, server_revision);
```

### 4.3 `glyph_sync_state`

```sql
CREATE TABLE glyph_sync_state (
  account_public_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL,
  last_revision INTEGER NOT NULL DEFAULT 0,
  last_synced_at INTEGER,
  PRIMARY KEY(account_public_id, conversation_id)
);
```

### 4.4 `glyph_mutation_outbox`

```sql
CREATE TABLE glyph_mutation_outbox (
  operation_id TEXT PRIMARY KEY,
  account_public_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL,
  action TEXT NOT NULL,
  local_glyph_id TEXT,
  server_glyph_id TEXT,
  payload_json TEXT,
  state TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  next_attempt_at INTEGER,
  last_error_code TEXT,
  created_at INTEGER NOT NULL
);
```

### 4.5 `chat_outbox`

```sql
CREATE TABLE chat_outbox (
  client_id TEXT PRIMARY KEY,
  account_public_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL,
  message_type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  state TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  next_attempt_at INTEGER,
  created_at INTEGER NOT NULL
);
```

## 5. Point codec

- Mỗi glyph chuẩn hóa thành đúng 64 điểm.
- Mỗi tọa độ lượng tử hóa về `int16` trong miền `-1000..1000`.
- `points_blob` chứa 128 số `int16`, khoảng 256 byte mỗi glyph.
- Byte order phải cố định và có unit test round trip.
- Decoder phải từ chối blob sai chiều dài hoặc dữ liệu lỗi.

## 6. Nhận diện một nét

Pipeline:

1. Thu điểm từ `Listener` hoặc `GestureDetector`.
2. Loại điểm quá gần nhau để giảm nhiễu.
3. Resample thành 64 điểm theo độ dài cung.
4. Scale theo cạnh lớn nhất để giữ tỷ lệ hình.
5. Dịch centroid về gốc.
6. So sánh path distance với dictionary.
7. So sánh cả chiều vẽ thuận và đảo.
8. Cho phép lệch góc khoảng 22 độ.

Quy tắc kết quả:

| Điều kiện | Hành vi |
|---|---|
| Score dưới `0.75` | Không nhận diện, cho vẽ lại hoặc tạo glyph mới |
| Score từ `0.75` và không mơ hồ | Đề xuất glyph để thêm vào composer |
| Hai kết quả chênh dưới `0.05` | Hiện lựa chọn, không tự quyết định |
| Glyph mới giống glyph cũ từ `0.85` | Cảnh báo collision |

Không tự gửi message ngay sau khi nhận diện.

## 7. Bộ từ điển cá nhân

Người dùng phải có thể:

- Tạo glyph bằng một nét.
- Nhập nghĩa tối đa 64 ký tự.
- Chọn màu từ palette cố định.
- Sửa hoặc xóa glyph cá nhân chưa chia sẻ.
- Xem cảnh báo khi hình quá giống glyph đã có.
- Dùng glyph personal khi offline.
- Xuất bản glyph vào một conversation.

Khi xuất bản:

1. Tạo `operationId` UUID.
2. Ghi `PUBLISH` vào `glyph_mutation_outbox` trong transaction.
3. Gửi API với `operationId` làm `clientMutationId`.
4. Upsert response vào `conversation_glyphs`.
5. Xóa outbox row sau khi transaction local thành công.

Glyph personal không tự động đồng bộ sang thiết bị khác trong MVP.

## 8. Đồng bộ conversation dictionary

Khi mở conversation:

1. Đọc SQLite và hiển thị ngay.
2. Đọc `last_revision`.
3. Gọi API với `afterRevision`.
4. Upsert cả `ACTIVE` và `ARCHIVED` trong một transaction.
5. Chỉ cập nhật checkpoint sau khi ghi thành công.
6. Lặp tiếp nếu `hasMore=true`.

Phải chạy delta sync khi:

- Mở conversation.
- Nhận `dictionary_changed`.
- WebSocket reconnect.
- Ứng dụng trở lại foreground.
- Message chứa glyph chưa có ở local.

Các trigger đồng thời phải dùng single-flight hoặc debounce để tránh gọi API trùng.

## 9. Gửi message glyph

Luồng gửi:

1. Composer giữ tối đa 12 glyph theo đúng thứ tự.
2. Personal glyph chưa có `serverId` phải được publish trước.
3. Tạo `clientId` UUID.
4. Ghi `chat_outbox` trước khi gửi mạng.
5. Thêm optimistic message trạng thái `pending`.
6. Gửi WebSocket khi connected, nếu không dùng REST.
7. Khi nhận ack hoặc REST `201`, thay temp ID và xóa outbox row.

Retry:

- Network, timeout và 5xx được retry bằng backoff.
- `CHAT_RATE_LIMIT` giữ nguyên composer và đợi trước khi retry.
- `GLYPH_NOT_ACTIVE` phải sync lại dictionary, không gửi lại tự động.
- `FORBIDDEN` hoặc conversation `closed` phải dừng worker và khóa composer.
- Nếu backend chưa idempotent theo `clientId`, chỉ retry tự động một lần để giảm nguy cơ gửi trùng.

Backoff đề xuất:

```text
1s -> 2s -> 4s -> 8s -> 30s -> 60s
```

## 10. Giao diện

Conversation screen phải có:

- Nút chuyển sang glyph mode.
- Drawing pad một nét.
- Kết quả nhận diện và trường hợp mơ hồ.
- Dải glyph chọn nhanh.
- Composer token theo thứ tự.
- Xóa từng token và xóa toàn bộ.
- Dictionary sheet gồm System, Personal và Conversation.
- Builder tạo glyph cá nhân.
- Bubble `GLYPH` với chế độ hiện hoặc ẩn nghĩa.
- Pending, failed và retry state.
- Fallback text khi thiếu glyph.

Mọi màn phải có loading, empty, error và success state phù hợp.

Mọi icon-only control phải:

- Có vùng chạm tối thiểu `44 x 44` logical pixels.
- Có `Semantics` tiếng Việt.
- Có tooltip tiếng Việt khi phù hợp.

## 11. Riverpod

Provider đề xuất:

```text
personalGlyphsProvider(accountId)
conversationGlyphsProvider(conversationId)
glyphRecognizerProvider(conversationId)
glyphComposerProvider(conversationId)
glyphSyncProvider(conversationId)
glyphOutboxWorkerProvider(accountId)
chatOutboxWorkerProvider(accountId)
```

Yêu cầu:

- Database dùng một connection cấp ứng dụng.
- Hủy stream subscription và timer trong `ref.onDispose`.
- Không mở database mới cho mỗi conversation.
- Không đặt storage, recognition và sync logic trực tiếp trong widget.

## 12. Tài khoản và riêng tư

- Mọi row cá nhân phải gắn `account_public_id`.
- Mọi query phải lọc theo account hiện tại.
- Đăng xuất hoặc xóa tài khoản phải xóa glyph, sync state và outbox của account.
- Không lưu token hoặc signed URL trong SQLite.
- Không log meaning, points, `glyphIds`, fallback hoặc nội dung chat.
- Không render SVG hoặc HTML từ server.
- Loại database chat khỏi Android Auto Backup.
- Cấu hình file protection phù hợp trên iOS.
- `sqflite` không mã hóa database; SQLCipher là hạng mục riêng nếu threat model yêu cầu.

## 13. ARB và lỗi

- Tất cả chuỗi giao diện mới phải nằm trong ARB.
- Lỗi API chỉ map theo stable `code`.
- Bổ sung message tiếng Việt cho toàn bộ `GLYPH_*` code.
- Không hiển thị trực tiếp trường `detail` từ RFC 7807.
- Không làm mất composer khi gửi thất bại hoặc gặp rate limit.

## 14. Kiểm thử bắt buộc

- Unit test point codec và blob lỗi.
- Unit test resample, normalize, reverse stroke và thresholds.
- SQLite migration test từ version 1 lên version 2.
- Account isolation test.
- Seed system dictionary idempotency test.
- Delta sync, pagination, tombstone và checkpoint test.
- Outbox restart, backoff và retry policy test.
- Controller test optimistic, ack, REST fallback và closed state.
- Widget test loading, empty, error, success và unknown glyph.
- Accessibility test tap target và Semantics.
- Integration test hai thiết bị, offline, reconnect và archive.

Trước handoff phải chạy:

```text
flutter analyze
flutter test
```

## 15. Feature flags

```text
GLYPH_READ_ENABLED
GLYPH_PERSONAL_LIBRARY_ENABLED
GLYPH_PUBLISH_ENABLED
GLYPH_SEND_ENABLED
```

Thứ tự rollout:

1. Bật read path.
2. Bật personal library.
3. Bật publish.
4. Bật send.

Khi rollback phải giữ read path để lịch sử không bị hỏng.

## 16. Tiêu chí hoàn thành

- Personal dictionary hoạt động offline và còn nguyên sau app restart.
- Migration không làm mất `cache_entries` hiện tại.
- Không trộn dữ liệu giữa các tài khoản.
- Recognizer xử lý chiều vẽ đảo và trường hợp mơ hồ.
- Delta sync phục hồi sau khi bỏ lỡ WebSocket event.
- Pending mutation và message sống qua app restart.
- Unknown hoặc archived glyph vẫn có fallback dễ hiểu.
- Tất cả trạng thái UI và accessibility requirements đạt.
- Không có dữ liệu nhạy cảm trong log.
- `flutter analyze` và `flutter test` thành công.

