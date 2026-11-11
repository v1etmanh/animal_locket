# UI redesign đợt 7 · Hồ sơ — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans.

**Goal:** Làm lại Hồ sơ của tôi, Cài đặt, Pro theo sổ ảnh (spec §7.7) và xoá `GlassContainer`, `GradientButton`, `AppColors`; không đổi luồng/controller/repository.

**Spec:** `docs/superpowers/specs/2026-11-09-ui-redesign-design.md` §7.7

## Global Constraints
- Không chữ Nhật; không `GlassContainer`, `GradientButton`, `AppColors`, `Icon` Material; màu từ `context.album`.
- Chữ giữ nguyên; tooltip cũ thành nhãn trình đọc màn hình.
- Vùng chạm ≥ 48pt; chữ 1.5× ở 360pt không tràn.
- Commit lên `feat/ui-redesign`, Conventional Commits, không dòng tác giả AI.

## Review Focus
1. Xoá tài khoản vẫn hai bước (hộp thoại + gõ XOÁ); đăng xuất/xoá tắt khi bận.
2. Công tắc khám phá: tắt thì vẫn xoá vị trí; lỗi thì hoàn lại.
3. Pro: nút mua tắt khi `busy`; dưới 18 không thấy ưu đãi; khôi phục chỉ khi có cửa hàng.
4. Hồ sơ: nút Pro chỉ hiện cho người lớn chưa Pro; đổi biệt danh giữ giới hạn 20.

### Task 1: Thành phần dùng chung + icon (`GoldBadge`, `TapedNote`, `onlineGreen`; icon settings/edit/logout)
### Task 2: Hồ sơ của tôi
### Task 3: Cài đặt
### Task 4: Pro
### Task 5: Xoá `GlassContainer`, `GradientButton`, `AppColors`; sửa test
### Task 6: Kiểm tra toàn bộ + Chrome + review độc lập, sửa Critical/Important, push
