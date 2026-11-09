# UI redesign đợt 5 · Kết bạn — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans.

**Goal:** Làm lại lưới ảnh, Bạn bè, Khám phá, Hồ sơ người khác theo sổ ảnh (spec §7.5), không đổi luồng/controller.

**Spec:** `docs/superpowers/specs/2026-11-09-ui-redesign-design.md` §7.5

## Global Constraints
- Không chữ Nhật; màn làm lại không dùng `GlassContainer`, `GradientButton`, `AppColors`, `Icon` Material (trừ nút quay lại hệ thống); màu từ `context.album`.
- Chữ giữ nguyên; nhãn trình đọc màn hình giữ như cũ (tooltip cũ thành nhãn).
- Vùng chạm ≥ 48pt; chữ 1.5× ở 360pt không tràn.
- Commit lên `feat/ui-redesign`, Conventional Commits, không dòng tác giả AI.

## Review Focus
1. Nút Chấp nhận/Từ chối/Huỷ tắt khi đang xử lý (busyId) và có nhãn.
2. Khám phá: nút Bỏ qua/Kết bạn tắt khi hết thẻ hoặc đang bận; Boost tắt khi bận.
3. Lưới ảnh: bài đang xử lý/bị từ chối vẫn có nhãn; lỗi 404 và lỗi khác giữ thông báo cũ; "Xem thêm ảnh".
4. Hồ sơ người khác: "Huỷ kết bạn" chỉ hiện khi là bạn.
5. Danh sách dài và chữ 1.5× không tràn (tab, tên dài, lời mời có mô tả dài).

### Task 1: Lưới ảnh `PostsGrid` + hộp xem ảnh
### Task 2: Bạn bè và lời mời
### Task 3: Khám phá
### Task 4: Hồ sơ người khác
### Task 5: Kiểm tra toàn bộ + Chrome + review độc lập, sửa Critical/Important, push
