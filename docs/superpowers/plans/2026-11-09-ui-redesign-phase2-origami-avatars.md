# UI redesign đợt 2 · Avatar origami — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vẽ lại 50 con vật thành thư viện avatar v2 kiểu "gấp đơn giản" (cùng bộ khoá v1) và cho app vẽ mọi avatar bằng v2.

**Architecture:** `build-lib.mjs` tách thành module v1 (giữ nguyên, sinh lại đúng từng byte) và v2 (mảnh origami mới, bảng màu thêm sắc độ tính sẵn). Hàm vẽ chuẩn thay mọi `{{tên}}` bằng màu cùng tên. Server không đổi code (khoá vẫn thuộc v1); app đóng gói v2 và chọn thư viện mới nhất có khoá.

**Tech Stack:** Node (ES modules, không thêm thư viện), Flutter/Dart (`flutter_svg`), Spring Boot user-service (chỉ test), Markdown.

**Spec:** `docs/superpowers/specs/2026-11-09-ui-redesign-design.md` §5, §5.1

## Global Constraints

- Bộ khoá v2 = v1: 50 con vật (cùng tên khoá và tên tiếng Việt) × 10 bảng màu × 6 phụ kiện (`none, glasses, party, crown, bow, phones`) = 3.000.
- `libs/avatar-lib/avatar-lib.v1.json` không đổi một byte; `mobile/test/fixtures/avatar-lib.v1.samples.json` cũng không đổi.
- 10 màu gốc mỗi bảng (`fur`, `belly`, `accent`, `bg`) giữ nguyên giá trị v1; sắc độ thêm: `furD`, `furL`, `bellyD`, `accentD`, `accentL`.
- Kiểu B: mảng đa giác cạnh thẳng (không `circle`/`ellipse` cho đầu, tai, mõm, phụ kiện lớn), một nếp dọc giữa mặt (nửa phải `furD`), tai là mảnh gấp đôi; mắt chấm `#2B2420`; không má hồng, không ánh sáng trong mắt.
- viewBox `0 0 100 100`, nền `<rect width="100" height="100" fill="bg"/>` như v1; hình được cắt tròn khi hiển thị nên phần quan trọng nằm trong vòng tròn bán kính 50.
- Không thêm dependency (Node chỉ dùng thư viện chuẩn).
- Commit theo Conventional Commits, không có dòng ghi tác giả AI.

## Review Focus

1. Sinh lại v1 sau khi tách module: phải trùng từng byte với file đã commit (một khác biệt nhỏ làm đổi hình của người đang dùng app cũ).
2. Bảng màu sáng (bảng 3, `fur #F4F1EC`) và tối (bảng 9, `fur #3E4A63`): nếp gấp và mắt vẫn thấy được; 10 bảng màu vẫn phân biệt.
3. Phụ kiện đặt đúng chỗ trên đầu mới của mọi con (kính ở hàng mắt, mũ/vương miện trên đỉnh không che mắt, nơ dưới cằm, tai nghe hai bên).
4. Mã đã cấp `1:…` trên máy có file v1 cũ trong thư mục support vẫn ra hình v2.
5. Cỡ 40pt: con vật vẫn nhận ra (tai, mõm, chi tiết đặc trưng không bị nhoè thành một mảng).

---

### Task 1: Tách module thư viện, hàm vẽ tổng quát, kiểm tra bộ khoá

**Files:**
- Create: `libs/avatar-lib/lib-v1.mjs` (chuyển nguyên phần mảnh + RAW + palettes + accessories của v1 từ `build-lib.mjs`, export `lib`)
- Modify: `libs/avatar-lib/build-lib.mjs` (chỉ còn: nạp các module phiên bản, ghi file, `render`, mẫu, kiểm tra khoá, `--preview`)
- Test: `libs/avatar-lib/check.mjs` (script tự kiểm, chạy bằng `node`)

**Interfaces:**
- Produces: mỗi module phiên bản `export const lib = { version, keyFormat, viewBox, animals, palettes, accessories }`.
- Produces: `export function render(lib, key): string` — thay mọi `{{name}}` theo `palettes[i]` (không thay `bg` trong thân), ghép như v1.
- Produces: `export function keySet(lib): Set<string>`.
- `build-lib.mjs` ghi: `libs/avatar-lib/avatar-lib.v{N}.json` cho mọi phiên bản; `mobile/assets/avatar/avatar-lib.v{latest}.json`; `mobile/test/fixtures/avatar-lib.v{N}.samples.json` cho mọi phiên bản.

- [ ] **Step 1: Viết `check.mjs`** — chạy build vào thư mục tạm (biến môi trường `AVATAR_OUT`), rồi `assert`:
  - v1 tạo ra trùng từng byte với `libs/avatar-lib/avatar-lib.v1.json` và `mobile/test/fixtures/avatar-lib.v1.samples.json` đã commit;
  - mọi phiên bản: `keySet(v) == keySet(v1)`, kích thước 3000;
  - mọi khoá của mọi phiên bản: `render` không còn chuỗi `{{`.
- [ ] **Step 2: Chạy** `node libs/avatar-lib/check.mjs` — Expected: FAIL (chưa có `AVATAR_OUT`/module).
- [ ] **Step 3: Tách `lib-v1.mjs`, sửa `build-lib.mjs`** (đường dẫn ra lấy từ `AVATAR_OUT` nếu có, mặc định như cũ; `render` tổng quát).
- [ ] **Step 4: Chạy** `node libs/avatar-lib/check.mjs` — Expected: PASS; `git status` không đổi file v1 nào.
- [ ] **Step 5: Commit** `refactor(avatar-lib): split v1 module and generalize render placeholders`

### Task 2: Thư viện v2 kiểu gấp đơn giản

**Files:**
- Create: `libs/avatar-lib/lib-v2.mjs`
- Modify: `libs/avatar-lib/build-lib.mjs` (thêm v2 vào danh sách; `--preview <file>` ghi trang HTML xem trước)
- Generated: `libs/avatar-lib/avatar-lib.v2.json`, `mobile/assets/avatar/avatar-lib.v2.json`, `mobile/test/fixtures/avatar-lib.v2.samples.json`
- Test: `libs/avatar-lib/check.mjs`

**Interfaces:**
- Consumes: `render`, `keySet` (Task 1).
- Produces: `lib.version = 2`; `palettes[i]` có thêm `furD furL bellyD accentD accentL` (hex `#RRGGBB`, sẫm = trộn 22% về `#1A1008`, sáng = trộn 22% về `#FFFFFF`).

- [ ] **Step 1: Thêm kiểm tra vào `check.mjs`** cho v2: tồn tại; 10 màu gốc mỗi bảng bằng v1; có đủ 5 sắc độ dạng hex; thân con vật không chứa `<circle` hay `<ellipse` lớn hơn bán kính 6 (chỉ mắt/chấm nhỏ được dùng hình tròn); `animals[k].name` bằng v1.
- [ ] **Step 2: Chạy** — Expected: FAIL (chưa có v2).
- [ ] **Step 3: Viết `lib-v2.mjs`** — bộ mảnh origami giữ đúng tên mảnh của v1 (tai `none tri rnd big long flop`; đầu `round wide tall`; mõm `m w s f n`; mắt `n big top`; mũi `none dot tri pig beak bill smile`; các chi tiết `X` cùng tên và lớp B/M/F) để dùng lại nguyên bảng RAW 50 dòng; đầu là đa giác có nửa phải `{{furD}}`, tai là mảnh gấp đôi, chi tiết thêm vẽ bằng đa giác/nét thẳng. Phụ kiện 6 khoá vẽ lại bằng mảng phẳng.
- [ ] **Step 4: Chạy** `node libs/avatar-lib/build-lib.mjs --preview .superpowers/avatar-v2-preview.html` rồi `node libs/avatar-lib/check.mjs` — Expected: PASS; mở trang xem trước tự soát 50 con ở cỡ 96 và 40pt, sửa con nào không nhận ra.
- [ ] **Step 5: Commit** `feat(avatar-lib): add origami avatar library v2`

### Task 3: App vẽ mọi avatar bằng v2

**Files:**
- Modify: `mobile/lib/core/avatar/avatar_library.dart`
- Delete: `mobile/assets/avatar/avatar-lib.v1.json`
- Test: `mobile/test/avatar_library_test.dart`

**Interfaces:**
- Consumes: `avatar-lib.v2.json`, fixture v1 + v2 (Task 1–2).
- Produces: `AvatarLibraryData.render` thay mọi `{{name}}`; `AvatarLibraries.bundledVersions == [2]`; `svgFor`/`animalName` dùng thư viện số lớn nhất có đủ con vật, bảng màu và phụ kiện của mã, nếu không có thì thư viện đúng phiên bản trong mã (tải nền như cũ).

- [ ] **Step 1: Sửa/viết test**:
  - `thư viện v2 có 3000 tổ hợp, cùng bộ khoá với v1` (đọc `../libs/avatar-lib/avatar-lib.v1.json` và `assets/avatar/avatar-lib.v2.json`);
  - `vẽ ra đúng chuỗi SVG như hàm chuẩn` cho cả fixture v1 (dùng JSON v1 ở `libs/`) và v2;
  - `mã đã cấp 1:… được vẽ bằng v2`: chỉ đăng ký v2 → `svgFor('1:fox:0:none') == v2.render(...)`, không tải phiên bản 1;
  - `có cả v1 và v2 thì vẫn chọn v2` (Review Focus 4);
  - `khoá không có trong thư viện nào thì dùng emoji` (giữ test `9:fox:0:none` hiện có, thêm `1:nope:0:none`);
  - `AnimalAvatar` semantics vẫn `Ảnh đại diện: Cáo`.
- [ ] **Step 2: Chạy** `flutter test test/avatar_library_test.dart` — Expected: FAIL (đang chọn theo phiên bản, render 3 tên cố định, asset v1).
- [ ] **Step 3: Sửa `avatar_library.dart`, xoá asset v1.**
- [ ] **Step 4: Chạy** `flutter test` (toàn bộ) và `flutter analyze` — Expected: tất cả PASS, không lỗi. Trả `lib/l10n/generated` về như cũ nếu Flutter sinh lại.
- [ ] **Step 5: Commit** `feat(mobile): draw every avatar with the origami library v2`

### Task 4: Server phục vụ v2, khoá không đổi

**Files:**
- Test: `services/user-service/src/test/java/com/animallocket/user/AvatarAllocationIntegrationTest.java`, `UserFlowIntegrationTest.java`

- [ ] **Step 1: Thêm test**: `library.latestVersion() == 2`; `library.find("fox:0:none").get().version() == 1`; `allKeys().size() == 3000` (đã có); `GET /api/v1/animals/avatar-lib/2` trả 200 với `"version":2`.
- [ ] **Step 2: Chạy** `mvn -q -B -pl services/user-service install` — Expected: PASS ngay vì file v2 đã nằm trong `libs/avatar-lib` (Task 2) và pom đã gom `avatar-lib.v*.json`. Kiểm chứng test có tác dụng: tạm đổi tên `avatar-lib.v2.json` → test `latestVersion` FAIL, đổi lại → PASS.
- [ ] **Step 3: Commit** `test(user): cover avatar library v2 keeping v1 keys`

### Task 5: Tài liệu

**Files:**
- Modify: `docs/19-avatar-mechanism.md` (trạng thái, §3.2 quy tắc, bảng nguồn/file, phần mobile), `docs/15-adr.md` (ADR-015 "Vẽ lại avatar sang origami, giữ bộ khoá"), `CLAUDE.md` (dòng Avatar), `libs/avatar-lib` chú thích đầu file.

- [ ] **Step 1: Sửa theo spec §5.1** (quy tắc mới: phiên bản mới được vẽ lại khoá cũ, giữ bộ khoá và ý nghĩa, không xoá khoá; app dùng thư viện mới nhất có khoá; v1 giữ nguyên từng byte cho server và app cũ).
- [ ] **Step 2: Soát** `grep -n "không bao giờ đổi nghĩa\|avatar-lib.v1.json" docs CLAUDE.md` — Expected: chỉ còn chỗ nói đúng sự thật mới.
- [ ] **Step 3: Commit** `docs(avatar): allow restyled library versions with frozen keys (ADR-015)`
