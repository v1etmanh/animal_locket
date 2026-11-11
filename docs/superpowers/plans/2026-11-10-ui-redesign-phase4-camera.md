# UI redesign đợt 4 · Chụp ảnh — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Làm lại Camera, Xem trước và nhãn trạng thái gửi theo sổ ảnh (spec §7.4), không đổi luồng chụp/gửi.

**Spec:** `docs/superpowers/specs/2026-11-09-ui-redesign-design.md` §7.4

## Global Constraints
- Không chữ Nhật; màn làm lại không dùng `GradientButton`, `AppColors`, `Icon` Material, `IconButton.filledTonal`; màu từ `context.album`.
- Chữ giữ nguyên trừ câu xin quyền camera mới.
- Logic camera (quyền, khởi tạo, vòng đời, flash, lật, lấy nét, chụp, chọn ảnh) và `UploadController` không đổi.
- Vùng chạm ≥ 48pt; chữ 1.5× không tràn; nhãn trình đọc màn hình giữ như cũ.
- Commit lên `feat/ui-redesign`, Conventional Commits, không dòng tác giả AI.

## Review Focus
1. Nhãn trạng thái gửi đọc rõ trên mọi nền ảnh, các nút "Xem / Thử lại / Đóng" vẫn bấm được và có nhãn.
2. Thanh tab không đè nút chụp ở máy thấp (640pt).
3. Nút chụp/flash tắt khi camera chưa sẵn sàng.
4. Xem trước: ảnh lỗi/không có đường dẫn vẫn giữ khung 4:5; bàn phím mở không làm tràn.
5. Chữ 1.5× trên 360pt cho cả 2 màn.

### Task 1: Widget dùng chung — `PhotoCornersFrame`, `PaperTileButton`, icon mới
- Test `test/camera_widgets_test.dart`: khung có 4 góc (CustomPaint `PhotoCornersPainter`), child lấp đầy; ô giấy có nhãn semantics, bấm gọi callback, tắt thì không, ≥ 48pt.
- Icon: `flashAuto`, `flashOn`, `flashOff`, `gallery`, `flipCamera`, `camera`, `send`, `close`, `alert`.
- Commit `feat(mobile): photo-corner frame and folded paper tiles`

### Task 2: Nhãn trạng thái gửi
- Test `test/send_status_pill_test.dart` (UploadController giả theo từng stage): chữ, nút hành động, nền giấy + washi, live region, không Icon Material.
- Commit `feat(mobile): send status as a taped paper label`

### Task 3: Camera
- Test `test/camera_screen_test.dart` (giả kênh `permission_handler` trả "denied"): tiêu đề, câu xin quyền mới, nút "Cho phép camera", khung góc ảnh, ô Thư viện/Lật có nhãn, nút chụp + flash tắt khi chưa sẵn sàng, không `Icon`/`AppColors`; 1.5× ở 360×640 không tràn.
- Commit `feat(mobile): camera viewfinder as a photo with album corners`

### Task 4: Xem trước
- Test `test/preview_screen_test.dart`: tấm ảnh dán băng 4:5 (không có ảnh thì icon ảnh), lời nhắn viết tay (Patrick Hand, max 200, nhãn + gợi ý), "Gửi cho bạn bè" + icon gửi, đang gửi thì nhãn đổi và tắt, "Chụp lại" quay lại, ghi chú; 1.5× không tràn.
- Commit `feat(mobile): preview as a taped print with a handwritten note`

### Task 5: Kiểm tra toàn bộ + review độc lập, sửa Critical/Important, push.
