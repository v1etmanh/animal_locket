# 13. Hướng dẫn phát triển

## 13.1 Yêu cầu

| Công cụ | Phiên bản | Ghi chú |
|---|---|---|
| JDK | 17 | Spring Boot 3.3.5 |
| Maven | 3.9.x | Không có wrapper; dùng `mvn` cài sẵn |
| Python | 3.12 | Cho `face-worker` |
| Docker Desktop | 4.x+ | Chỉ cần khi chạy cả hệ thống / Testcontainers; **không bắt buộc** để build và chạy test |
| GPU NVIDIA 8–12 GB VRAM | tuỳ chọn | Chỉ cho AI inpainting |

## 13.2 Cấu trúc repo

```
animal-locket/
├─ pom.xml                       parent + danh sách module
├─ libs/common                   dùng chung (xem 3.9)
├─ libs/outbox-jpa               Outbox + idempotency
├─ infra/config-server | eureka-server | api-gateway | config-repo
├─ services/user | media | post | notification | discovery | chat | billing -service
├─ face-worker/                  Python (facework/, tests/, tools/evaluate.py, Dockerfile)
├─ deploy/                       Traefik, Keycloak realm, MinIO policy, observability, init SQL, Dockerfile.java
├─ docs/                         tài liệu (file này nằm ở đây)
└─ docker-compose.yml            (do nhánh hạ tầng cung cấp)
```

Mỗi service Java: `config/`, `domain/` (entity), `repo/`, `service/`, `web/` (controller), `dto/`, `messaging/` (Kafka listener), `client/` (gọi service khác), `src/main/resources/{application.yml, db/migration/V*.sql}`, `src/test/{java, resources/application.yml}`.

## 13.3 Build và chạy

```bash
mvn -B install                         # build + test toàn bộ
mvn -B -DskipTests install             # chỉ build
mvn -B -pl services/user-service -am install
```

**Chạy một service cục bộ không cần Docker** (ví dụ khi phát triển): mỗi service có giá trị mặc định cho `localhost`. Cần các thành phần tương ứng đang chạy:

| Service | Cần chạy kèm |
|---|---|
| user | MySQL (`user_db`), Kafka (tuỳ chọn: không có thì outbox chỉ tích luỹ), Keycloak (xác thực JWT) |
| media | MySQL (`media_db`), Kafka, MinIO, user-service |
| post | MySQL (`post_db`), Redis, Kafka, user-service |
| discovery | Redis, user-service (+ billing cho Boost) |
| chat | MongoDB, Redis, user-service, media-service |
| billing | PostgreSQL (`billing_db`), Kafka (`BILLING_DEV_STORE=true` để thử mua hàng giả lập) |
| notification | Kafka, user-service |
| gateway | Redis, Keycloak, Eureka, các service đích |

```bash
mvn -pl services/user-service spring-boot:run
# tắt kiểm tra JWT khi thử nhanh bằng curl (KHÔNG dùng ngoài máy dev):
mvn -pl services/user-service spring-boot:run -Dspring-boot.run.arguments=--animal.security.enabled=false
```

Chạy cả hệ thống bằng Docker: xem [10-deployment-infrastructure.md](10-deployment-infrastructure.md).

## 13.4 Quy ước code

**Gói và đặt tên**: `com.animallocket.<service>.{domain,repo,service,web,dto,messaging,client,config}`. Thư viện: `com.animallocket.common`, `com.animallocket.outbox`.

**Quy tắc bắt buộc (review sẽ chặn nếu vi phạm)**

1. **DTO riêng tư**: DTO trả cho người khác chỉ chứa `publicId`, alias, con vật. **Không bao giờ** `sub`, email, SĐT, `birthDate`, toạ độ, đường dẫn kho ảnh, `reports`. Thêm test âm khi tạo DTO mới.
2. **Danh tính**: controller lấy người gọi bằng `@RequestHeader(Headers.PUBLIC_ID) String me`. Không nhận `publicId` của người gọi từ body/query. Ngoại lệ duy nhất: `register` dùng `@AuthenticationPrincipal Jwt`.
3. **Lỗi**: ném `ApiException` (có sẵn `notFound`, `forbidden`, `conflict`, `badRequest`, `tooMany`) với `code` ổn định dạng `UPPER_SNAKE`; không ném `RuntimeException` trần cho lỗi nghiệp vụ. Thông báo `detail` viết cho người dùng cuối (tiếng Việt), không lộ chi tiết nội bộ. Không tiết lộ sự tồn tại: không có quyền xem → `notFound`.
4. **Endpoint nội bộ** đặt dưới `/internal/**` (đã được `InternalTokenFilter` bảo vệ) và **không** thêm route cho chúng ở gateway.
5. **Event**: phát qua `OutboxService.publish` **trong transaction nghiệp vụ**; payload chỉ `publicId`/mã; consumer có DB phải gọi `IdempotencyService.firstTime(eventId)` trong cùng transaction. Không gọi Kafka trực tiếp từ nghiệp vụ có DB.
6. **Gọi service khác**: qua `RestClient` `@LoadBalanced` + `CircuitBreakerFactory`, **có chính sách rõ** (fail closed hay fail soft — chọn và ghi chú) và timeout.
7. **Hạn mức/cache**: dùng `KeyValueStore`; đặt TTL; dùng giờ Việt Nam cho ngày; hoàn lượt khi thao tác thất bại.
8. **Giờ**: lưu `Instant` UTC; không tin giờ client.
9. **Không log** token, thân request, nội dung tin nhắn, toạ độ.
10. **Cấu hình**: giá trị theo môi trường qua biến môi trường (`${VAR:mặc_định_dev}`); mặc định chỉ an toàn cho dev. Bí mật không đặt trong repo.

**Style**: Lombok cho entity (`@Getter/@Setter/@NoArgsConstructor`), `record` cho DTO/payload, không dùng `@Data` cho entity JPA.

## 13.5 Quy trình thêm thành phần

### Thêm endpoint
1. DTO (`record` + validation), service method (đặt `@Transactional` đúng chỗ), controller.
2. Nếu qua gateway: kiểm tra đường dẫn đã khớp một route trong `infra/api-gateway/.../application.yml`.
3. Test tích hợp (MockMvc + `jwt()` + header `X-Public-Id`) gồm trường hợp thành công, sai quyền (`404`), vượt hạn mức.
4. Cập nhật [06-api-reference.md](06-api-reference.md).

### Thêm migration
1. Tạo `V<n+1>__mo_ta.sql` trong `src/main/resources/db/migration/` (không sửa file đã chạy).
2. Giữ SQL tương thích MySQL **và** cập nhật entity; kiểm tra bằng MySQL thật khi có Docker (`JPA_DDL_AUTO=validate`).
3. Với bảng lớn, dùng thay đổi tương thích ngược (thêm cột nullable → backfill → siết ràng buộc ở bản sau).

### Thêm event
Xem [07-event-catalog.md](07-event-catalog.md) mục 7.8.

### Thêm service mới
1. Tạo module trong `services/`, thêm vào `<modules>` của `pom.xml` gốc, copy `pom.xml` của một service tương tự (đã có `common`, `outbox-jpa`, Eureka, Config, Resilience4j).
2. `application.yml`: `spring.application.name`, cổng (8108+), `spring.config.import: optional:configserver:…`, `animal.security.enabled`, cấu hình Kafka/DB.
3. Thêm route vào gateway; thêm vào Compose, Prometheus (`deploy/observability/prometheus`), tài liệu 03/04.
4. Test: tạo `src/test/resources/application.yml` riêng (H2/in-memory, `animal.kv.type=memory`, `animal.outbox.relay.enabled=false`, `spring.kafka.listener.auto-startup=false`, `eureka.client.enabled=false`, `spring.cloud.config.enabled=false`) và `@MockBean JwtDecoder`.

### Thêm tính năng cho face-worker
Thêm module nhỏ trong `facework/`, nối vào `Pipeline`/`FaceReplacer`, viết test trong `tests/` dùng `FixedDetector`/`FakeStorage`/`FakePublisher` (`tests/helpers.py`). Mọi thay đổi định dạng event Python phải cập nhật `FaceWorkerContractTest`.

## 13.6 Git và commit

- Nhánh: `main` luôn xanh và triển khai được; làm việc trên `feat/<mô-tả>`, `fix/<mô-tả>`; PR nhỏ (một mối quan tâm).
- Commit theo Conventional Commits: `feat(user): thêm cooldown alias`, `fix(face-worker): đăng ký pillow-heif`, `docs: …`, `test: …`, `chore: …`. Tiêu đề ≤ 72 ký tự, thân giải thích **vì sao**.
- PR phải: build xanh, có test, không thêm bí mật, cập nhật tài liệu, đánh dấu rõ nếu thay đổi hợp đồng API/event.
- Bắt buộc review thêm người thứ hai với thay đổi chạm: DTO công khai, `LocationPrivacy`, `CommonAutoConfiguration`, `IdentityFilter`, billing, face-worker.

## 13.7 CI/CD (gợi ý)

```yaml
# .github/workflows/ci.yml
name: ci
on: { pull_request: {}, push: { branches: [main] } }
jobs:
  java:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: 17, cache: maven }
      - run: mvn -B install                       # Docker có sẵn → test Testcontainers (Mongo) cũng chạy
  python:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: face-worker } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: pip }
      - run: pip install -r requirements-dev.txt
      - run: pytest -q
  docker:
    needs: [java, python]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:                                      # build image từng service (deploy/docker/Dockerfile.java, MODULE_PATH=…)
      - uses: actions/checkout@v4
      - run: echo "build & push images; quét lỗ hổng (Trivy); smoke test bằng docker compose"
```

Thêm: quét phụ thuộc (Dependabot/OWASP), quét bí mật (gitleaks), job nightly chạy Compose smoke + k6 nhẹ.

## 13.8 Checklist onboarding

- [ ] Cài JDK 17, Maven, Python 3.12; chạy `mvn -B install` và `pytest` xanh.
- [ ] Đọc README → 01 → 03 → 09 (riêng tư) → tài liệu của khu vực bạn làm.
- [ ] Đọc `libs/common` (Headers, `ApiException`, `CommonAutoConfiguration`) và `libs/outbox-jpa`.
- [ ] Chạy một service cục bộ và gọi thử bằng `curl` với `animal.security.enabled=false` + header `X-Public-Id`.
- [ ] Chạy `docker compose` cục bộ (khi có) và đi hết kịch bản vàng ở [12-testing-strategy.md](12-testing-strategy.md).
- [ ] Hiểu chính sách fail closed/soft ([03-architecture.md](03-architecture.md) 3.8).

## 13.9 Bẫy đã gặp khi phát triển (đọc trước khi đổi code liên quan)

| # | Bẫy | Hệ quả/Cách tránh |
|---|---|---|
| 1 | **OpenCV 5.x đã bỏ Haar cascade** (`cv2.data.haarcascades` rỗng, không có `CascadeClassifier`) | Ghim `opencv-python-headless>=4.9,<5` (đã làm trong `requirements.txt`); không nâng lên 5 |
| 2 | **`pillow-heif` có trong `requirements` nhưng chưa được đăng ký** | HEIC bị `UNREADABLE_IMAGE`; cần `pillow_heif.register_heif_opener()` |
| 3 | **Hibernate 6.5 + MySQL + `ddl-auto: validate`** có thể báo sai kiểu cột enum | Mặc định `JPA_DDL_AUTO=none` cho MySQL; kiểm tra với MySQL thật rồi bật `validate` |
| 4 | **Bộ thẻ discovery = lân cận HOẶC đang online**; `updateLocation` cũng đánh dấu online | Người ở xa vẫn có thẻ (không có khoảng cách). Khi viết test, đặt "người ở xa không online" qua `store.putLocation` |
| 5 | **Dữ liệu test dùng chung** trong context Spring (H2/`InMemoryKeyValueStore`) | Dọn trong `@BeforeEach`; đặt hạn mức test đủ lớn hoặc kiểm hạn mức bằng unit test riêng |
| 6 | **Surefire bỏ qua lớp test lồng nhau** | Mỗi lớp test là một file cấp cao nhất |
| 7 | **MongoDB lưu thời gian ở mili-giây** | So sánh `>` nghiêm ngặt có thể rơi tin cùng mili-giây; dùng mốc từ dữ liệu thật |
| 8 | `OutboxService.publish` là `MANDATORY` | Gọi ngoài transaction sẽ ném lỗi — có chủ đích |
| 9 | `IdempotencyService.firstTime` cũng `MANDATORY`; listener phải `@Transactional` | Quên annotation → lỗi `IllegalTransactionStateException` |
| 10 | `spring-cloud-starter-config` bắt buộc cần `spring.config.import` | Đã dùng `optional:configserver:` nên chạy được khi không có Config Server |
| 11 | `common` đặt Redis là `optional` | Service cần Redis phải tự thêm `spring-boot-starter-data-redis` |
| 12 | Chữ ký presigned URL gắn với **host** | `minio.endpoint` (nội bộ) khác `minio.public-endpoint` (điện thoại truy cập) — đặt sai thì upload thất bại `SignatureDoesNotMatch` |
| 13 | Trong form POST S3, trường `file` **phải là trường cuối cùng** | Client đặt sai thứ tự sẽ bị MinIO từ chối |
| 14 | Spring không có `HttpClientErrorException.PaymentRequired` | So sánh `getStatusCode().value()` cho 402 |
| 15 | `ApiExceptionHandler` có handler `Exception` chung | Đừng bắt `Exception` rộng ở nơi khác làm mất mã lỗi chuẩn; handler đã ném lại lỗi bảo mật/404/405 |
| 16 | Mặc định `dev-internal-token`, `config-dev-password`, `minioadmin`, `DISCOVERY_SECRET` dev | Chỉ cho dev; **đổi ở mọi môi trường thật** |
