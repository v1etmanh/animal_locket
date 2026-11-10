# 19. Cơ chế avatar con vật

> Trạng thái: **đã triển khai phần cơ chế avatar** (2026-11-08): thư viện v1, kho + cấp phát duy nhất, cấp cho tài khoản cũ, hiển thị trên mobile. 2026-11-09: thư viện **v2 origami** (vẽ lại cùng bộ khoá, ADR-015), app vẽ mọi avatar bằng v2. Nạp tiền & hạn mức (§8) chưa làm. Chưa chạy thử với MySQL thật (test dùng H2).
>
> Mã nguồn chính: `libs/avatar-lib/build-lib.mjs` (sinh thư viện từ `lib-v1.mjs`, `lib-v2.mjs`; tự kiểm bằng `check.mjs`), user-service `AvatarLibrary`, `AvatarPoolSeeder`, `AvatarAllocator`, `AvatarBackfill`, `AvatarService`; mobile `lib/core/avatar/`, `AnimalAvatar`.

## 0. Quyết định đã chốt (2026-11-08)

| # | Quyết định |
| --- | --- |
| 1 | Phụ kiện tính cả lựa chọn "không phụ kiện": **50 con vật × 10 màu × 6 phụ kiện = 3.000 avatar** (thư viện v1). |
| 2 | **Không có hai người trùng avatar.** Mỗi avatar thuộc về **tối đa một người** trên toàn hệ thống, server kiểm tra và cơ sở dữ liệu chặn cứng. |
| 3 | Khi đăng ký: **quay đúng 1 lần**, không quay lại. |
| 4 | Avatar quay được (sau này, khi nạp tiền) **nằm trong bộ sưu tập** của người đó và vẫn là của riêng họ, không ai khác nhận được. |
| 5 | **Nạp tiền** (quay thêm, tăng cấp) và **bảng hạn mức** (ảnh/ngày, bạn tối đa): **làm sau**, tài liệu chỉ để chỗ (§8). |
| 6 | Mở rộng kho (thêm con vật/màu/chiều mới): **làm sau**, khi kho chạm ngưỡng cảnh báo. |
| 7 | Xoá tài khoản: **avatar không bao giờ được thu hồi**, vẫn gắn vĩnh viễn với tài khoản đã xoá. |
| 8 | Tài khoản cũ (đang có `lead_animal` trùng nhau): **giữ lại**, mỗi tài khoản được **cấp ngẫu nhiên một avatar mới duy nhất** từ kho (§5), giống người đăng ký mới. |

## 1. Bài toán

- Mỗi người dùng có một avatar con vật **độc nhất**, gắn với tài khoản. Đây là thứ người khác thấy khi quẹt thẻ khám phá, xem bài đăng, chat, nên nó chính là "mặt" của người dùng.
- Avatar được ghép từ thư viện: con vật × bảng màu × phụ kiện (theo file HTML mẫu).

## 2. Hiện trạng trong code (điểm xuất phát)

| Nơi | Hiện có |
| --- | --- |
| user-service `users.lead_animal` | Mã con vật chủ đạo, chọn bằng `AnimalCatalog.randomStarter()` khi `register()`. **Nhiều người trùng nhau.** |
| `animals`, `user_animals` | Danh mục con vật + bộ sưu tập theo con vật (không có màu/phụ kiện). |
| `PUT /users/me/lead-animal` | Chỉ Pro, đổi sang con đã sở hữu; phát `LEAD_ANIMAL_CHANGED`. |
| discovery / post / media | Nhận `leadAnimal` qua API nội bộ hoặc event `USER_REGISTERED` / `LEAD_ANIMAL_CHANGED`. |
| Mobile `AnimalAvatar` | Chỉ vẽ **emoji** + màu pastel; `AnimalAssetResolver` map khoảng 9 mã sang emoji. |

Hướng làm: **mở rộng `lead_animal` thành avatar đầy đủ, được cấp phát từ một kho avatar có chủ duy nhất**, tái dùng outbox/event sẵn có.

## 3. Mô hình avatar

### 3.1. Avatar là một bộ mã, không phải ảnh

Không lưu file PNG/SVG cho từng người. Avatar là một bộ giá trị:

```json
{ "v": 1, "animal": "fox", "palette": 0, "accessory": "none" }
```

Có hai loại khoá, đừng nhầm:

- **Khoá nhận dạng (`avatar_key`)** = `animal:palette:accessory`, ví dụ `fox:0:none`. Đây là **thứ phải duy nhất**: hai người khác nhau không bao giờ có cùng `avatar_key`.
- **Phiên bản thư viện (`v`)**: chỉ cho biết cần thư viện nào để vẽ. **Không** nằm trong khoá duy nhất. Lý do: nếu v2 vẫn có `fox`, màu 0, không phụ kiện thì nhìn giống hệt v1; đưa `v` vào khoá sẽ cho phép hai người "khác mã nhưng giống hình".

Chuỗi truyền giữa các service: `1:fox:0:none` (`v:avatar_key`).

### 3.2. Thư viện (`avatar-lib`)

JSON chứa 50 mẫu SVG có chỗ trống màu `{{tên}}`, 10 bảng màu, 6 phụ kiện. v1 dùng `{{fur}}`, `{{belly}}`, `{{accent}}` (đúng như `lib` trong file HTML mẫu); v2 origami thêm sắc độ tính sẵn `furD`, `furL`, `bellyD`, `accentD`, `accentL` vào mỗi bảng màu, giữ nguyên 4 màu gốc.

Quy tắc bất biến:

1. File của một phiên bản đã phát hành **không bao giờ đổi**: sinh lại phải trùng từng byte (`check.mjs` so với bản trong git). Server và app cũ vẫn vẽ theo nó.
2. **Bộ khoá không bao giờ mất và không đổi ý nghĩa**: `fox:0:none` luôn là con cáo, bảng màu 0, không phụ kiện. Phiên bản mới phải chứa mọi khoá cũ và chỉ được **thêm** khoá (con vật, màu, phụ kiện, hoặc một chiều mới). Nhờ vậy `avatar_key` cũ vẫn hợp lệ, và tính duy nhất vẫn đúng qua các phiên bản.
3. Phiên bản mới **được vẽ lại** hình của khoá cũ (đổi phong cách, ví dụ v2 origami), nhưng hai khoá khác nhau phải vẫn phân biệt được bằng mắt. App vẽ mỗi mã bằng **thư viện mới nhất có khoá đó**, không theo số phiên bản trong mã (ADR-015).
4. Hàm vẽ là hàm thuần `render(lib, key) → svg`: nền `bg` → thân → phụ kiện, mọi chỗ trống `{{tên}}` lấy màu cùng tên trong bảng màu. JS (`build-lib.mjs`) và Dart phải ra cùng chuỗi (mẫu đối chiếu `mobile/test/fixtures/avatar-lib.vN.samples.json`).

| Bản | Vị trí | Mục đích |
| --- | --- | --- |
| Nguồn gốc | `libs/avatar-lib/avatar-lib.v1.json`, `avatar-lib.v2.json` | Một nguồn duy nhất cho server và mobile. Mỗi khoá thuộc phiên bản đầu tiên có nó (hiện tại đều là v1). |
| Server | user-service đọc từ classpath | Sinh kho avatar, kiểm tra mã hợp lệ. |
| Mobile | `mobile/assets/avatar/avatar-lib.v2.json` (chỉ bản mới nhất) | Vẽ được ngay, không cần mạng; mã `1:…` cũng vẽ bằng v2. |
| Bản mới | `GET /api/v1/animals/avatar-lib/{v}` (cần đăng nhập, `Cache-Control: immutable`, có `ETag`) | App gặp mã có khoá mà không thư viện nào trên máy có thì tải đúng phiên bản trong mã một lần, lưu file trong thư mục support của app. |

### 3.3. Cơ chế render: từ bộ mã ra hình

**Không có file ảnh nào cho từng avatar.** Cả 3.000 hình đều được ghép tại chỗ từ thư viện (vài chục mảnh SVG). Mỗi lần cần hiển thị:

```text
avatar {animal:"fox", palette:0, accessory:"glasses"}
   │
   ├─1. animals["fox"].svg          → khung con vật, màu còn là chỗ trống:
   │                                   <ellipse ... fill="{{fur}}"/> ... fill="{{belly}}" ...
   ├─2. palettes[0]                 → {fur:#E8702A, belly:#FFF1DE, accent:#7A3511, bg:#FFE4C4}
   │                                   thay {{fur}} {{belly}} {{accent}} bằng mã màu
   ├─3. accessories["glasses"].svg  → mảnh kính, vẽ đè lên trên cùng
   └─4. ghép:
        <svg viewBox="0 0 100 100">
          <rect width="100" height="100" fill="{bg}"/>   ← nền theo bảng màu
          {thân con vật đã tô màu}
          {phụ kiện}
        </svg>
```

Khung con vật (bước 1) cũng là đồ ghép, nhưng **được ghép sẵn một lần khi tạo thư viện**, không phải lúc render. Mỗi con vật là một dòng mô tả trong file mẫu, ví dụ `fox|Cáo|tri|wide|w|dot|n|`: tai `tri`, đầu `wide`, mõm `w`, mũi `dot`, mắt `n`, cùng các chi tiết thêm (`X`) như sọc, bờm, vòi. Mỗi chi tiết thêm có lớp `B` (vẽ sau đầu), `M` (trên đầu) hoặc `F` (trên cùng). Script tạo thư viện ghép các mảnh theo thứ tự `B → tai → đầu → M → mõm → mắt → mũi → F` thành chuỗi `animals[k].svg`. File `avatar-lib.vN.json` chỉ chứa kết quả đã ghép (v2 dùng cùng bảng mô tả, vẽ lại từng mảnh theo kiểu origami), nên client không cần biết các mảnh tai/đầu/mõm.

Ai render:

| Nơi | Cách |
| --- | --- |
| Mobile (Flutter) | `buildSvg(avatar, lib)` (vài dòng thay chuỗi) → `SvgPicture.string(...)` của `flutter_svg`; cache chuỗi SVG theo `avatar_key`. |
| Server | **Không render.** Chỉ kiểm tra khoá tồn tại trong thư viện và cấp phát. |
| Ảnh PNG (nếu sau này cần, ví dụ thông báo đẩy, chia sẻ ra ngoài app) | Render SVG → PNG một lần, lưu cache trên R2 theo `avatar_key`. Chưa cần ở giai đoạn này. |

Vì vậy dữ liệu truyền đi khắp hệ thống chỉ là chuỗi `1:fox:0:glasses`. Đổi màu hay sửa nét cho cả nghìn người chỉ cần phát hành thư viện mới, không phải tạo lại ảnh.

## 4. Cấp phát avatar duy nhất

### 4.1. Kho avatar (`avatar_pool`)

Mỗi tổ hợp có thể có là **một dòng** trong bảng `avatar_pool`, cột `owner_public_id` cho biết ai đang giữ nó. Khi thư viện có phiên bản mới, server chèn thêm các tổ hợp mới vào kho (bước seed idempotent lúc khởi động hoặc trong migration).

Tại sao dùng bảng kho thay vì "random rồi kiểm xem có ai trùng":

- Kho chỉ có 3.000 tổ hợp. Khi đã cấp khoảng 2.900, "random rồi thử" sẽ trúng tổ hợp đã có chủ ~97% số lần, phải thử lại rất nhiều. Còn khi chọn trực tiếp từ các dòng còn trống thì luôn ra kết quả sau một lần.
- Biết ngay còn bao nhiêu avatar trống để cảnh báo trước khi hết (§4.4).

### 4.2. Thuật toán quay (lúc đăng ký)

Trong transaction của `register()`, thay `randomStarter()`:

```text
lặp tối đa 5 lần:
    free = SELECT COUNT(*) FROM avatar_pool WHERE owner_public_id IS NULL
    nếu free = 0 → ném ApiException 503 AVATAR_POOL_EXHAUSTED
    k = SecureRandom.nextInt(free)
    key = SELECT avatar_key FROM avatar_pool WHERE owner_public_id IS NULL
          ORDER BY avatar_key LIMIT 1 OFFSET k
    n = UPDATE avatar_pool SET owner_public_id = :me, assigned_at = now()
        WHERE avatar_key = :key AND owner_public_id IS NULL     -- giữ chỗ nguyên tử
    nếu n = 1 → thành công, thoát vòng lặp
    (n = 0: người khác vừa lấy đúng avatar này → thử lại)
hết 5 lần vẫn không được → 503 AVATAR_BUSY (client thử lại)
```

- Câu `UPDATE ... AND owner_public_id IS NULL` là chỗ **đảm bảo không trùng** khi hai người đăng ký cùng lúc: chỉ một câu lệnh cập nhật được dòng đó. Cách này chạy được cả trên MySQL lẫn H2 trong test, không cần `SKIP LOCKED`.
- Lớp chặn thứ hai: `UNIQUE (avatar_key)` trên `user_avatars`. Có bug ở tầng ứng dụng thì cơ sở dữ liệu vẫn từ chối.
- Xác suất đều trên các avatar còn trống. Server quay, client chỉ chạy hiệu ứng; không có endpoint nào cho client tự chọn mã.
- Đăng ký vẫn idempotent theo `sub`: gọi lại trả về avatar đã cấp, không quay lại.
- Rollback transaction (ví dụ lỗi ngày sinh) thì việc giữ chỗ trong kho cũng rollback, avatar trở về trống.

Sau khi giữ chỗ thành công (cùng transaction):

1. `INSERT user_avatars (source = REGISTER)`.
2. `users.avatar_key`, `users.avatar_version`, `users.lead_animal = animal`.
3. `outbox.publish(USER, USER_REGISTERED, …)` mang thêm `avatar`.

### 4.3. Bộ sưu tập

- Mỗi avatar trong `user_avatars` vẫn có chủ trong `avatar_pool`, nên **không ai khác quay ra được**, kể cả khi người đó không còn dùng nó làm avatar chính.
- Hệ quả: mỗi lượt quay thêm (sau này, khi nạp tiền) **tiêu tốn một avatar của kho chung**. Phần thiết kế nạp tiền phải tính đến điều này (§4.4).
- Đổi avatar đang dùng sang một avatar khác trong bộ sưu tập: để đến phần nạp tiền mới quyết định.

### 4.4. Sức chứa: rủi ro lớn nhất

**Với 3.000 avatar duy nhất, hệ thống chỉ chứa được tối đa 3.000 tài khoản**, và còn ít hơn nữa khi có lượt quay thêm. Hết kho thì **không đăng ký được nữa**. Cần làm trước khi ra mắt:

- **Metric + cảnh báo**: `avatar_pool_free` (gauge). Cảnh báo khi còn dưới 30% và báo động khi còn dưới 10%.
- **Mở rộng kho bằng phiên bản thư viện mới**, chỉ thêm và không đổi nghĩa (§3.2). Mỗi chiều mới nhân sức chứa lên. Ví dụ:

  | Cách mở rộng | Sức chứa |
  | --- | --- |
  | v1: 50 × 10 × 6 | 3.000 |
  | +10 con vật, +6 màu (60 × 16 × 6) | 5.760 |
  | thêm chiều "nền/hoa văn" 8 kiểu (60 × 16 × 6 × 8) | 46.080 |
  | thêm chiều "kiểu mắt" 4 kiểu | 184.320 |

  Khi thêm một chiều mới, avatar cũ nhận giá trị mặc định của chiều đó (ví dụ `pattern = 0`). `avatar_key` mới có thêm phần tử, nhưng mỗi khoá cũ ánh xạ đúng một khoá mới, nên tính duy nhất vẫn được giữ.
- Để dễ mở rộng, nên đặt `avatar_key VARCHAR(80)` ngay từ đầu và parse theo thư viện của phiên bản, không cố định đúng 3 phần.

### 4.5. Xoá tài khoản: không thu hồi avatar

- Khi tài khoản bị xoá (kể cả xoá hẳn), dòng trong `avatar_pool` **giữ nguyên `owner_public_id`**, và dòng trong `user_avatars` cũng không bị xoá. Avatar đó **không bao giờ** được cấp lại cho ai.
- Bị khoá hoặc tạm ngưng: tương tự, giữ nguyên.
- Lý do: avatar là "mặt" của người dùng, nên người cũ và người mới không bao giờ bị nhầm với nhau.
- Hệ quả: **kho chỉ giảm, không bao giờ tăng lại**. Tài khoản bị xoá vẫn chiếm chỗ. Metric `avatar_pool_free` vì vậy là chỉ số chính để quyết định khi nào phát hành thư viện mới (§4.4).
- Xoá dữ liệu cá nhân (quyền riêng tư) vẫn làm như cũ. `publicId` trong `avatar_pool` chỉ là chuỗi ngẫu nhiên, không chứa thông tin cá nhân, nên giữ lại được.

## 5. Lưu trữ phía server (user-service, MySQL)

Migration `V2__avatar.sql`. Test H2 dùng `create-drop` nên không phát hiện được chỗ entity lệch với SQL: sửa entity thì phải sửa cả SQL.

```sql
-- Kho avatar: mỗi tổ hợp một dòng, tối đa một chủ.
CREATE TABLE avatar_pool (
    avatar_key VARCHAR(80) NOT NULL,          -- "fox:0:none"
    lib_version INT NOT NULL,                 -- phiên bản thư viện đầu tiên có tổ hợp này
    owner_public_id VARCHAR(20) NULL,         -- đã gán thì không bao giờ về NULL (§4.5)
    assigned_at DATETIME(6) NULL,
    PRIMARY KEY (avatar_key),
    INDEX idx_pool_owner (owner_public_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- Bộ sưu tập: avatar_key UNIQUE toàn bảng = lớp chặn trùng thứ hai.
CREATE TABLE user_avatars (
    id BIGINT NOT NULL AUTO_INCREMENT,
    public_id VARCHAR(20) NOT NULL,
    avatar_key VARCHAR(80) NOT NULL,
    lib_version INT NOT NULL,
    source VARCHAR(12) NOT NULL,              -- REGISTER | BACKFILL | PURCHASE | ADMIN
    source_ref VARCHAR(64) NULL,
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_user_avatars_key UNIQUE (avatar_key),
    INDEX idx_user_avatars_owner (public_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

ALTER TABLE users
    ADD COLUMN avatar_key VARCHAR(80) NULL,   -- avatar đang dùng; NULL chỉ trong lúc cấp cho tài khoản cũ
    ADD COLUMN avatar_version INT NULL,
    ADD CONSTRAINT uk_users_avatar UNIQUE (avatar_key);  -- lớp chặn thứ ba cho avatar đang dùng
```

- **Seed kho**: một bean chạy lúc khởi động đọc `avatar-lib`, `INSERT` các tổ hợp còn thiếu (idempotent theo khoá chính). Không seed 3.000 dòng bằng SQL viết tay.
- **Tài khoản cũ được cấp avatar ngẫu nhiên** (giữ nguyên bạn bè, bài đăng, chat):
  - Bean `AvatarBackfill` chạy lúc user-service khởi động, sau bước seed kho. Nó lấy các `users` có `avatar_key IS NULL` theo thứ tự `created_at`, cấp cho từng người bằng **đúng thuật toán §4.2**, mỗi người một transaction.
  - Cấp xong thì ghi `user_avatars (source = BACKFILL)`, đặt `lead_animal = animal` mới và phát `AVATAR_CHANGED` để discovery/post/chat cập nhật.
  - Idempotent: chạy lại chỉ xử lý người còn `NULL`. Nhiều instance cùng chạy cũng không sao, vì lệnh giữ chỗ có điều kiện vẫn ngăn trùng; người đã có avatar thì bỏ qua (`UPDATE users ... WHERE avatar_key IS NULL`).
  - Ngẫu nhiên hoàn toàn, không cố giữ con vật cũ.
  - Tài khoản `DELETED` được bỏ qua (không tốn avatar của kho), nên `users.avatar_key` **giữ nullable**: chỉ tài khoản đã xoá trước khi có avatar mới là `NULL`. Không làm migration `NOT NULL`.
  - Tắt được bằng `animal.avatar.backfill-on-startup=false`.
  - App phải chịu được `avatar = null` trong khoảng thời gian ngắn trước khi backfill xong (hiện emoji cũ).
- Bảng `animals`/`user_animals` (danh mục cũ, gói SAFARI/OCEAN) **giữ nguyên, coi là legacy**: đăng ký không còn ghi `user_animals`. `POST /users/me/spin` và `PUT /users/me/lead-animal` trả `410 FEATURE_RETIRED` (mỗi người chỉ quay một lần; đổi avatar sẽ làm cùng phần nạp tiền).
- `users.lead_animal` giữ nguyên trong giai đoạn chuyển, để các service đang đọc nó không bị lỗi.

## 6. Lưu trữ phía máy người dùng

Máy **chỉ là bộ đệm**, server là nguồn sự thật:

| Dữ liệu | Lưu ở | Ghi chú |
| --- | --- | --- |
| `avatar-lib.vN.json` | assets của app + thư mục cache khi tải bản mới | Khoảng 30–50 KB. |
| Avatar của tôi | File `my_avatar.json` trong thư mục support của app (`MyAvatarStore`) | Ghi lại mỗi lần gọi `GET /users/me` / đăng ký; xoá khi xoá tài khoản; cài lại app thì lấy lại từ server. |
| Avatar người khác | Không lưu riêng | Đi kèm trong thẻ discovery, bài đăng, danh sách bạn (chuỗi mã) và được vẽ tại chỗ. |
| SVG đã dựng | Cache bộ nhớ theo `avatar_key` | Tránh dựng lại SVG khi cuộn danh sách. |

Mobile: `AnimalAvatar(avatar: …, leadAnimal: …)` vẽ bằng `flutter_svg` (`SvgPicture.string`), dùng thư viện mới nhất trên máy có khoá của mã. Nếu không thư viện nào có khoá đó thì tải phiên bản `v` trong nền và hiện emoji cũ làm dự phòng. `reveal_screen` hiện avatar thật, với hiệu ứng quay chạy trên kết quả server đã trả.

## 7. API & event

| Endpoint | Mô tả |
| --- | --- |
| `POST /users/register` | Trả thêm `avatar`. Mã lỗi mới `AVATAR_POOL_EXHAUSTED` / `AVATAR_BUSY` (503). |
| `GET /users/me` | Thêm `avatar`: **chuỗi** `"1:fox:0:glasses"` (client tự tách). |
| `GET /users/me/avatars` | Bộ sưu tập: `[{avatar, source, acquiredAt}]`. |
| `GET /animals/avatar-lib/{v}` | Thư viện; `404` nếu không có phiên bản đó. |
| `POST /users/me/spin`, `PUT /users/me/lead-animal` | Đã ngừng: `410 FEATURE_RETIRED`. |
| `PublicProfile`, discovery `Card`, post `Author`, internal user | Thêm `avatar` bên cạnh `leadAnimal`. |

Event (topic `USER`): `USER_REGISTERED` thêm `avatar`; mới có `AVATAR_CHANGED {publicId, avatar}` (dùng khi cấp avatar cho tài khoản cũ và sau này khi đổi avatar trong bộ sưu tập). `LEAD_ANIMAL_CHANGED` vẫn phát song song (media-service còn đọc). discovery/post không cần nghe event: chúng lấy hồ sơ qua API nội bộ (post cache 5 phút), nên avatar mới hiện sau tối đa vài phút. Consumer gọi `idempotency.firstTime(eventId)`.

## 8. Nạp tiền & hạn mức (làm sau)

Đã ghi nhận hướng đi, chưa thiết kế chi tiết:

- Nạp tiền → nhận lượt quay (`AVATAR_SPIN` qua `CONSUMABLE_GRANTED`), quay bằng `POST /users/me/avatar/spin` (có `Idempotency-Key`), avatar mới lấy từ cùng kho §4 và vào bộ sưu tập.
- Nạp tiền → tăng ảnh/ngày (post-service `QuotaService`) và số bạn tối đa (**chưa có** giới hạn bạn bè trong `FriendService`, là logic mới).
- Cần tính chung với sức chứa kho (§4.4): mỗi lượt quay bán ra làm giảm một chỗ trong kho.

## 9. Kế hoạch triển khai (phần đã chốt)

1. **Thư viện**: tách `lib` từ file HTML mẫu thành `libs/avatar-lib/avatar-lib.v1.json`. Test: đủ 3.000 tổ hợp, mọi `avatar_key` phân biệt; bản Dart vẽ ra SVG giống bản JS cho vài mã mẫu.
2. **user-service**: migration `V2__avatar.sql` + entity, seed kho lúc khởi động, `AvatarAllocator` (thuật toán §4.2), sửa `register()`, `GET /users/me/avatars`, metric `avatar_pool_free`.
   Test bắt buộc:
   - Cấp phát song song (ví dụ 50 luồng đăng ký cùng lúc) thì không ai trùng.
   - Kho chỉ còn 1 avatar → hai người đăng ký cùng lúc → một người được, người kia nhận `AVATAR_POOL_EXHAUSTED`.
   - Kho rỗng → 503.
   - Gọi `register()` lại thì không cấp thêm.
   - Lỗi giữa chừng → avatar trở về trống.
3. **Cấp avatar cho tài khoản cũ** (`AvatarBackfill`, §5) + test: N người cũ → N avatar khác nhau, chạy lại không đổi gì, tài khoản đã xoá không lấy avatar.
4. **discovery / post**: thêm `avatar` vào DTO (chat lấy hồ sơ từ danh sách bạn của user-service).
5. **Mobile**: thư viện trong assets, `AnimalAvatar` vẽ SVG, `reveal_screen` có hiệu ứng quay, hồ sơ hiện bộ sưu tập, lưu avatar vào máy.
6. Cập nhật `docs/05-data-model.md`, `06-api-reference.md`, `07-event-catalog.md`.

Tất cả các bước trên **đã làm**. Còn thiếu: luật cảnh báo Prometheus cho `avatar_pool_free` (metric đã có, chưa có rule), chạy thử migration với MySQL thật.

**Sửa thư viện**: chỉ sửa `libs/avatar-lib/build-lib.mjs` rồi chạy `node libs/avatar-lib/build-lib.mjs` (ghi `libs/avatar-lib/`, `mobile/assets/avatar/` và mẫu đối chiếu `mobile/test/fixtures/`). Không sửa tay file JSON. Phiên bản đã phát hành không được đổi nghĩa (§3.2).

## 10. Còn cần chốt

Phần cơ chế avatar đã chốt hết. Còn lại thuộc giai đoạn sau:

1. Nạp tiền & bảng hạn mức (§8).
2. Nội dung thư viện v2 (con vật/màu/chiều mới) khi kho chạm ngưỡng cảnh báo.
