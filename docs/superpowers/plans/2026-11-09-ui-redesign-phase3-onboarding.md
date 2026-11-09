# UI redesign đợt 3 · Vào app — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Bỏ chữ Nhật khỏi UI, thêm nút giấy/polaroid dùng chung, làm lại 3 màn Đăng nhập · Thiết lập an toàn · Nhận avatar theo sổ ảnh.

**Architecture:** Widget dùng chung mới trong `mobile/lib/core/widgets/album/` (`PaperButton`, `Polaroid`), `HankoStamp` nhận hình khắc bằng icon. Ba màn trong `features/auth/presentation` chỉ đổi lớp trình bày; luồng, route, controller giữ nguyên.

**Tech Stack:** Flutter 3.47, Riverpod 3, flutter_svg, go_router.

**Spec:** `docs/superpowers/specs/2026-11-09-ui-redesign-design.md` §2 (không chữ Nhật), §7.3

## Global Constraints

- Không ký tự Nhật (U+3040–30FF, U+4E00–9FFF) trong `lib/` và `assets/` (trừ không có ngoại lệ).
- Màn làm lại không dùng `GlassContainer`, `GradientButton`, `AppColors`, `Icon` Material; màu lấy từ `context.album`.
- Chữ giữ nguyên trừ 3 thay đổi đã chốt ở §7.3 (câu đăng nhập mới, "ảnh chưa rửa…", "Chạm để chọn ngày sinh").
- Vùng chạm ≥ 48pt; chữ 1.5× không tràn; giảm chuyển động thì không chạy hiệu ứng.
- Commit Conventional Commits, không dòng tác giả AI; commit lên nhánh `feat/ui-redesign`.

## Review Focus

1. Cỡ chữ 1.5× trên máy 360pt: nút giấy, 3 ô ngày, polaroid không tràn.
2. Đọc màn hình: nút giấy là button có nhãn; con dấu đồng ý là checkbox/toggle có nhãn câu điều khoản; 3 ô ngày đọc thành một nút.
3. Nút tắt (chưa đủ ngày sinh + đồng ý; đang đăng ký; đang quay) không nhận chạm.
4. Avatar trong polaroid không bị cắt tròn và không tràn khung.
5. Bảng tin sau khi bỏ chữ dọc: thẻ ảnh vẫn trọn trong trang, không lệch.

---

### Task 1: Bỏ chữ Nhật, con dấu khắc hình
- Test: `test/no_japanese_text_test.dart` quét `lib/` và `assets/` không có ký tự Nhật; sửa `album_background_test` (bỏ asset deco), `album_widgets_test` (con dấu dùng `AlbumIcon` khắc hình, mặc định trái tim), `feed_screen_test` (bỏ test chữ dọc; thẻ ảnh cách đều hai bên).
- Code: xoá `assets/deco/*`, `KanjiDeco`, trường `kanji` của `AlbumPalette`; `HankoStamp({mark = AlbumIcons.heart})`; icon mới `heart`, `check`; Bảng tin bỏ `DecoSvg` chữ dọc, lề thẻ `fromLTRB(10, 12, 10, 0)`.
- Commit `refactor(mobile): drop Japanese glyphs from the UI`

### Task 2: `PaperButton` và `Polaroid`
- Test `test/paper_widgets_test.dart`: nhãn + icon hiện; bấm gọi callback; `onPressed: null` không gọi và semantics `enabled: false`; cao ≥ 52; 1.5× ở 360pt không tràn; có mép răng cưa (`ClipPath` với `TornPaperClipper`) và góc gấp; `.tape` có băng washi; `Polaroid` hiện child + chú thích viết tay, khung vuông.
- Code: `lib/core/widgets/album/paper_button.dart`, `lib/core/widgets/album/polaroid.dart`; icon mới `mail`, `arrow_right`, `dice`, `cake` (nếu cần).
- Commit `feat(mobile): torn-paper buttons and polaroid frame`

### Task 3: Đăng nhập
- Test `test/sign_in_screen_test.dart` (fake `AuthController`): chữ (gồm câu mới), không Glass/Icon Material/AppColors; 2 `Polaroid` với avatar cáo, gấu trúc; bấm "Đăng nhập bằng email" gọi `signIn`, "Mở tài khoản demo" gọi `enterDemo`; khi `checking` cả hai tắt và nhãn "Đang mở đăng nhập…"; lỗi hiện thông báo; 1.5× không tràn.
- Commit `feat(mobile): sign-in as an album cover`

### Task 4: Thiết lập an toàn
- Test `test/birth_consent_screen_test.dart`: chữ hiện tại + "Chạm để chọn ngày sinh"; 3 ô `--/--/----`; chọn ngày (qua date picker) thì ô hiện đúng; con dấu đồng ý là toggle có nhãn câu điều khoản; "Tiếp tục" tắt tới khi đủ, bật thì `go('/reveal?birthDate=yyyy-MM-dd')`; 1.5× không tràn.
- Commit `feat(mobile): birth date and consent as a taped paper slip`

### Task 5: Nhận avatar
- Test `test/reveal_screen_test.dart` (fake `registerProfile`): trước khi quay polaroid "?" + "ảnh chưa rửa…"; ô biệt danh + nút xúc xắc đổi tên; bấm "Quay avatar" → hiện avatar vuông trong polaroid, chú thích tên con vật, "Chào …", "… · không ai khác có avatar này"; "Vào app" gọi `finishRegistration`; lỗi API hiện dưới ô; giảm chuyển động thì không quay; 1.5× không tràn.
- Code: `AnimalAvatar(square: true)` (ClipRect thay ClipOval).
- Commit `feat(mobile): reveal avatar as a developing polaroid`

### Task 6: Kiểm tra toàn bộ
- `flutter test`, `flutter analyze`, chạy Chrome (chế độ demo) soát 3 màn + Bảng tin; review nhánh bằng reviewer độc lập; sửa Critical/Important.
