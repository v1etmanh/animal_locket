# UI redesign đợt 6 · Chat — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans.

**Goal:** Làm lại Danh sách chat, Hội thoại, bảng soạn ký hiệu, sheet Tạo ký hiệu / Từ điển theo sổ ảnh (spec §7.6), không đổi luồng/controller/repository.

**Spec:** `docs/superpowers/specs/2026-11-09-ui-redesign-design.md` §7.6

## Global Constraints
- Không chữ Nhật; màn làm lại không dùng `GlassContainer`, `GradientButton`, `AppColors`, `Icon` Material (trừ nút quay lại hệ thống); màu từ `context.album`.
- Chữ và chuỗi l10n giữ nguyên; nhãn trình đọc màn hình giữ như cũ (tooltip cũ thành nhãn).
- Vùng chạm ≥ 48pt; chữ 1.5× ở 360pt không tràn.
- Màu glyph (`colorArgb`) là dữ liệu người dùng: không đổi.
- Commit lên `feat/ui-redesign`, Conventional Commits, không dòng tác giả AI.

## Review Focus
1. Bảng soạn: Gửi tắt khi chưa chọn / đang gửi / hội thoại đóng; chọn nhanh và × tắt khi bận; Tạo tắt khi đóng.
2. Tin gửi lỗi vẫn có "Thử lại"; tin đang gửi vẫn mờ; glyph không rõ vẫn hiện chữ thay thế.
3. Tạo ký hiệu: Lưu tắt khi nét < 5 điểm, thiếu nghĩa hoặc trùng ≥ .85.
4. Danh sách chat: số chưa đọc có nhãn đọc màn hình; lỗi/rỗng giữ chữ.
5. Chữ 1.5× không tràn (biệt danh dài, nhiều glyph, sheet có bàn phím).

### Task 1: Thành phần dùng chung + icon mới
`DashedDivider`, `MiniPolaroidAvatar` tách từ `friends_screen.dart` sang `core/widgets/album/`; Bạn bè dùng lại. Icon `eye`, `eye_off`, `book`, `plus`, `refresh`. `PaperTileButton` nhận `child` thay icon (cho glyph).
### Task 2: Danh sách chat
### Task 3: Hội thoại (mẩu giấy ghi chú, nhãn đóng, lỗi)
### Task 4: Bảng soạn + ô vẽ + token
### Task 5: Sheet Tạo ký hiệu / Từ điển
### Task 6: Kiểm tra toàn bộ + Chrome + review độc lập, sửa Critical/Important, push
