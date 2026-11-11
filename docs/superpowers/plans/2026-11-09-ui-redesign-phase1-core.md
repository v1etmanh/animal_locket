# Làm lại giao diện — Đợt 1 (Core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dựng hệ theme 4 bảng màu chọn được, font và nền "album giấy gấp", bộ icon riêng, thanh điều hướng washi và màn Feed mới cho app Flutter `mobile/`.

**Architecture:** Màu đi qua một `ThemeExtension` (`AlbumPalette`) gắn vào `ThemeData`; `AnimalLocketApp` dựng `ThemeData` từ theme đang chọn trong một Riverpod `Notifier`, lưu lựa chọn bằng `flutter_secure_storage` (gói đã có). Nút/ô nhập/hộp thoại được làm lại qua component theme của Material; thẻ ảnh washi, con dấu hanko, nền giấy gấp, thanh tab là widget/CustomPainter riêng. Màn cũ tự nhận nền, font, màu theme qua `AppBackground`/`ThemeData`; widget cũ (`GlassContainer`, `GradientButton`, `AppColors`) giữ nguyên.

**Tech Stack:** Flutter 3.41 / Dart ^3.13, flutter_riverpod 3, go_router 18, flutter_svg (đã có), flutter_secure_storage 11, flutter_test.

**Spec:** `docs/superpowers/specs/2026-11-09-ui-redesign-design.md` (đọc kèm). Mockup tham chiếu (máy local, không trong git): `.superpowers/brainstorm/990-1794159769/content/combined-v1.html`, `theme-set-v1.html`, `nav-options-v1.html` (phương án 3).

## Global Constraints

- Không đổi chuỗi giao diện hiện có, thứ tự/nhãn tab (`Ảnh · Bảng tin · Khám phá · Chat · Hồ sơ` từ `l10n`), luồng, hành vi, repository/controller. Chữ thật thắng chữ mẫu trong mockup (spec §7.1).
- Chỉ thêm chuỗi mới cho mục chọn theme (Task 8), copy cố định ở đó.
- Theme chỉ đổi bảng màu. Mặc định **Shu**. Mọi theme mở cho mọi người. Lưu trên máy.
- Màu trên màn đã làm lại chỉ lấy từ `AlbumPalette`; không `Color(0x…)` và không `Icons.*` trong file màn/widget mới (trừ trong `album_palette.dart`).
- Mọi cặp chữ/nền dùng thật phải đạt WCAG AA: 4.5:1 chữ thường, 3:1 chữ lớn/icon.
- Font: Lora (tiêu đề, ngày), Be Vietnam Pro (chữ thường), Patrick Hand (chỉ caption/ghi chú tay). Nhúng `.ttf` + giấy phép OFL vào `assets/fonts/`. Chữ Nhật trang trí là SVG, không nhúng font CJK.
- Tôn trọng `MediaQuery.disableAnimations`: khi bật thì không chạy hiệu ứng.
- Không thêm gói pub mới. Không đụng backend, `libs/`.
- `PostsGrid` (`posts_grid.dart`) không thuộc đợt này.
- Commit theo Conventional Commits, scope `mobile`; không thêm dòng Co-authored-by.

## Review Focus

- Đọc lựa chọn theme lỗi (plugin không có trong test/web, giá trị lạ trong storage) → dùng Shu, không crash. Test ở Task 3.
- Alias rất dài, caption nhiều dòng/emoji trên thẻ washi → không tràn (alias cắt `…`, caption xuống dòng). Test ở Task 7.
- Bật "giảm chuyển động" → con dấu và washi đổi trạng thái ngay, không animation. Test ở Task 5 và Task 6.
- Cỡ chữ hệ thống 1.5× → nhãn thanh tab không tràn (`Khám phá` dài nhất). Test ở Task 6.
- Ảnh đang tải / lỗi / `url == null` trong thẻ washi → khung giữ tỉ lệ 4:5, hiện icon riêng, không vỡ layout. Test ở Task 7.

---

### Task 1: Bảng màu theme (`AlbumPalette`)

**Files:**
- Create: `mobile/lib/core/theme/album_palette.dart`
- Test: `mobile/test/album_palette_test.dart`

**Interfaces:**
- Produces:
  - `enum AlbumThemeId { shu, yuzu, sakura, sora }`
  - `class AlbumPalette extends ThemeExtension<AlbumPalette>` với các field `Color background, paper, fold1, fold2, fold3, tape1, tape2, accent, accentDeep, accentSoft, muted, ink, danger` và `String kanji`; `static AlbumPalette of(AlbumThemeId id)`; `copyWith`, `lerp` chuẩn.
  - `extension AlbumContext on BuildContext { AlbumPalette get album; }` (đọc `Theme.of(this).extension<AlbumPalette>()!`).
  - `double contrastRatio(Color a, Color b)` (WCAG 2.x, top-level, dùng lại trong test).

- [ ] **Step 1: Write the failing test** `album_palette_test.dart`:
  - `of(AlbumThemeId.shu)` có `background == Color(0xFFFFF8EF)`, `accent == Color(0xFFB8402A)`, `kanji == '朱'`; tương tự kiểm `accent` của yuzu `0xFFA35C00`, sakura `0xFFB23A5B`, sora `0xFF2F5F8A` và kanji `柚 桜 空`.
  - `contrastRatio(Color(0xFF000000), Color(0xFFFFFFFF))` ≈ 21.0 (±0.01); `contrastRatio(x, x) == 1.0`.
  - Với **mỗi** theme: `contrastRatio(ink, background) >= 4.5`, `(ink, paper) >= 4.5`, `(muted, background) >= 4.5`, `(muted, paper) >= 4.5`, `(accent, paper) >= 4.5`, `(accent, accentSoft) >= 4.5`, `(danger, paper) >= 4.5`, `(Color(0xFFFFFFFF), accent) >= 4.5`.

- [ ] **Step 2: Run** `cd mobile && flutter test test/album_palette_test.dart` — Expected: FAIL (file chưa có).

- [ ] **Step 3: Implement `album_palette.dart`.** Giá trị lấy nguyên bảng spec §4:

  | | shu | yuzu | sakura | sora |
  |---|---|---|---|---|
  | background | FFF8EF | FFFAEA | FFF6F1 | F6F9FB |
  | paper | FFFDF8 | FFFEF8 | FFFDFB | FFFFFF |
  | fold1/2/3 | FFE3C2 FFE9DC FDE4C8 | FFEEB8 FFF3D1 FFE6A6 | FFE0D2 FFDBE5 FFE9C9 | D9EBF6 E8F2F9 FFE9D6 |
  | tape1/2 | F4B9A3 F9D3C3 | F7CF6B FBE3A3 | F6B8C8 FBD7E1 | 9CC7E3 C8E1F1 |
  | accent / deep / soft | B8402A 8A2C1B FBE1D6 | A35C00 7A4400 FFEFC2 | B23A5B 842640 FBDDE6 | 2F5F8A 204465 DCEAF5 |
  | muted | 6A5B4E | 6B5D45 | 6C5A58 | 56616B |
  | kanji | 朱 | 柚 | 桜 | 空 |

  `ink = 0xFF2B2420` chung; `danger = 0xFFA8261E` chung. Nếu một cặp trong test không đạt AA, chỉnh **sắc độ** màu đó (giữ tông) cho tới khi đạt, rồi ghi giá trị mới vào bảng spec §4 cùng commit.

- [ ] **Step 4: Run** `flutter test test/album_palette_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit** `feat(mobile): add album color palettes for four themes`

---

### Task 2: Font và `ThemeData` theo bảng màu

**Files:**
- Create: `mobile/assets/fonts/Lora-Variable.ttf`, `Lora-Italic-Variable.ttf`, `BeVietnamPro-{Regular,Medium,SemiBold,Bold}.ttf`, `PatrickHand-Regular.ttf`, `OFL-Lora.txt`, `OFL-BeVietnamPro.txt`, `OFL-PatrickHand.txt`
- Modify: `mobile/pubspec.yaml` (mục `fonts:`), `mobile/lib/core/theme/app_theme.dart`
- Test: `mobile/test/app_theme_test.dart`

**Interfaces:**
- Consumes: `AlbumPalette`, `AlbumThemeId` (Task 1).
- Produces: `AppTheme.forPalette(AlbumPalette p) → ThemeData`; `AppTheme.light` giữ lại = `forPalette(AlbumPalette.of(AlbumThemeId.shu))`; hằng `AppFonts.title = 'Lora'`, `AppFonts.body = 'Be Vietnam Pro'`, `AppFonts.hand = 'Patrick Hand'` (trong `app_theme.dart`).

- [ ] **Step 1: Tải font** từ `https://github.com/google/fonts/tree/main/ofl/` (`lora/Lora[wght].ttf`, `lora/Lora-Italic[wght].ttf`, `bevietnampro/BeVietnamPro-*.ttf`, `patrickhand/PatrickHand-Regular.ttf`, mỗi thư mục có `OFL.txt`) về đúng tên file ở trên. Khai báo 3 family trong `pubspec.yaml` (Lora: file thường + file `style: italic`; Be Vietnam Pro: weight 400/500/600/700). Giữ khai báo Fraunces/Plus Jakarta Sans (màn cũ không phụ thuộc tên family, nhưng xoá ở đợt cuối).

- [ ] **Step 2: Write the failing test** `app_theme_test.dart`, với mỗi `AlbumThemeId`:
  - `theme.extension<AlbumPalette>()` bằng `AlbumPalette.of(id)`.
  - `theme.scaffoldBackgroundColor == Colors.transparent` (nền do `AppBackground` vẽ).
  - `theme.textTheme.bodyMedium!.fontFamily == 'Be Vietnam Pro'`; `headlineMedium!.fontFamily == 'Lora'`; `titleMedium!.fontFamily == 'Be Vietnam Pro'`.
  - `theme.colorScheme.primary == palette.accent`, `onPrimary == Color(0xFFFFFFFF)`, `surface == palette.paper`, `error == palette.danger`.
  - Widget test: pump `FilledButton(child: Text('Thử lại'))` trong `MaterialApp(theme: forPalette(...))` → nền nút `== palette.accent`.

- [ ] **Step 3: Run** `flutter test test/app_theme_test.dart` — Expected: FAIL.

- [ ] **Step 4: Implement `AppTheme.forPalette`.** Gắn `extensions: [p]`; `colorScheme` dựng thủ công (không `fromSeed`) từ token; text theme: body/label = Be Vietnam Pro, display/headline/titleLarge = Lora 700, màu chữ `ink`. Component theme: `FilledButton` (nền `accent`, chữ trắng, bo 14, bóng dưới `accentDeep` 3px qua `elevation`/`shadowColor` hoặc `side` — tuỳ builder, miễn nhìn như nút "giấy dày"), `OutlinedButton` (viền `accent`, nền `paper`), `TextButton` (chữ `accent`), `InputDecorationTheme` (nền `paper`, viền `fold1`, focus `accent` 1.5, bo 14), `DialogTheme` (nền `paper`, bo 18, tiêu đề Lora), `SnackBarTheme` (nền `ink`, floating), `ProgressIndicatorTheme` (`accent`), `AppBarTheme` (nền trong suốt, chữ `ink`, tiêu đề Lora 22). `AppTheme.light` gọi `forPalette` với Shu.

- [ ] **Step 5: Run** `flutter test` (toàn bộ) — Expected: PASS, 12 file test cũ vẫn xanh.

- [ ] **Step 6: Commit** `feat(mobile): album fonts and palette-driven ThemeData`

---

### Task 3: Lưu và áp dụng theme đang chọn

**Files:**
- Create: `mobile/lib/core/theme/theme_controller.dart`
- Modify: `mobile/lib/app.dart` (`theme:`), `mobile/test/app_smoke_test.dart` (override store)
- Test: `mobile/test/theme_controller_test.dart`

**Interfaces:**
- Consumes: `AlbumThemeId`, `AppTheme.forPalette`, `AlbumPalette.of`.
- Produces:
  - `abstract interface class ThemeStore { Future<AlbumThemeId?> read(); Future<void> write(AlbumThemeId id); }`
  - `class SecureThemeStore implements ThemeStore` (khoá `album_theme`, lưu `id.name`) và `class MemoryThemeStore implements ThemeStore` (dùng cho test/override).
  - `final themeStoreProvider = Provider<ThemeStore>(...)` (mặc định `SecureThemeStore(FlutterSecureStorage())`).
  - `class ThemeController extends Notifier<AlbumThemeId>` với `Future<void> select(AlbumThemeId id)`; `final albumThemeProvider = NotifierProvider<ThemeController, AlbumThemeId>(...)`.

- [ ] **Step 1: Write the failing test** `theme_controller_test.dart` (dùng `ProviderContainer` với `themeStoreProvider` override):
  - Store rỗng → state ban đầu `shu`, sau khi load vẫn `shu`.
  - Store chứa `sakura` → sau `await container.pump()`/đợi load, state == `sakura`.
  - `select(sora)` → state == `sora` ngay; `store.read()` trả `sora`.
  - Store ném lỗi khi `read` (giả lập `MissingPluginException`) → state `shu`, không ném ra ngoài.
  - Store chứa chuỗi lạ (`'neon'`) → `SecureThemeStore`/parse trả `null` → state `shu`.
  - Widget test: `AnimalLocketApp` với store `MemoryThemeStore(sora)` → `Theme.of(context).extension<AlbumPalette>()!.accent == AlbumPalette.of(sora).accent` ở màn đăng nhập.

- [ ] **Step 2: Run** `flutter test test/theme_controller_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement.** `build()` trả `shu` rồi đọc store bất đồng bộ và cập nhật state nếu có giá trị hợp lệ (bọc try/catch, lỗi → giữ `shu`). `select` đặt state trước rồi ghi store (lỗi ghi chỉ bỏ qua). `app.dart`: `theme: AppTheme.forPalette(AlbumPalette.of(ref.watch(albumThemeProvider)))`. Thêm `themeStoreProvider.overrideWithValue(MemoryThemeStore())` vào `app_smoke_test.dart`.

- [ ] **Step 4: Run** `flutter test` — Expected: PASS toàn bộ.

- [ ] **Step 5: Commit** `feat(mobile): persist selected album theme on device`

---

### Task 4: Nền giấy gấp, asset icon và chữ Nhật trang trí

**Files:**
- Modify: `mobile/lib/core/widgets/app_background.dart` (giữ tên lớp `AppBackground`), `mobile/lib/core/widgets/app_page.dart` (`SectionLabel`, `InfoPill`, `AppBar` dùng token thay `AppColors`), `mobile/pubspec.yaml` (`assets/icons/`, `assets/deco/`)
- Create: `mobile/lib/core/widgets/album_icon.dart`, `mobile/assets/icons/*.svg`, `mobile/assets/deco/*.svg`
- Test: `mobile/test/album_background_test.dart`

**Interfaces:**
- Consumes: `context.album`.
- Produces:
  - `AppBackground({required Widget child})` — vẽ `background` + 3 khối giấy gấp (`fold1..3`) bằng `CustomPainter` `FoldedPaperPainter(AlbumPalette p)`; vị trí/góc như mockup (`combined-v1.html`: khối 190×190 xoay 45° tràn góc trên phải, 120×120 xoay 28° mép trái giữa, 90×90 xoay 60° góc dưới phải; scale theo kích thước màn).
  - `enum AlbumIcons { photos, feed, discover, chat, profile, comment, friends, emptyAlbum, cloudOff, imageBroken, image }` và `AlbumIcon(AlbumIcons icon, {double size = 24, Color? color, String? semanticLabel})` — `SvgPicture.asset('assets/icons/<name>.svg')` tô bằng `ColorFilter.mode(color ?? IconTheme.of(context).color, BlendMode.srcIn)`.
  - `KanjiDeco.vertical(AlbumThemeId)` → `assets/deco/album_<id>.svg` (chữ `<kanji>のアルバム` dọc); `KanjiDeco.hanko` → `assets/deco/hanko_good.svg` (chữ 好). Widget `DecoSvg(String asset, {double height, Color color})`, `excludeFromSemantics: true`.

- [ ] **Step 1: Vẽ icon SVG** (viewBox 24, `fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"`, màu thay bằng ColorFilter). Năm icon tab lấy đúng path từ `nav-options-v1.html` phương án 3: `feed` = hai tấm ảnh chồng nghiêng ±6°, `discover` = ghim bản đồ, `chat` = bóng thoại, `profile` = thẻ hồ sơ có mặt người, `photos` = máy ảnh (dùng bên trong polaroid). Các icon còn lại vẽ cùng phong cách (`comment` = bóng thoại nhỏ, `friends` = hai thẻ người, `emptyAlbum` = album mở, `cloudOff`, `imageBroken`, `image`).

- [ ] **Step 2: Sinh SVG chữ Nhật** bằng một script tạm **ngoài repo** (ví dụ thư mục scratch, `npm i opentype.js` + font Noto Serif JP SemiBold): chuyển text thành `<path>` (không còn `<text>`), viewBox ôm sát. Tạo `hanko_good.svg` (好), `album_shu.svg`, `album_yuzu.svg`, `album_sakura.svg`, `album_sora.svg` (dọc, `<kanji>のアルバム`). Chỉ commit file SVG.

- [ ] **Step 3: Write the failing test** `album_background_test.dart`:
  - Pump `MaterialApp(theme: forPalette(of(yuzu)), home: AppBackground(child: Text('x')))` → tìm thấy `CustomPaint` có `painter is FoldedPaperPainter` và `(painter as FoldedPaperPainter).palette == AlbumPalette.of(yuzu)`; `find.text('x')` có.
  - `FoldedPaperPainter(of(shu)).shouldRepaint(FoldedPaperPainter(of(sora)))` là `true`, với cùng palette là `false`.
  - Mọi giá trị `AlbumIcons` có file asset tương ứng: `rootBundle.loadString('assets/icons/${icon.asset}.svg')` không ném lỗi và chứa `<svg`; tương tự 5 file `assets/deco/*.svg`, và **không** chứa `<text`.

- [ ] **Step 4: Run** `flutter test test/album_background_test.dart` — Expected: FAIL.

- [ ] **Step 5: Implement** `AppBackground`, `FoldedPaperPainter`, `AlbumIcon`, `DecoSvg`/`KanjiDeco`; `SectionLabel`/`InfoPill`/`AppPage.appBar` đổi màu sang `context.album` (`accent`, `paper`, `fold1`, `ink`).

- [ ] **Step 6: Run** `flutter test` — Expected: PASS toàn bộ.

- [ ] **Step 7: Commit** `feat(mobile): folded-paper background, album icon set and kanji decorations`

---

### Task 5: Thẻ ảnh washi và con dấu hanko

**Files:**
- Create: `mobile/lib/core/widgets/album/washi_photo_card.dart`, `mobile/lib/core/widgets/album/hanko_stamp.dart`
- Test: `mobile/test/album_widgets_test.dart`

**Interfaces:**
- Consumes: `context.album`, `KanjiDeco.hanko`, `AppFonts.hand`.
- Produces:
  - `WashiPhotoCard({required Widget photo, required Widget header, Widget? caption, required Widget footer, double tiltDegrees = -1.4})` — giấy `paper`, padding 12, bóng mềm, xoay `tiltDegrees`, băng washi (`WashiTapePainter(tape1, tape2)`, 86×24, sọc chéo 45° bước 6px, xoay 3°, opacity .85) ở giữa mép trên, ảnh `AspectRatio(4/5)`. Xoay bằng `Transform.rotate` (không ảnh hưởng hit-test lệch đáng kể).
  - `WashiPhotoCard.tiltFor(int index) → double` = `index.isEven ? -1.4 : 1.2`.
  - `HankoStamp({required bool stamped, required VoidCallback? onPressed, required String tooltip, double size = 34})` — vòng tròn viền `accent` 2px, xoay -12°, bên trong `KanjiDeco.hanko` màu `accent`; `stamped == true` → nền `accentSoft`, viền đặc; `false` → nền trong suốt, viền + chữ màu `muted`. Khi chuyển sang `stamped` chạy scale 1.15→1 + xoay -18°→-12° trong 180ms, trừ khi `MediaQuery.disableAnimationsOf(context)`. Vùng chạm tối thiểu 44×44; `Semantics(button: true, toggled: stamped, label: tooltip)`.

- [ ] **Step 1: Write the failing test** `album_widgets_test.dart`:
  - `WashiPhotoCard` với `caption: Text('Đèn lồng')` → có `Transform` với góc ≈ `-1.4 * pi / 180`; có `CustomPaint` dùng `WashiTapePainter`; có `AspectRatio(aspectRatio: 0.8)`.
  - `tiltFor(0) == -1.4`, `tiltFor(1) == 1.2`.
  - `HankoStamp(stamped: false, ...)` → bấm gọi `onPressed` đúng một lần; `tester.getSize(find.byType(HankoStamp))` ≥ 44×44; semantics `toggled == false`, label = tooltip.
  - Đổi sang `stamped: true` với `MediaQueryData(disableAnimations: true)` → sau **một** `pump()` không còn frame chờ (`tester.hasRunningAnimations == false`).
  - Đổi sang `stamped: true` bình thường → `hasRunningAnimations == true` sau `pump()`, hết sau `pumpAndSettle()`.

- [ ] **Step 2: Run** `flutter test test/album_widgets_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement** hai widget theo Interfaces.

- [ ] **Step 4: Run** `flutter test test/album_widgets_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit** `feat(mobile): washi photo card and hanko stamp widgets`

---

### Task 6: Thanh điều hướng washi & polaroid

**Files:**
- Create: `mobile/lib/features/shell/presentation/washi_nav_bar.dart`
- Modify: `mobile/lib/features/shell/presentation/app_shell.dart`
- Test: `mobile/test/washi_nav_bar_test.dart`

**Interfaces:**
- Consumes: `context.album`, `AlbumIcon`, `AlbumIcons`, `WashiTapePainter` (Task 5).
- Produces: `class WashiNavItem { final AlbumIcons icon; final String label; }`; `WashiNavBar({required List<WashiNavItem> items, required int currentIndex, required ValueChanged<int> onSelected})`. Mục index 0 vẽ dạng **polaroid** (khung trắng 56×62, padding 5/5/14, xoay 4°, ô màu `accent` chứa icon `photos` trắng) kèm nhãn bên dưới; các mục khác là icon + nhãn, mục đang chọn có mẩu washi (`tape1`, 52×30, xoay -4°, opacity .7) phía sau icon, icon/nhãn màu `accent`, mục khác màu `muted`.

Hình dạng thanh: nền `paper`, bo `BorderRadius.only(topLeft/Right: 4, bottomLeft/Right: 18)`, viền trên như mép giấy xé (painter vẽ đường gạch `fold1` 8px / khe 6px), bóng `Color(0x1A3C2814)`, cao 68, margin `fromLTRB(16, 0, 16, 10)` trong `SafeArea`. Mẩu washi trượt sang tab mới trong 200ms, tắt khi `disableAnimations`.

- [ ] **Step 1: Write the failing test** `washi_nav_bar_test.dart`:
  - `AppShell`-level: pump router thật (demo mode, `backendModeProvider` = demo, `tokenStoreProvider` + `themeStoreProvider` override) tới `/feed` → thấy đủ 5 nhãn đúng thứ tự trái→phải: `Ảnh`, `Bảng tin`, `Khám phá`, `Chat`, `Hồ sơ` (so `tester.getCenter(...).dx` tăng dần); **không** còn `NavigationBar`.
  - Bấm `Khám phá` → route hiện tại là `/discover`; bấm `Ảnh` → `/camera`.
  - `WashiNavBar(currentIndex: 2)` riêng: mục 2 có semantics `selected: true`, các mục khác `false`; màu chữ nhãn mục 2 == `accent`.
  - `MediaQuery(textScaler: TextScaler.linear(1.5))` trên bề rộng 360 → `tester.takeException()` là `null` (không overflow).
  - `disableAnimations: true`, đổi `currentIndex` 1→3 → `hasRunningAnimations == false` sau một `pump()`.

- [ ] **Step 2: Run** `flutter test test/washi_nav_bar_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement** `WashiNavBar`; `AppShell` thay `GlassContainer(NavigationBar)` bằng `WashiNavBar`, nhãn lấy từ `l10n` như cũ, icon map `photos, feed, discover, chat, profile`, `onSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex)`; giữ `extendBody: true`.

- [ ] **Step 4: Run** `flutter test` — Expected: PASS toàn bộ.

- [ ] **Step 5: Commit** `feat(mobile): washi and polaroid bottom navigation`

---

### Task 7: Màn Feed (Bảng tin) mới

**Files:**
- Modify: `mobile/lib/features/feed/presentation/feed_screen.dart`
- Test: `mobile/test/feed_screen_test.dart`

**Interfaces:**
- Consumes: `WashiPhotoCard`, `HankoStamp`, `AlbumIcon`, `KanjiDeco.vertical`, `context.album`, `AppFonts`; không đổi `feedControllerProvider`, `mediaUrlProvider`, `formatPostDay`, `FeedState`, `Post`.
- Produces: không có API mới; các lớp private trong file giữ vai trò cũ (`_FeedError`, `_EmptyFeed`, `_DegradedBanner`, `_PostCard`).

Bố cục (chữ giữ nguyên toàn bộ; spec §7.1):
- Tiêu đề `Khoảnh khắc` (Lora qua `AppBar`), nút `Bạn bè` dùng `AlbumIcon(friends)` thay `Icons.group_outlined` (tooltip giữ).
- Chữ Nhật dọc `KanjiDeco.vertical(themeId)` ở mép phải dưới tiêu đề, màu `accent`, cao ~140, không nhận chạm.
- Nhãn ngày: chuỗi từ `formatPostDay` như cũ, kiểu Lora italic 14, màu `muted`.
- `_PostCard` → `WashiPhotoCard(tiltDegrees: WashiPhotoCard.tiltFor(index))`: header = `AnimalAvatar` 40 + alias (Be Vietnam Pro 600, 1 dòng, `ellipsis`) + thời gian tương đối (`muted`); bấm header vẫn `context.push('/user/<publicId>')`. Caption (nếu có) dùng `AppFonts.hand` 19. Footer: `HankoStamp(stamped: post.likedByMe, tooltip: post.likedByMe ? 'Bỏ thích' : 'Thích', onPressed: toggleLike)` + `'${post.likeCount}'` + `AlbumIcon(comment, size: 21)` + `'${post.commentCount}'`.
- Ảnh đang tải: nền `fold2` + `CircularProgressIndicator`; lỗi: nền `fold2` + `AlbumIcon(imageBroken)`; `url == null`: `AlbumIcon(image)`.
- `_FeedError`: `AlbumIcon(cloudOff, size: 46)`, chữ như cũ, `FilledButton('Thử lại')`. `_EmptyFeed`: `AlbumIcon(emptyAlbum, size: 58, color: muted)` + chữ như cũ. `_DegradedBanner`: nền `accentSoft`, viền `fold1`, chữ như cũ.
- Thẻ xuất hiện lần đầu: trượt lên 12px + từ góc 0 về `tiltFor(index)` trong 250ms, tắt khi `disableAnimations`.

- [ ] **Step 1: Write the failing test** `feed_screen_test.dart` — override `feedControllerProvider` bằng controller giả trả `FeedState` cố định (2 bài cùng ngày + 1 bài hôm trước; 1 bài `likedByMe: true`), `mediaUrlProvider` override theo `mediaId`: bài 1 trả `null`, bài 2 ném lỗi, bài 3 treo (`Completer` không hoàn tất = đang tải). Không dùng URL thật (test không có mạng):
  - Thấy `Khoảnh khắc`, các nhãn ngày đúng chuỗi `formatPostDay`, caption, số like/comment.
  - Không còn widget `GlassContainer`, `Icon` (Material) nào trong `FeedScreen` (`find.descendant(of: find.byType(FeedScreen), matching: find.byType(Icon))` → `findsNothing`).
  - Có 3 `WashiPhotoCard` với góc nghiêng `-1.4, 1.2, -1.4`.
  - Bấm `HankoStamp` của bài thứ nhất → controller giả ghi nhận `toggleLike('<id bài 1>')`.
  - Bài có alias 60 ký tự và caption 5 dòng + emoji trên bề rộng 360 → `tester.takeException() == null`.
  - Ảnh `null`, lỗi, đang tải → mỗi khung vẫn có `AspectRatio(0.8)`; lần lượt có `AlbumIcon(image)`, `AlbumIcon(imageBroken)`, `CircularProgressIndicator`.
  - `FeedState(items: [])` → thấy chuỗi rỗng cũ `Chưa có khoảnh khắc nào…`; `degraded: true` → thấy chuỗi banner cũ.

- [ ] **Step 2: Run** `flutter test test/feed_screen_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement** theo bố cục trên.

- [ ] **Step 4: Run** `flutter test` — Expected: PASS toàn bộ.

- [ ] **Step 5: Commit** `feat(mobile): redesign feed screen as washi photo album`

---

### Task 8: Mục chọn theme trong Cài đặt

**Files:**
- Create: `mobile/lib/features/profile/presentation/theme_picker.dart`
- Modify: `mobile/lib/features/profile/presentation/settings_screen.dart` (chèn `ThemePicker()` làm khối **đầu tiên** của `Column`, trước công tắc khám phá, cách 24)
- Test: `mobile/test/theme_picker_test.dart`

**Interfaces:**
- Consumes: `albumThemeProvider`, `ThemeController.select`, `AlbumPalette.of`, `SectionLabel`.
- Produces: `ThemePicker()` (ConsumerWidget).

Copy cố định (chuỗi mới duy nhất của đợt 1):
- Nhãn mục: `SectionLabel('Màu giao diện')`
- Tên: `Shu · Son đỏ`, `Yuzu · Vàng thanh yên`, `Sakura · Hồng anh đào`, `Sora · Trời xanh`

Mỗi lựa chọn là một ô giấy (`paper`) có 4 vệt màu (`background`, `fold1`, `tape1`, `accent` của theme đó) + tên; ô đang chọn viền `accent` 2px kèm mẩu washi nhỏ. Lưới 2×2, mỗi ô cao ≥ 64, `Semantics(selected:, button: true, label: tên)`.

- [ ] **Step 1: Write the failing test** `theme_picker_test.dart` (store `MemoryThemeStore()`):
  - Thấy `Màu giao diện` và đủ 4 tên đúng chuỗi trên.
  - Ban đầu ô `Shu · Son đỏ` có semantics `selected: true`.
  - Bấm `Sakura · Hồng anh đào` → `container.read(albumThemeProvider) == AlbumThemeId.sakura`; `Theme.of` của cây con đổi `accent` thành của sakura sau `pump()`; store lưu `sakura`.
  - Pump `SettingsScreen` (demo mode) → `ThemePicker` nằm trên `Cho phép khám phá` (so `dy`).

- [ ] **Step 2: Run** `flutter test test/theme_picker_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement** `ThemePicker` và chèn vào `SettingsScreen`.

- [ ] **Step 4: Run** `flutter test` — Expected: PASS toàn bộ.

- [ ] **Step 5: Commit** `feat(mobile): theme picker in settings`

---

### Task 9: Kiểm tra cuối đợt 1

**Files:** không tạo mới (chỉ sửa nếu kiểm tra phát hiện lỗi).

- [ ] **Step 1:** `cd mobile && flutter analyze` — Expected: `No issues found!`
- [ ] **Step 2:** `flutter test` — Expected: tất cả test pass (12 file cũ + 8 file mới).
- [ ] **Step 3:** Chạy kiểm tra thiết kế impeccable trên các file Dart đã đổi/tạo trong đợt 1 (`impeccable detect <files>`); sửa lỗi thật, ghi lại những gì bỏ qua và lý do.
- [ ] **Step 4:** `flutter run -d chrome` → "Mở tài khoản demo" → tab Bảng tin; với **mỗi** theme (đổi trong Hồ sơ → Cài đặt): chụp màn Feed và thanh tab, so với mockup `combined-v1.html` / `nav-options-v1.html` (3). Kiểm: đổi theme áp dụng ngay; tải lại trang vẫn giữ theme (trên web nếu `flutter_secure_storage` không lưu được thì ghi rõ và kiểm trên Android); các màn cũ (Khám phá, Chat, Hồ sơ, Camera) vẫn dùng được và đọc rõ trên nền mới.
- [ ] **Step 5:** Ghi kết quả (ảnh chụp 4 theme, lỗi còn lại) vào mô tả commit cuối hoặc báo cáo cho chủ dự án; dừng để chủ dự án duyệt trước khi sang đợt 2.
