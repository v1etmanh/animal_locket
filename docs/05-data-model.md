# 5. Mô hình dữ liệu

Nguồn: các file Flyway `src/main/resources/db/migration/V1__init.sql` và entity JPA của từng service. Quy ước chung:

- Mỗi service có DB riêng. Tham chiếu chéo service chỉ bằng `publicId` (`VARCHAR(20)`), **không có khoá ngoại giữa DB**.
- Thời gian lưu UTC: MySQL `DATETIME(6)`, PostgreSQL `TIMESTAMP(6) WITH TIME ZONE`.
- Enum lưu dạng chuỗi (`@Enumerated(STRING)`).
- Mọi service dùng JPA có thêm hai bảng chung của `libs/outbox-jpa`: `outbox_events`, `processed_events` (xem 5.6).
- Schema do **Flyway** quản lý. `spring.jpa.hibernate.ddl-auto` đọc biến `JPA_DDL_AUTO`: user/media/post mặc định **`none`**, billing (PostgreSQL) mặc định `validate`. Lý do: Hibernate 6.5 có thể kỳ vọng kiểu `ENUM` thay vì `VARCHAR` cho cột enum trên MySQL và làm schema validation thất bại. **Việc cần làm khi có Docker**: chạy MySQL thật với `JPA_DDL_AUTO=validate`; nếu lỗi thì gắn `@JdbcTypeCode(SqlTypes.VARCHAR)` cho các cột enum, rồi đổi mặc định về `validate`.

---

## 5.1 user-service — MySQL `user_db`

| Bảng | Cột chính | Ràng buộc / chỉ mục |
|---|---|---|
| `users` | `id` PK, `public_id` (20), `keycloak_sub` (100), `alias` (30), `lead_animal` (40), `avatar_key` (80, null chỉ với tài khoản xoá trước khi có avatar), `avatar_version`, `birth_date` (null sau khi xoá), `age_group` (`MINOR`/`ADULT`), `discoverable` (bit), `status` (`ACTIVE`/`SUSPENDED`/`DELETED`), `alias_changed_at`, `created_at` | UNIQUE `public_id`, UNIQUE `keycloak_sub`, UNIQUE `avatar_key` |
| `friendships` | `user_low`, `user_high`, `created_at` | UNIQUE `(user_low, user_high)`; luôn lưu `low < high` (so sánh chuỗi) |
| `friend_requests` | `from_id`, `to_id`, `source` (`SWIPE`/`INVITE`), `status` (`PENDING`/`ACCEPTED`/`DECLINED`/`CANCELED`), `created_at` | UNIQUE `(from_id, to_id)` — bản ghi cũ được tái dùng khi mời lại; INDEX `(to_id,status)`, `(from_id,created_at)` |
| `blocks` | `blocker_id`, `blocked_id`, `created_at` | UNIQUE `(blocker_id, blocked_id)`; INDEX `blocked_id` |
| `reports` | `reporter_id`, `target_public_id`, `target_type` (`USER`/`POST`/`COMMENT`/`MESSAGE`), `target_ref`, `reason`, `details` (500), `status` (`OPEN`/`ACTIONED`/`DISMISSED`) | INDEX `(status,created_at)`, `(reporter_id,created_at)` |
| `animals` | `code` PK, `name`, `rarity` (`COMMON`/`RARE`/`EPIC`), `pack_code` (null = bộ cơ bản) | Nạp idempotent khi khởi động (`AnimalCatalog`): 17 con cơ bản + gói `SAFARI` (4) + `OCEAN` (4) |
| `user_animals` | `public_id`, `animal_code`, `acquired_at` (legacy, không còn ghi khi đăng ký) | UNIQUE `(public_id, animal_code)` |
| `avatar_pool` | `avatar_key` PK ("fox:0:none"), `lib_version`, `owner_public_id` (đã gán thì không về null), `assigned_at` | INDEX `owner_public_id`. Seed lúc khởi động từ avatar-lib (docs/19) |
| `user_avatars` | `public_id`, `avatar_key`, `lib_version`, `source` (`REGISTER`/`BACKFILL`/`PURCHASE`/`ADMIN`), `source_ref`, `created_at` | UNIQUE `avatar_key` toàn bảng |
| `spin_log` | `public_id`, `animal_code`, `spun_at` | INDEX `(public_id, spun_at)` |
| `device_tokens` | `public_id`, `token` (255), `platform`, `updated_at` | UNIQUE `token` |
| `entitlements` | `public_id` PK, `plan`, `expires_at` | Bản sao quyền lợi Pro từ event billing |

Điểm riêng tư: `keycloak_sub` và `birth_date` **không** có trong DTO nào ra ngoài (trừ `/internal/identity/{sub}` trả `publicId` cho gateway).

## 5.2 media-service — MySQL `media_db`

| Bảng | Cột chính | Ghi chú |
|---|---|---|
| `media_jobs` | `id` (UUID), `owner_public_id`, `context` (`POST`/`CHAT`), `ref_id`, `raw_key`, `public_key`, `status` (`PENDING_UPLOAD`/`UPLOADED`/`READY`/`REJECTED`), `lead_animal`, `method` (`AI`/`STICKER`/`NONE`), `faces_detected`, `reject_reason`, `created_at`, `updated_at` | INDEX `owner_public_id`, `(status, updated_at)` |
| `owner_animals` | `public_id` PK, `lead_animal` | Bản sao từ `USER_REGISTERED`/`LEAD_ANIMAL_CHANGED` |

Mã `reject_reason` thường gặp: `FILE_TOO_LARGE`, `PROCESSING_TIMEOUT`, `UNREADABLE_IMAGE`, `IMAGE_TOO_LARGE`, `RAW_MISSING`, `PROCESSING_FAILED`.

## 5.3 post-service — MySQL `post_db`

| Bảng | Cột chính | Ràng buộc / chỉ mục |
|---|---|---|
| `posts` | `id` (UUID), `author_id`, `caption` (200), `media_id` (36), `public_key`, `status` (`PENDING_MEDIA`/`PUBLISHED`/`REJECTED`/`DELETED`), `reject_reason`, `like_count`, `comment_count`, `created_at`, `published_at` | UNIQUE `media_id`; INDEX `(author_id,status,published_at)`, `(status,created_at)` |
| `post_likes` | `post_id`, `user_id`, `created_at` | UNIQUE `(post_id,user_id)`; INDEX `user_id` |
| `comments` | `id` PK, `post_id`, `author_id`, `text` (300), `created_at` | INDEX `(post_id,id)`, `author_id` |
| `media_states` | `media_id` PK, `owner_id`, `status` (`READY`/`REJECTED`), `public_key`, `reason`, `updated_at` | Kết quả ảnh nhận từ media-service; cần vì `PHOTO_READY` có thể đến trước khi tạo bài |

`like_count`/`comment_count` được tăng/giảm bằng câu `UPDATE` nguyên tử (không đọc-rồi-ghi).

## 5.4 billing-service — PostgreSQL `billing_db`

| Bảng | Cột chính | Ràng buộc |
|---|---|---|
| `products` | `sku` PK, `type` (`SUBSCRIPTION`/`CONSUMABLE`/`PACK`), `item`, `quantity`, `active` | Seed trong migration: `animallocket.pro.month`, `.pro.year`, `.boost.1`, `.boost.5`, `.invite.1`, `.invite.5`, `.pack.safari`, `.pack.ocean` (trùng product id đăng ký trên store) |
| `purchases` | `id` PK, `store` (`APPLE`/`GOOGLE`/`DEV`), `store_transaction_id`, `original_transaction_id`, `public_id`, `sku`, `status` (`GRANTED`/`REFUNDED`), `created_at` | UNIQUE `(store, store_transaction_id)`; INDEX `public_id`. Sau khi xoá tài khoản `public_id` được ẩn danh (giữ bản ghi tài chính) |
| `subscriptions` | `id` PK, `public_id`, `sku`, `store`, `original_transaction_id`, `status` (`ACTIVE`/`EXPIRED`), `expires_at`, `updated_at` | UNIQUE `(store, original_transaction_id)`; INDEX `public_id`, `(status,expires_at)` |
| `wallet_balances` | PK `(public_id, item)`, `balance` | `CHECK (balance >= 0)` |
| `wallet_ledger` | `id` PK, `public_id`, `item`, `delta`, `reason` (`PURCHASE`/`CONSUME`/`REFUND`), `ref`, `created_at` | UNIQUE `(reason, ref, item)` — cộng/trừ cùng một sự kiện hai lần là không thể |
| `webhook_events` | `id` PK (id thông báo của store), `store`, `type`, `received_at` | Khử trùng lặp webhook |

Số dư đổi bằng `UPDATE ... WHERE balance >= n` nguyên tử, kèm một dòng sổ cái. Vật phẩm mua lẻ: `BOOST`, `PRIORITY_INVITE`. `PACK` không có số dư trong billing: quyền sở hữu con vật nằm ở user-service (qua event `CONSUMABLE_GRANTED` `item=ANIMAL_PACK:<mã>`).

> Lưu ý nhỏ: `PRIORITY_INVITE` mua được và có số dư, nhưng hiện **chưa có chức năng nào tiêu thụ** (chưa có endpoint "lời mời ưu tiên" ở user-service).

## 5.5 chat-service — MongoDB `chat_db`

**`conversations`**

| Trường | Ý nghĩa |
|---|---|
| `_id` | ObjectId |
| `key` | `"idThấp:idCao"`, **chỉ mục duy nhất** — mỗi cặp một hội thoại |
| `participants` | `[a, b]` đã sắp xếp, có chỉ mục |
| `status` | `ACTIVE` / `CLOSED` |
| `closedReason` | `BLOCKED`... |
| `createdAt`, `lastMessageAt` | |
| `lastReadAt` | map `publicId → Instant` (mốc đã đọc) |

**`messages`**: `_id`, `conversationId`, `senderId`, `type` (`TEXT`/`IMAGE`), `text`, `mediaId`, `createdAt`. Chỉ mục ghép `conv_created` = `{conversationId:1, createdAt:-1}`. `auto-index-creation: true`.

Lưu ý: MongoDB lưu thời gian ở độ phân giải **mili-giây**; mốc đọc vì thế dùng thời điểm của tin mới nhất thực sự đã đọc, và mặc định "chưa đọc từ EPOCH".

## 5.6 Bảng chung của Outbox (mọi service JPA)

| Bảng | Cột | Ghi chú |
|---|---|---|
| `outbox_events` | `id` (= `eventId`), `topic`, `event_key`, `type`, `payload` (TEXT, JSON của envelope), `created_at`, `published_at` | INDEX `(published_at, created_at)`; dòng đã đẩy bị dọn sau 1 ngày |
| `processed_events` | `event_id` PK, `processed_at` | Khử trùng lặp consumer. **Chưa có cơ chế dọn** — cần job xoá bản ghi cũ (ví dụ > 30 ngày) khi lên production |

## 5.7 Redis

Hai nhóm: khoá qua `KeyValueStore` (hạn mức, cache) và cấu trúc riêng của discovery. Ngày trong khoá hạn mức tính theo giờ Việt Nam (`Asia/Ho_Chi_Minh`), định dạng `yyyyMMdd`.

| Khoá | Kiểu | TTL | Service | Ý nghĩa |
|---|---|---|---|---|
| `quota:photo:{id}:{yyyyMMdd}` | counter | 30 giờ | post | Số ảnh đã đăng hôm nay |
| `quota:swipe:{id}:{yyyyMMdd}` | counter | 30 giờ | discovery | Số lượt quẹt phải hôm nay |
| `pro:{id}` | string | đến hạn thuê bao (tối đa 400 ngày) | post, discovery | Bản sao trạng thái Pro |
| `friends:{id}` | CSV | 45 giây | post | Danh sách bạn (tươi) |
| `friends:stale:{id}` | CSV | 1 giờ | post | Bản dự phòng khi user-service lỗi |
| `rl:cards:{id}:{epochMinute}` | counter | 2 phút | discovery | Giới hạn 10 lần tìm/phút |
| `chat:rl:{id}:{epoch/10s}` | counter | 30 giây | chat | Giới hạn 20 tin/10 giây |
| `chat:rel:{a}:{b}` | `ok`/`no` | 30 giây | chat | Cache quan hệ bạn bè/chặn |
| `chat:conn:{id}` | string | 90 giây | chat | Đang có kết nối WebSocket |
| `geo:{MINOR\|ADULT}` | GEO | — | discovery | Vị trí đã làm nhiễu của từng người |
| `geo:exp:{ageGroup}` | ZSET | — | discovery | `score` = thời điểm hết hạn (giây); job dọn xoá member hết hạn khỏi GEO |
| `online:{ageGroup}` | ZSET | — | discovery | `score` = lần heartbeat cuối; "online" = trong 60 giây |
| `boost` | ZSET | — | discovery | `score` = thời điểm hết Boost |
| `swipe:left:{me}` | ZSET | 35 ngày | discovery | Người đã quẹt trái (nhớ 30 ngày) |
| `swipe:right:{me}` | SET | 35 ngày | discovery | Người đã quẹt phải |
| `chat:user:{id}` | pub/sub | — | chat | Kênh phân phối tin tới người dùng |
| `request_rate_limiter.*` | Spring Cloud Gateway | — | gateway | Token bucket của `RequestRateLimiter` |

`geo:*`, `geo:exp:*`, `online:*` tách theo nhóm tuổi để người lớn và người dưới 18 **không bao giờ thấy nhau**.

## 5.8 MinIO

| Bucket | Khoá | Nội dung | Vòng đời |
|---|---|---|---|
| `raw` (private) | `{mediaId}.{jpg\|png\|webp\|heic}` | Ảnh gốc người dùng upload | Xoá ngay khi xử lý thành công; `MediaJanitor` xoá mọi object cũ hơn **1 giờ** (quét mỗi 10 phút); không sao lưu |
| `public` (private, **không** public-read) | `pub/{mediaId}.jpg` | Ảnh đã ẩn mặt, đã xoá EXIF, kèm metadata `x-amz-meta-method`, `x-amz-meta-faces` | Chỉ phát qua URL ký sẵn 10 phút sau khi kiểm tra bạn bè; xoá khi chủ tài khoản bị xoá |

Cả hai bucket do `MinioObjectStorage` tự tạo lúc khởi động nếu chưa có. MinIO lifecycle tối thiểu 1 ngày nên cam kết "tối đa 1 giờ" do `MediaJanitor` thực hiện, không phải lifecycle rule.

## 5.9 Bảng tóm tắt lưu giữ dữ liệu

| Dữ liệu | Thời gian giữ | Cơ chế |
|---|---|---|
| Ảnh gốc | ≤ 1 giờ (xoá ngay sau xử lý) | worker + `MediaJanitor` |
| Vị trí đã làm nhiễu | 30 phút kể từ lần cập nhật cuối | `geo:exp` + job purge 60 giây |
| Lượt quẹt trái | 30 ngày (key 35 ngày) | Redis TTL |
| `outbox_events` đã đẩy | 1 ngày | `OutboxRelay.cleanup` |
| `processed_events` | **chưa dọn** | cần bổ sung |
| Tin nhắn | đến khi xoá tài khoản | chưa có chính sách hết hạn |
| `reports` | giữ lại cả khi xoá tài khoản | quyết định an toàn/pháp lý, cần chốt thời hạn |
| `purchases` | giữ, ẩn danh `public_id` khi xoá tài khoản | nghĩa vụ kế toán |
