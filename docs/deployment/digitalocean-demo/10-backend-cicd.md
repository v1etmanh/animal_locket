# 10. CI/CD backend trên server demo

Workflow: [backend-demo.yml](../../../.github/workflows/backend-demo.yml). Pipeline dùng server đã bootstrap theo bước 2–6; không tạo Droplet, không tự sinh lại `.env`, không mua thêm dịch vụ cloud.

## Luồng hoạt động

1. PR vào `master`: kiểm tra Bash bằng ShellCheck, kiểm tra Compose, kiểm tra dependency mới có lỗ hổng mức high trở lên, chạy `mvn verify` toàn bộ backend, xác nhận thư viện avatar nằm trong JAR và build thử các image runtime.
2. Push/merge vào `master`: chạy lại kiểm tra và build. Khi bật CD, đóng gói source deployment cùng đúng JAR vừa kiểm tra thành artifact giữ tối đa 1 ngày, xoá sau khi job deploy thành công để giảm storage. Khi tắt CD không upload JAR artifact. Test Redis chạy với Redis thật; MongoDB dùng Testcontainers trên GitHub runner. Test R2 live vẫn có điều kiện riêng, không dùng khoá cloud trong CI.
3. Khi repository variable `DEMO_DEPLOY_ENABLED=true`: tải artifact, xác minh SHA-256, truyền qua SSH và triển khai vào `/opt/animal-locket/releases/<commit>-<run>-<attempt>`.
4. Server tạo image từ JAR tuần tự, không chạy Maven; giữ database/volume, `.env`, file khoá và cấu hình email TLS dùng chung. Compose đợi các container healthy, sau đó kiểm tra HTTPS/OIDC/MinIO/API 401. Chỉ khi thành công mới cập nhật symlink `current-release`; lần thành công kế tiếp lưu `previous-release`.

CI kiểm tra cả report JUnit để bảo đảm Mongo/Redis integration test thực sự chạy, không bị đánh dấu skip vì thiếu Docker/Redis. Testcontainers được giữ ở dòng 1.x tương thích API hiện tại và đã nâng lên `1.21.4` để hỗ trợ Docker Engine mới.

PR chỉ sửa mobile/docs chạy job nhận diện thay đổi rồi bỏ qua test/build backend để tiết kiệm runner. Push vào `master` chỉ kích hoạt workflow khi file backend, `libs/`, `infra/`, `deploy/`, `.gitattributes` hoặc workflow thay đổi. Có thể chạy thủ công bằng **Actions → Backend CI and demo deploy → Run workflow → master**. CD chỉ chấp nhận ref `master`, không chạy từ PR hoặc branch khác. CI thất bại thì job deploy không chạy. Các lần deploy được xếp hàng, không huỷ deployment đang chạy.

Trước khi kết nối SSH, job đối chiếu commit với HEAD của `master`; nếu đã có commit mới hơn thì bỏ qua bản cũ để tránh deploy ngược thứ tự khi các lượt CI hoàn thành khác nhau. Khi push chỉ mobile/docs và muốn deploy lại master mới nhất, dùng Run workflow thủ công.

## Thiết lập một lần

### 1. Chuẩn bị server

Hoàn thành runbook bootstrap/deploy/HTTPS trước. Server phải có Docker Compose hỗ trợ `up --wait --wait-timeout`, Bash, curl, tar, sha256sum và flock (Ubuntu 24.04 có util-linux). SSH mặc định cổng 22. User SSH phải ghi được `/opt/animal-locket` và gọi Docker không cần hỏi mật khẩu; tài khoản `root` của demo hiện tại đáp ứng điều này.

Giữ các file dùng chung:

```text
/opt/animal-locket/.env
/opt/animal-locket/deploy/secrets/
/opt/animal-locket/deploy/demo/traefik.demo.yml
```

Kiểm tra `.env` có `COMPOSE_PROJECT_NAME=animal-locket`, `COMPOSE_PROFILES=core,app`, domain server hiện tại và thông tin kết nối đúng. CI/CD cố định project name `animal-locket` để dùng lại các named volume hiện hữu. Không dùng quy trình này cho stack khác có cùng project name/mạng `animal-net` trên cùng máy.

### 2. SSH key cho GitHub Actions

Nên tạo SSH key riêng cho pipeline, thêm public key vào `~/.ssh/authorized_keys` trên server. Private key không có passphrase vì job chạy không tương tác. Việc thêm key trên DigitalOcean chỉ áp dụng lúc tạo Droplet; với server đang có phải thêm vào `authorized_keys`.

Lấy public host key trực tiếp qua console DigitalOcean hoặc một phiên SSH đã xác thực:

```bash
cat /etc/ssh/ssh_host_ed25519_key.pub
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Secret known_hosts phải có dạng `<DROPLET_IP> ssh-ed25519 AAAA...` với key ở trên. Xác minh fingerprint qua kênh đã tin cậy. Pipeline bật `StrictHostKeyChecking=yes`, không tự tin một key thu được bằng `ssh-keyscan` chưa đối chiếu.

### 3. Cấu hình GitHub

Trong repository **Settings → Environments**, tạo environment `demo`, giới hạn deployment branch là `master`. Trong environment `demo`, thêm:

| Secret | Giá trị |
|---|---|
| `DEMO_SSH_HOST` | IP/hostname server, không kèm `https://` |
| `DEMO_SSH_USER` | User SSH, ví dụ `root` |
| `DEMO_SSH_PRIVATE_KEY` | Toàn bộ private key dành cho CI/CD |
| `DEMO_SSH_KNOWN_HOSTS` | Dòng known_hosts đã xác minh cho đúng IP |

Không đưa `.env`, mật khẩu database hoặc token người dùng lên artifact. Các secret ứng dụng chỉ nằm trên server. Job CI không có secret deploy; chỉ job CD tham chiếu environment `demo`.

Trong **Settings → Secrets and variables → Actions → Variables → Repository variables**, tạo `DEMO_DEPLOY_ENABLED=true` khi muốn tự deploy. Để trống hoặc `false` sẽ chạy CI/build mà bỏ qua CD. Khi destroy server, đặt `false`; khi tạo lại phải cập nhật IP, host key, authorized_keys và bootstrap server mới trước khi bật lại.

Trong **Settings → Rules → Rulesets** (hoặc Branch protection), yêu cầu PR vào `master` và status checks `changes`, `verify`, `dependency-review` trước merge. Job backend được skip trên PR mobile/docs vẫn hoàn thành hợp lệ; workflow PR không dùng path filter ở cấp workflow để tránh required check bị treo pending. Các quy tắc này phải được bật trên GitHub; thêm file workflow không tự bật branch protection.

## Kiểm tra kết quả và vận hành

GitHub Actions hiển thị job `verify` và `deploy`; lỗi test có artifact XML riêng. Server:

```bash
readlink -f /opt/animal-locket/current-release
cd /opt/animal-locket/current-release
export DEPLOY_TAG="$(basename "$(pwd -P)")"
export COMPOSE_PROFILES=core,app
docker compose --project-name animal-locket --env-file /opt/animal-locket/.env \
  -f docker-compose.yml -f deploy/demo/docker-compose.demo.yml \
  -f deploy/demo/docker-compose.ci.yml ps -a
bash deploy/demo/smoke-check.sh /opt/animal-locket/.env
```

Sau khi chuyển sang CI/CD, dùng cả **ba** Compose file khi restart/up/logs; lệnh build theo source ở bước 4 chỉ dành cho cài đặt ban đầu. Không dùng lại checkout gốc để `up` vì sẽ chuyển stack về image `:dev`.

Smoke tự động kiểm tra public boundary và container health, chưa thay thế luồng nghiệp vụ có đăng nhập. Chạy thêm [Postman](../../../postman/README.md) để xác nhận upload ảnh → complete → bài READY/feed, avatar, discovery, chat và billing. PayPal/payOS chỉ hoạt động khi thêm đúng credentials; payOS không có sandbox.

## Rollback và lỗi deploy

Nếu build lỗi, container đang chạy vẫn giữ nguyên. Nếu `up` hoặc smoke lỗi, job thất bại và symlink chưa đổi, nhưng một số container hoặc migration **có thể đã cập nhật**; symlink không phải bằng chứng toàn bộ stack đang chạy bản cũ. Kiểm tra `docker ps` và logs từ thư mục release vừa thất bại.

Để quay về release thành công trước đó, khi schema còn tương thích:

```bash
previous=$(readlink -f /opt/animal-locket/previous-release)
test -n "$previous" && test -d "$previous"
bash "$previous/deploy/demo/deploy-release.sh" "$previous" --rollback
```

Rollback dùng lại image đã có, không build lại. Nếu lần deploy đầu tiên chưa có `previous-release`, dùng runbook cài đặt gốc hoặc triển khai commit đã biết tốt. Không tự rollback database: backup trước migration và chỉ rollback app khi schema tương thích. Không chạy hai stack cùng lúc trên Droplet 8 GB; sẽ có gián đoạn ngắn khi recreate container. Không cam kết zero downtime.

Image/JAR của các release chiếm thêm disk. Giữ ít nhất hai bản tốt, theo dõi `df -h` và `docker system df`; sau khi xác minh bản mới có thể xoá thủ công đúng release/image cũ không còn dùng. Pipeline không tự prune Docker/volume hay xoá backup.

## Chi phí và trạng thái kích hoạt

Không cần registry, Load Balancer, Kubernetes hay Droplet bổ sung. GitHub runner thực hiện test/build JAR; artifact release chỉ tạo khi bật CD và xoá sau job deploy thành công (nếu lỗi thì tự hết hạn sau 1 ngày). Mức phí Actions/storage phụ thuộc loại repository, runner, quota và gói tài khoản; kiểm tra billing của GitHub trước khi đổi sang repo private/runner trả phí. Server vẫn được tính phí theo tài nguyên DigitalOcean đang tồn tại.

Tại thời điểm bổ sung workflow, repository chưa có Actions secret/variable deploy. Chỉ thêm code không thể xác thực server mới; cần cấu hình các giá trị ở trên rồi push/merge workflow vào `master` và chạy một lượt để xác nhận end-to-end.

Tài liệu chính thức: [GitHub environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments), [Compose up và health wait](https://docs.docker.com/reference/cli/docker/compose/up/).
