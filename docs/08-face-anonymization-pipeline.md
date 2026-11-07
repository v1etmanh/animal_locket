# 8. Pipeline ẩn mặt (face-worker)

> **ĐÃ NGỪNG DÙNG.** Tính năng ẩn mặt bằng AI đã bị gỡ khỏi hệ thống: `face-worker` không còn trong docker-compose, `media-service` chuyển ảnh thẳng từ bucket `raw` sang `public` khi nhận `complete` rồi phát `PHOTO_READY` (method `NONE`). Tài liệu bên dưới giữ lại để tham khảo, KHÔNG còn mô tả hành vi hiện tại. Xoá EXIF/GPS hiện do client làm (`keepExif: false`).

Đây là tính năng cốt lõi và rủi ro lớn nhất của sản phẩm. Tài liệu mô tả **đúng những gì code trong `face-worker/` làm**, cách đo chất lượng và các giới hạn đã biết.

## 8.1 Tổng quan luồng

```
Client ──(1) POST /media/uploads──► media-service  → job PENDING_UPLOAD + biểu mẫu POST (MinIO)
Client ──(2) POST form ───────────► MinIO bucket raw  (private, ≤10MB, đúng Content-Type, 5 phút)
Client ──(3) POST /media/{id}/complete ► media-service: statObject, snapshot con vật chủ đạo
        job UPLOADED ─ Outbox ─► Kafka media.events  PHOTO_UPLOADED{mediaId, rawKey, leadAnimal,...}

face-worker (consumer group "face-worker"):
   a. idempotent? pub/{mediaId}.jpg đã có → chỉ phát lại FACE_PROCESSED (đọc method/faces từ metadata)
   b. tải raw → decode_clean → detect → replace → encode JPEG
   c. put pub/{mediaId}.jpg (metadata method, faces) → xoá raw → phát FACE_PROCESSED lên media.results
   d. lỗi tạm thời: retry 3 lần (backoff 1.5s, 3s) → DLQ + FACE_FAILED(PROCESSING_FAILED)
   e. ảnh hỏng/quá lớn/raw mất: FACE_FAILED ngay (không retry)

media-service: FACE_PROCESSED → job READY → PHOTO_READY ─► post-service PUBLISHED
               FACE_FAILED / quá 10 phút không có kết quả → REJECTED → PHOTO_REJECTED
```

**Nguyên tắc fail closed**: không có `FACE_PROCESSED` thì ảnh **không bao giờ** được đăng hoặc cấp URL xem.

## 8.2 Từng bước xử lý ảnh (`facework/pipeline.py`)

### 1. `decode_clean(raw, cfg)` — giải mã an toàn và xoá metadata

1. Đặt `Image.MAX_IMAGE_PIXELS = MAX_PIXELS` (mặc định 40 triệu điểm ảnh). Ảnh vượt ngưỡng → `ImageRejected("IMAGE_TOO_LARGE")` (chống decompression bomb).
2. `Image.open().load()`; lỗi bất kỳ → `ImageRejected("UNREADABLE_IMAGE")` (không retry vì vô ích).
3. Ảnh động (nhiều khung): chỉ lấy khung đầu.
4. `ImageOps.exif_transpose` — áp dụng hướng xoay theo EXIF **trước khi** bỏ EXIF.
5. Ảnh có alpha/palette: dán lên nền trắng, đổi sang RGB.
6. Nếu cạnh dài > `MAX_SIDE_PX` (2048): thu nhỏ bằng LANCZOS.
7. **`Image.frombytes("RGB", size, img.tobytes())`**: tạo ảnh mới chỉ từ điểm ảnh ⇒ mất mọi EXIF, GPS, ICC, thumbnail, XMP.

Bằng chứng đã xoá EXIF (test `test_exif_and_gps_are_stripped_and_orientation_applied`): ảnh đầu vào có `Orientation=6`, `Make="SecretPhoneMaker"` và khối GPS; sau xử lý `getexif()` rỗng, byte `SecretPhoneMaker` không còn trong dữ liệu, kích thước đã hoán đổi theo hướng xoay. `encode_jpeg` không truyền tham số `exif=`, nên không có cơ hội ghi lại.

### 2. Phát hiện mặt (`facework/detect.py`)

Nguyên tắc: **thà che thừa còn hơn sót**, nên dùng nhiều detector và hợp nhất bằng phép hợp (union).

| Detector | Cấu hình | Ghi chú |
|---|---|---|
| `HaarDetector` | `haarcascade_frontalface_default`, `…_alt2` (scale 1.08, minNeighbors 2), `profileface` (scale 1.1, minNeighbors 3) chạy cả trên ảnh lật ngang; ảnh xám + `equalizeHist`; `minSize = max(20, 2% cạnh ngắn)` | Chạy CPU, có sẵn trong OpenCV **4.x** |
| `YuNetDetector` | `cv2.FaceDetectorYN`, ngưỡng `YUNET_SCORE=0.3`, NMS 0.3, top-k 5000 | Chính xác hơn với mặt nhỏ/nghiêng. Cần file `face_detection_yunet_2023mar.onnx` (Dockerfile tải sẵn vào `/models`); thiếu file thì **bỏ qua kèm cảnh báo** |

- `DETECTORS` (mặc định `haar,yunet`) chọn detector; phải còn ít nhất một, nếu không worker không khởi động.
- Một detector ném lỗi chỉ bị ghi log, các detector khác vẫn chạy.
- `merge_boxes`: hai hộp được hợp nhất thành hộp bao nếu IoU ≥ 0.25 hoặc tâm của hộp này nằm trong hộp kia. Hộp lớn xử lý trước.
- Các mặt được sắp theo diện tích giảm dần; **mặt lớn nhất lấy con vật chủ đạo** của người đăng. `OTHER_FACES=same` (mặc định): mọi mặt khác cũng dùng con vật đó; `random`: mặt còn lại lấy ngẫu nhiên trong 17 con cơ bản.

### 3. Hộp che (`facework/replace.py`)

Hộp mặt được nới để bao cả tóc, trán, cằm: `SIDE=0.25`, `TOP=0.45`, `BOTTOM=0.15` (nhân với rộng/cao hộp, cắt theo khung ảnh). Chỉ **thay hoàn toàn** vùng này, không blur.

### 4a. Sticker 2D (`StickerReplacer`) — luôn có sẵn

- `stickers.render(animal, size)` vẽ mặt con vật bằng Pillow (siêu lấy mẫu ×4), không cần file ảnh. 25 con có kiểu riêng; mã lạ dùng kiểu mặc định.
- Kích thước: `size = ceil( hypot(w', h') / 2 / 0.40 × 1.05 )` với `w', h'` là kích thước hộp đã nới. Đĩa mặt của sticker có bán kính `0.40 × size`, nên **phủ kín cả bốn góc của hộp** (hộp nới đã chứa hộp mặt gốc). Các test `test_sticker_fully_replaces_face_box_including_corners` và `test_sticker_covers_edge_and_odd_shaped_boxes` kiểm tra không còn điểm ảnh gốc trong hộp (ảnh nền xám thuần, so sánh < 1% điểm giữ nguyên) cho mặt ở góc ảnh, hộp dẹt, hộp cao.
- Là phương án dự phòng **và** chế độ dev không GPU. Che kín nên không lộ danh tính, nhưng nhìn "hoạt hình".

### 4b. AI inpainting (`DiffusersInpainter`) — chỉ khi `AI_ENABLED=true` và có GPU

Cho từng mặt:
1. Lấy khung vuông rộng ≈ 1.6× hộp nới (thêm ngữ cảnh để giữ tư thế/ánh sáng).
2. Mặt nạ elip trên hộp nới, làm mờ biên (Gaussian) để hoà vào ảnh.
3. Thu về 512×512, chạy `StableDiffusionInpaintPipeline` (`AI_MODEL`, mặc định `runwayml/stable-diffusion-inpainting`, `AI_STEPS=25`) với prompt "close-up photo of a {animal} face replacing a human face…" và negative prompt chống mặt người.
4. Ghép lại theo mặt nạ mờ.

`FaceReplacer` quản lý dự phòng **theo từng mặt**:
- Quá `AI_TIMEOUT_S` (45 giây, kiểm tra **trước mỗi mặt**) → sticker cho các mặt còn lại.
- Ngoại lệ (hết VRAM, lỗi mô hình) → sticker cho mặt đó.
- **Kiểm tra sau khi sinh**: `mean_abs_change(ảnh gốc, ứng viên, hộp mặt) < AI_MIN_CHANGE` (18/255) nghĩa là vùng mặt gần như không đổi → bỏ kết quả AI, dùng sticker.
- Kết quả `method="AI"` chỉ khi **mọi** mặt đều qua AI; có bất kỳ mặt nào dùng sticker thì `method="STICKER"`.

Mô hình không bao giờ gọi ra dịch vụ ngoài; ảnh gốc không rời máy chủ của hệ thống.

### 5. Mã hoá

`encode_jpeg(quality=JPEG_QUALITY=88, optimize=True)`. Không có mặt: vẫn đăng (`method=NONE`, `faces=0`) sau khi xoá EXIF.

## 8.3 Retry, DLQ và giao lại (`facework/worker.py`)

| Tình huống | Hành vi | Kết quả phát ra |
|---|---|---|
| Thành công | put public (metadata `method`, `faces`) → xoá raw → metric | `FACE_PROCESSED` |
| Đã có `pub/{id}.jpg` (giao lại sau khi worker chết) | Không xử lý lại, chỉ xoá raw (nếu còn) | `FACE_PROCESSED` (method/faces lấy từ metadata) |
| `ImageRejected` hoặc raw không còn | Xoá raw, **không retry** | `FACE_FAILED(UNREADABLE_IMAGE\|IMAGE_TOO_LARGE\|RAW_MISSING)` |
| Lỗi tạm thời (MinIO, bộ nhớ…) | Retry tối đa `MAX_ATTEMPTS=3`, ngủ `RETRY_BACKOFF_S × lần` (1.5s, 3s) | — |
| Hết lượt retry | Gửi message gốc vào `media.events.dlq`, xoá raw | `FACE_FAILED(PROCESSING_FAILED)` |
| Message không phải JSON | DLQ ngay | — |
| Event khác `PHOTO_UPLOADED` | Bỏ qua | — |
| Xoá raw lỗi | Chỉ cảnh báo (`MediaJanitor` sẽ xoá sau ≤ 1 giờ) | không ảnh hưởng kết quả |

Offset Kafka chỉ commit **sau khi** `handle()` trả về (đã phát kết quả). Ngoại lệ hạ tầng không bị bắt (ví dụ Kafka producer hỏng) → không commit, Kafka giao lại.

## 8.4 Metric (Prometheus, cổng `HTTP_PORT=8110`)

| Metric | Nhãn | Ý nghĩa |
|---|---|---|
| `facework_processed_total` | `method` (`AI`/`STICKER`/`NONE`) | Ảnh xử lý thành công |
| `facework_failed_total` | `reason` | Ảnh thất bại |
| `facework_faces_total` | — | Số mặt đã che |
| `facework_duration_seconds` | histogram (0.1…64 s) | Thời gian xử lý mỗi ảnh |
| `facework_retries_total` | — | Số lần retry |

Mọi đường dẫn của cổng 8110 đều trả `200` (dùng cho healthcheck).

## 8.5 Cấu hình (biến môi trường, `facework/config.py`)

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `KAFKA_BOOTSTRAP`, `KAFKA_GROUP` | `localhost:9092`, `face-worker` | |
| `TOPIC_IN`, `TOPIC_OUT`, `TOPIC_DLQ` | `media.events`, `media.results`, `media.events.dlq` | |
| `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MINIO_SECURE` | `localhost:9000`, `minioadmin`… | Endpoint **nội bộ** (không qua Traefik) |
| `RAW_BUCKET`, `PUBLIC_BUCKET` | `raw`, `public` | |
| `MAX_ATTEMPTS`, `RETRY_BACKOFF_S` | 3, 1.5 | |
| `MAX_SIDE_PX`, `MAX_PIXELS`, `JPEG_QUALITY` | 2048, 40 000 000, 88 | |
| `DETECTORS`, `YUNET_MODEL`, `YUNET_SCORE` | `haar,yunet`, `/models/face_detection_yunet_2023mar.onnx`, 0.3 | |
| `AI_ENABLED`, `AI_MODEL`, `AI_STEPS`, `AI_MIN_CHANGE`, `AI_TIMEOUT_S` | false, SD inpainting, 25, 18, 45 | |
| `OTHER_FACES` | `same` | `same` \| `random` |
| `HTTP_PORT` | 8110 | |

## 8.6 Chạy và kiểm thử

```bash
cd face-worker
python -m venv .venv
.venv/Scripts/pip install -r requirements-dev.txt      # Windows; Linux/macOS: .venv/bin/pip
.venv/Scripts/python -m pytest -q                       # 32 test, không cần Kafka/MinIO/GPU
python -m facework.main                                 # cần Kafka + MinIO đang chạy
```

- Bản GPU: cài `requirements-ai.txt`, đặt `AI_ENABLED=true` (xem `Dockerfile` với `--build-arg BASE=nvidia/cuda:… --build-arg REQS=requirements-ai.txt`).
- `import confluent_kafka` làm trễ (trong `main()`), nên test và `tools/evaluate.py` chạy được không cần librdkafka.

## 8.7 Đo chất lượng (bước "spike", `tools/evaluate.py`)

Mục tiêu của kế hoạch: **tỉ lệ bỏ sót mặt < 1%**, **ảnh còn EXIF = 0**, đo thời gian và chi phí GPU mỗi ảnh.

```bash
python -m tools.evaluate <thư_mục_ảnh> <labels.json> [--animal fox]
```

`labels.json` — toạ độ trên **ảnh gốc** (sau khi xoay theo EXIF), gồm cả ảnh không có mặt:

```json
{ "anh1.jpg": [[120, 80, 90, 110], [400, 95, 70, 85]],
  "anh2.jpg": [] }
```

Cách tính: với mỗi mặt nhãn, lấy tỉ lệ điểm ảnh trong hộp nhãn **đã bị thay đổi** (chênh lệch tổng kênh > 12). Dưới **0.90** coi là **bỏ sót**. In ra `miss_rate`, số ảnh theo phương pháp, ảnh không mặt bị che nhầm, thời gian p50/p95/max, số ảnh còn EXIF. Mã thoát 0 chỉ khi `miss_rate < 1%` **và** `EXIF = 0`.

### Bộ ảnh test cần chuẩn bị (tự gán nhãn)

Tối thiểu 300 ảnh (≥ 600 mặt), nên có đủ các nhóm sau — tỉ lệ bỏ sót phải được báo **theo nhóm**, không chỉ trung bình:

| Nhóm | Ví dụ |
|---|---|
| Mặt chính diện, rõ | selfie, ảnh chân dung |
| Mặt nhỏ trong ảnh nhóm | ≥ 5 người, mặt < 5% chiều cao ảnh |
| Mặt nghiêng/ngửa/cúi | profile, 3/4 |
| Bị che một phần | khẩu trang, kính râm, mũ, tay che |
| Điều kiện sáng khó | ngược sáng, tối, nhoè chuyển động |
| Mặt bị cắt ở mép ảnh | |
| Màu da/độ tuổi đa dạng | trẻ em, người lớn tuổi, nhiều sắc tộc (kiểm tra thiên lệch detector) |
| Không có mặt | phong cảnh, đồ vật, tranh vẽ/ảnh có mặt trên poster (xem false positive) |
| Ảnh iPhone (HEIC), ảnh xoay EXIF, ảnh lớn 12MP | kiểm tra pipeline đầu cuối |

Chỉ dùng ảnh có quyền sử dụng; **không** dùng dữ liệu người dùng thật nếu chưa có sự đồng ý rõ ràng.

### Công thức chi phí GPU

```
chi_phí_GPU_mỗi_ảnh = giá_thuê_GPU_mỗi_giờ / (số_ảnh_xử_lý_mỗi_giờ_ở_hiệu_suất_thực)
số_ảnh_mỗi_giờ      = 3600 / thời_gian_trung_bình_mỗi_ảnh_(giây) × số_worker_song_song × hệ_số_sử_dụng (0.6–0.8)
```

Lấy `thời_gian_trung_bình` từ `facework_duration_seconds` (mean) trên bộ ảnh test; nhân với số mặt trung bình mỗi ảnh vì AI chạy **tuần tự từng mặt**. Dữ liệu này đưa vào mô hình ở [02-business-monetization.md](02-business-monetization.md).

## 8.8 Giới hạn và rủi ro đã biết

| # | Vấn đề | Mức | Hướng xử lý |
|---|---|---|---|
| 1 | **Chưa đăng ký `pillow_heif`**: `requirements.txt` có `pillow-heif` nhưng code không gọi `register_heif_opener()`, nên ảnh HEIC (iPhone) hiện bị `UNREADABLE_IMAGE` dù media-service cho phép `image/heic` | Cao | Thêm `import pillow_heif; pillow_heif.register_heif_opener()` trong `decode_clean`/khởi tạo, kèm test HEIC. Tạm thời client nên chuyển HEIC → JPEG trước khi upload |
| 2 | Recall của Haar trung bình (mặt nhỏ/nghiêng/che) | Cao | Bắt buộc dùng YuNet (hoặc detector mạnh hơn, ví dụ RetinaFace/SCRFD) ở production; đo bằng 8.7 trước khi ra mắt |
| 3 | Đường AI **chưa được chạy thật** (không có GPU/mô hình khi phát triển); chỉ có test với AI giả | Cao | Chạy spike trên máy GPU: đo thời gian, tỉ lệ mặt không đổi, chất lượng thị giác |
| 4 | Không có lượt phát hiện lại trên ảnh đầu ra để bắt mặt sót | Trung bình | Thêm bước kiểm tra "còn mặt thật?" sau khi thay (chỉ cần chạy detector lần nữa) |
| 5 | Một lần gọi AI không thể bị ngắt giữa chừng; timeout chỉ kiểm tra giữa các mặt | Trung bình | Chạy AI trong tiến trình con có timeout cứng, hoặc dùng số bước thấp |
| 6 | Mặt sinh bởi AI có thể vẫn trông giống người (mô hình bỏ qua prompt) → kiểm tra chỉ đo "có thay đổi" chứ không đo "đã là con vật" | Trung bình | Dùng bộ phân loại/CLIP để xác nhận, hoặc buộc dùng sticker cho nhóm miễn phí |
| 7 | Ảnh có mặt trong ảnh/poster/màn hình cũng bị che (false positive) | Thấp | Chấp nhận (ưu tiên an toàn) |
| 8 | Không có kiểm duyệt nội dung nhạy cảm (NSFW/bạo lực) | Cao (sản phẩm) | Thêm bước phân loại trước khi publish — chưa có |
| 9 | Ảnh động chỉ lấy khung đầu; video không hỗ trợ | Thấp | Ghi rõ trong sản phẩm |
| 10 | Nếu job đã bị `REJECTED` do timeout rồi worker mới xử lý xong, ảnh trong `public/` thành **mồ côi** (không ai tham chiếu) | Thấp | Job dọn định kỳ đối chiếu `pub/*` với `media_jobs` |
| 11 | Ảnh >2048 px được thu nhỏ; `evaluate.py` đã phóng lại về kích thước gốc để so khớp nhãn | Thấp | — |
