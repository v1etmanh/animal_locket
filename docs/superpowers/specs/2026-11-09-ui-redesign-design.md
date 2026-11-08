# Làm lại giao diện app mobile — "album giấy gấp"

Ngày: 2026-11-09 · Phạm vi tài liệu: toàn bộ chương trình làm lại, chi tiết cho **đợt 1 (Core)**.
Mockup đã duyệt (throwaway, không commit): `.superpowers/brainstorm/990-1794159769/content/` — `combined-v1.html` (bố cục), `theme-set-v1.html` (bảng màu), `nav-options-v1.html` (thanh điều hướng, phương án 3).

## 1. Ý định

Giao diện hiện tại của app Flutter (`mobile/`) trông "AI-slop": theme kính mờ (glassmorphism) tím, gradient, icon Material mặc định, thanh tab `NavigationBar` chuẩn. Chủ dự án muốn một bản có cá tính: **chút vibe Nhật, tươi sáng, ấm áp, như một cuốn album ảnh**, với avatar mặt thú kiểu **origami**.

Thành công = mở app thấy ngay "sổ ảnh giấy gấp" có chủ đích, không còn cảm giác template; không màn nào còn sót kính tím/icon mặc định sau khi đợt của nó xong.

## 2. Mục tiêu, không mục tiêu, phản mục tiêu

**Mục tiêu**
- Làm lại toàn bộ phần nhìn: element, font, màu, icon, asset, khoảng cách, chuyển động.
- Hệ thống theme **chỉ đổi bảng màu**, 4 theme, người dùng tự chọn.
- Avatar origami (thư viện v2) — đợt 2.

**Không mục tiêu**
- Không đổi nội dung chữ, luồng màn hình, thứ tự tab, hành vi, API, logic state (Riverpod/repository). Chỉ đổi lớp trình bày.
- Không đổi backend (user-service, kho avatar 3.000 mã giữ nguyên).
- Không theme tối, không theme đổi "chất liệu" (dải phim…). Không giới hạn theme cho Pro.

**Phản mục tiêu** (làm vậy là hỏng dù chạy được)
- Thanh điều hướng trông như tab mặc định: icon vuông vô hồn, nút giống mọi app khác. Đây là điểm chủ dự án lo nhất.
- Trang trí Nhật kiểu "dán cho có" (chữ Nhật khắp nơi, hoa văn sáo rỗng). Chữ Nhật chỉ là điểm nhấn hiếm.
- Chữ tiếng Việt bị lỗi dấu, hoặc tương phản kém (mọi chữ đạt WCAG AA trên mọi theme).

## 3. Hướng thị giác đã chốt

Ghép từ 3 hướng đã xem:

| Phần | Nguồn | Mô tả |
|---|---|---|
| Nền | hướng C "Origami pop" | Nền giấy sáng ấm theo theme, vài **khối giấy gấp** (hình vuông xoay 28–60°) màu nhạt tràn mép, đứng yên phía sau nội dung |
| Feed / thẻ ảnh | hướng A "Sổ ảnh washi" | Ảnh như ảnh in dán vào sổ: viền giấy trắng ngà, bóng mềm, **nghiêng nhẹ** (±1–2°, xen kẽ), **băng washi** sọc chéo dán mép trên; caption **chữ viết tay**; nút thích là **con dấu hanko** tròn nghiêng (chữ 好); ngày kiểu nghiêng serif ("Thứ Bảy, 8 tháng 11"); chữ Nhật dọc trang trí mép phải (ví dụ 思い出のアルバム) |
| Thanh điều hướng | hướng B, phương án 3 "Băng washi & polaroid" | Viên nổi bo tròn phía dưới (bo 4px trên, 18px dưới), viền trên như mép giấy xé; tab đang chọn có **mẩu băng washi dán chéo** sau icon; icon nét mảnh chủ đề album; tab **Ảnh** (camera) là **tấm polaroid nhỏ nghiêng** |

**Thanh tab giữ nguyên thứ tự và nhãn hiện tại**: Ảnh · Bảng tin · Khám phá · Chat · Hồ sơ (`l10n.photosTab`…). Tab Ảnh nằm ở vị trí đầu như hiện tại, chỉ đổi dạng thành polaroid. *(Lựa chọn của người viết; mockup đặt nút chụp ở giữa — xem §9.)*

### 3.1 Typography

| Vai trò | Font | Ghi chú |
|---|---|---|
| Tiêu đề, ngày | **Lora** (700, 500 italic) | thay Fraunces |
| Chữ thường, nhãn, nút | **Be Vietnam Pro** (400/500/600/700) | thay Plus Jakarta Sans |
| Caption ảnh, ghi chú tay | **Patrick Hand** | chỉ cho chữ "viết tay"; không dùng cho chữ chức năng |
| Chữ Nhật trang trí | không nhúng font | 好, 思い出のアルバム… vẽ sẵn thành SVG asset (tránh nhúng font CJK nhiều MB) |

Cả ba font hỗ trợ đủ dấu tiếng Việt, giấy phép OFL; nhúng file `.ttf` vào `assets/fonts/` (kèm file giấy phép) như cách đang làm, không tải lúc chạy. Bỏ Fraunces và Plus Jakarta Sans khi không còn màn nào dùng (cuối chương trình).

### 3.2 Icon

Bộ icon **vẽ riêng** (SVG, `flutter_svg` đã có): nét ~1.8 trên lưới 24, đầu nét bo tròn, chủ đề sổ ảnh (hai tấm ảnh chồng, ghim bản đồ, bóng thoại, thẻ hồ sơ, máy ảnh…). Màu theo `currentColor` để đổi theo theme/trạng thái. Đợt 1 vẽ icon cho thanh điều hướng và mọi icon xuất hiện trên màn Feed; các đợt sau bổ sung icon của màn mình. Không dùng `Icons.*` của Material trên màn đã làm lại.

### 3.3 Chuyển động *(lựa chọn của người viết, giữ nhẹ)*

- Thẻ ảnh xuất hiện: trượt lên + xoay về góc nghiêng của nó (~250ms).
- Bấm thích: con dấu "đóng" xuống (scale 1.15→1 + xoay nhẹ, ~180ms).
- Đổi tab: mẩu washi trượt sang tab mới (~200ms).
- Tôn trọng "giảm chuyển động" của hệ điều hành (tắt hiệu ứng, chỉ đổi trạng thái).

## 4. Hệ thống theme

Mỗi theme là một bảng màu; mọi thành phần chỉ đọc màu qua token, **không hard-code màu** trong màn hình.

| Token | Shu · Son đỏ *(mặc định)* | Yuzu · Vàng thanh yên | Sakura · Hồng anh đào | Sora · Trời xanh |
|---|---|---|---|---|
| `background` | `#FFF8EF` | `#FFFAEA` | `#FFF6F1` | `#F6F9FB` |
| `paper` (thẻ ảnh, thanh tab) | `#FFFDF8` | `#FFFEF8` | `#FFFDFB` | `#FFFFFF` |
| `fold1/2/3` (khối giấy gấp) | `#FFE3C2` `#FFE9DC` `#FDE4C8` | `#FFEEB8` `#FFF3D1` `#FFE6A6` | `#FFE0D2` `#FFDBE5` `#FFE9C9` | `#D9EBF6` `#E8F2F9` `#FFE9D6` |
| `tape1/2` (sọc washi) | `#F4B9A3` `#F9D3C3` | `#F7CF6B` `#FBE3A3` | `#F6B8C8` `#FBD7E1` | `#9CC7E3` `#C8E1F1` |
| `accent` (con dấu, tab chọn, nút chính) | `#B8402A` | `#A35C00` | `#B23A5B` | `#2F5F8A` |
| `accentDeep` (bóng nút) | `#8A2C1B` | `#7A4400` | `#842640` | `#204465` |
| `accentSoft` (nền nhấn nhạt) | `#FDEAE2` | `#FFF4D6` | `#FBDDE6` | `#DCEAF5` |
| `muted` (chữ phụ) | `#6A5B4E` | `#6B5D45` | `#6C5A58` | `#56616B` |
| `ink` (chữ chính) | `#2B2420` (chung) | ← | ← | ← |

Chữ Nhật trang trí theo theme: Shu 朱, Yuzu 柚, Sakura 桜, Sora 空.
`danger` (xoá, lỗi) và màu trạng thái giữ chung cho 4 theme; builder chọn sao cho đạt AA trên `paper`.

**Hành vi**
- Chọn theme ở một mục trong **Cài đặt** (đợt 1 thêm mục này vào màn Cài đặt hiện có; phần nhìn còn lại của màn Cài đặt làm ở đợt 7). Xem trước 4 ô màu, bấm là áp dụng ngay, không cần khởi động lại.
- Lưu trên máy, không cần backend; chế độ demo cũng đổi được. Mặc định Shu khi chưa chọn.
- Mọi theme mở cho tất cả người dùng.
- Trên mọi theme, chữ `ink`/`muted`/`accent` trên `background`/`paper`/`accentSoft` phải đạt WCAG AA (4.5:1 chữ thường, 3:1 chữ lớn). Bảng trên là điểm xuất phát; được chỉnh sắc độ để đạt AA nhưng giữ tinh thần màu.

## 5. Avatar origami (đợt 2 — chỉ ghi ràng buộc)

- Vẽ lại cả 50 con vật kiểu giấy gấp (mặt ghép từ mảnh tam giác, mỗi mảnh một sắc độ) thành **thư viện v2**, sinh bằng `libs/avatar-lib/build-lib.mjs`, xuất `avatar-lib.v2.json` cho mobile.
- **Giữ nguyên bộ khoá**: 50 con vật × 10 bảng màu × 6 phụ kiện, cùng mã (`fox:0:none`…). Kho avatar trên server không đổi. 10 bảng màu phải vẫn phân biệt rõ trên hình origami.
- App vẽ mọi avatar bằng v2 (người đang có `fox:0:none` thấy con cáo của mình chuyển sang origami).
- Đây là thay đổi quy tắc của docs/19 ("bản mới không đổi nghĩa hình cũ"): đợt 2 phải cập nhật docs/19 và thêm ADR.
- Đợt 1 dùng avatar hiện tại, chỉ đặt trong khung mới.

## 6. Chia đợt

Mỗi đợt xong thì dừng để chủ dự án duyệt trên chế độ demo, rồi mới sang đợt sau.

| Đợt | Nội dung |
|---|---|
| **1 · Core** (tài liệu này chi tiết) | Hệ thống theme + mục chọn theme; font; nền giấy gấp; thành phần dùng chung; bộ icon cho nav + Feed; thanh điều hướng; màn **Feed** (Bảng tin) |
| 2 · Avatar origami | Thư viện v2, docs/19, ADR |
| 3 · Vào app | Đăng nhập, xác nhận ngày sinh, màn "lộ" avatar |
| 4 · Chụp ảnh | Camera, xem trước |
| 5 · Kết bạn | Bạn bè, khám phá, hồ sơ người khác |
| 6 · Chat | Danh sách chat, hội thoại glyph |
| 7 · Hồ sơ | Hồ sơ của tôi, cài đặt (phần còn lại), Pro |

**Màn chưa làm lại nhận theme mới ngay từ đợt 1** (chủ dự án chốt): ThemeData, font, nền giấy gấp và màu theme áp cho toàn app; các màn cũ vẫn còn sót `GlassContainer`, `GradientButton`, màu cố định trong `AppColors` và icon Material cho tới đợt của chúng. Không giữ song song hệ theme cũ và mới. Chấp nhận app "nửa cũ nửa mới" trong lúc duyệt, miễn là màn cũ vẫn dùng được và chữ vẫn đọc rõ (đạt AA) trên nền mới.

## 7. Đợt 1 chi tiết

**Hiện trạng liên quan**: màu gom ở `core/theme/app_colors.dart` (hằng số tĩnh), `core/theme/app_theme.dart` (ThemeData seed tím); widget dùng chung `core/widgets/` (`glass_container` dùng ở 15 chỗ, `gradient_button` 5 chỗ, `app_background`, `app_page`, `animal_avatar`, `text_input_dialog`); thanh tab ở `features/shell/presentation/app_shell.dart` (`NavigationBar` + `GlassContainer`); Feed ở `features/feed/presentation/` (`feed_screen.dart`, `posts_grid.dart`).

**Kết quả cần có**
1. Token màu theo theme, truy cập được từ mọi widget; ThemeData dựng từ theme đang chọn; đổi theme cập nhật toàn app ngay.
2. Ba font mới đăng ký trong `pubspec.yaml`; text theme map Lora/Be Vietnam Pro/Patrick Hand.
3. Nền giấy gấp thay `app_background` (khối giấy vẽ bằng code theo token `fold*`).
4. Thành phần dùng chung mới, đủ cho Feed và để các đợt sau tái dùng: thẻ ảnh washi (ảnh + băng + nghiêng), con dấu hanko (trạng thái thích/chưa thích), nút chính/phụ (thay `gradient_button`), ô nhập, hộp thoại xác nhận, chip đếm, tiêu đề trang + dòng ngày.
5. Thanh điều hướng mới trong `app_shell.dart`, giữ nguyên nhánh, thứ tự, nhãn và hành vi `goBranch`.
6. Màn Feed (`feed_screen.dart`) làm lại hoàn toàn bằng thành phần mới: danh sách bài bạn bè, trạng thái tải/lỗi/rỗng. Mọi chữ giữ nguyên (xem §7.1). `PostsGrid` (`posts_grid.dart`) **không** thuộc đợt 1: nó chỉ hiển thị ở Hồ sơ và Hồ sơ người khác, nên làm cùng đợt 5/7.
7. Mục chọn theme trong màn Cài đặt.
8. Widget cũ (`glass_container`, `gradient_button`) **giữ lại** cho màn chưa làm; xoá ở đợt cuối khi không còn chỗ dùng.

### 7.1 Mockup với chữ thật: chữ hiện tại luôn thắng

Mockup chỉ là tham chiếu phần nhìn; chữ mẫu trong mockup không phải yêu cầu. Cụ thể với Feed:
- Tiêu đề trang giữ **"Khoảnh khắc"** (mockup ghi "Bạn bè").
- Không thêm dòng ngày dưới tiêu đề. Nhãn ngày của từng bài giữ `formatPostDay` ("Hôm nay", "Hôm qua", `dd/MM/yyyy`), chỉ đổi kiểu chữ sang Lora nghiêng.
- Lượt thích/bình luận giữ dạng số + icon như hiện tại; icon thích chuyển thành con dấu hanko, icon bình luận dùng bộ icon mới.
- Chữ Nhật dọc (ví dụ 思い出のアルバム) là **trang trí** (asset SVG theo theme, không phải chuỗi giao diện, không cần dịch), được phép thêm.

### 7.2 Thanh điều hướng trên tab Ảnh (camera)

Tab Ảnh (`/camera`) là màn đầu tiên sau đăng nhập và có khung ngắm toàn màn hình nằm dưới thanh tab (`extendBody`). Thanh tab giữ **cùng một dạng** trên mọi tab, kể cả trên khung ngắm (nền `paper` đặc, có bóng, nên vẫn đọc rõ). Tab Ảnh vẫn có nhãn **"Ảnh"** dưới tấm polaroid (giữ nhãn hiện tại). *(Lựa chọn của người viết.)*

**Kiểm tra trước khi giao đợt 1**
- `flutter analyze` sạch, `flutter test` xanh (12 file test hiện có không được hỏng; thêm test cho việc lưu/khôi phục theme và cho thanh tab giữ đúng 5 nhánh).
- Chạy chế độ demo trên Chrome và (nếu được) điện thoại thật: Feed + thanh tab đúng mockup trên **cả 4 theme**, đổi theme áp dụng ngay và còn sau khi mở lại app.
- Kiểm tra tương phản AA của token trên 4 theme.
- Chạy kiểm tra thiết kế impeccable trên các file đã đổi.

## 8. Ràng buộc

- Flutter (SDK hiện có 3.41), Riverpod, go_router — giữ nguyên kiến trúc; không thêm thư viện UI lớn. Dùng gói đã cài trước khi thêm gói mới.
- Chữ tiếng Việt, i18n qua `l10n` hiện có — không đổi chuỗi.
- Chế độ demo là đường kiểm tra chính (không cần backend).
- Không đụng backend, API, `libs/` (trừ avatar-lib ở đợt 2).

## 9. Lựa chọn người viết tự quyết (chủ dự án nên rà)

- Giữ thứ tự tab hiện tại; tab Ảnh dạng polaroid ở vị trí đầu thay vì nút giữa như mockup.
- Font Lora / Be Vietnam Pro / Patrick Hand; chữ Nhật trang trí dạng SVG.
- Shu là theme mặc định.
- Chuyển động như §3.3.
- Mục chọn theme nằm trong màn Cài đặt hiện có.
- `PostsGrid` để sang đợt 5/7; chữ hiện tại thắng chữ mẫu trong mockup (§7.1).
- Thanh tab giống nhau trên mọi tab, kể cả trên camera; tab Ảnh giữ nhãn (§7.2).

## 10. Để builder quyết

Cấu trúc thư mục/tên lớp của hệ token và thành phần; cơ chế lưu lựa chọn theme trên máy (ưu tiên gói đã có); cách vẽ khối giấy gấp và sọc washi (CustomPainter hay SVG); chi tiết từng icon; tinh chỉnh sắc độ để đạt AA; số liệu khoảng cách/bo góc cụ thể (bám theo mockup).
