# 9. Prompt copy-paste để tạo lại server từ source local

Prompt này dùng khi nhánh `demo_Deploy` chỉ tồn tại trên máy local và chưa được push lên GitHub. Agent phải lấy source từ `D:\ky 8\animal_locket`, không được clone nhánh `demo_Deploy` từ remote.

## Thông tin cần điền

Trước khi gửi prompt, thay:

```text
<DROPLET_IP> = public IPv4 của Droplet mới
```

Các giá trị còn lại đã khớp máy hiện tại:

```text
LOCAL_REPOSITORY=D:\ky 8\animal_locket
LOCAL_BRANCH=demo_Deploy
LOCAL_COMMIT=10e37dc
SSH_PRIVATE_KEY=C:\Users\tanvi\.ssh\animal_locket_do_v2
LETSENCRYPT_EMAIL=tanvinhza2@gmail.com
```

Nếu nhánh local có commit mới hơn `10e37dc`, Agent phải dùng HEAD mới nhất của `demo_Deploy` sau khi xác nhận các file runbook vẫn tồn tại.

## Prompt để copy

```text
Bạn hãy triển khai lại toàn bộ Animal Locket demo lên Droplet DigitalOcean mới.

Thông tin đầu vào:
- DROPLET_IP: <DROPLET_IP>
- SSH_PRIVATE_KEY: C:\Users\tanvi\.ssh\animal_locket_do_v2
- LOCAL_REPOSITORY: D:\ky 8\animal_locket
- LOCAL_BRANCH: demo_Deploy
- EXPECTED_COMMIT: 10e37dc hoặc HEAD mới hơn của demo_Deploy
- LETSENCRYPT_EMAIL: tanvinhza2@gmail.com

Quan trọng:
1. Nhánh demo_Deploy hiện chỉ có trên máy local, chưa push GitHub.
2. Không clone nhánh demo_Deploy từ origin và không yêu cầu GitHub remote.
3. Đọc đầy đủ các file sau trước khi hành động:
   - AGENTS.md
   - docs/deployment/digitalocean-demo/README.md
   - docs/deployment/digitalocean-demo/03-bootstrap-server.md
   - docs/deployment/digitalocean-demo/04-deploy-stack.md
   - docs/deployment/digitalocean-demo/05-https-and-keycloak.md
   - docs/deployment/digitalocean-demo/06-smoke-check-and-flutter.md

Hãy thực hiện trọn quy trình sau:

A. Kiểm tra local
- Xác nhận repository D:\ky 8\animal_locket tồn tại.
- Xác nhận branch hiện tại hoặc branch có sẵn là demo_Deploy.
- Xác nhận commit 10e37dc tồn tại; nếu demo_Deploy có commit mới hơn thì dùng HEAD mới nhất.
- Xác nhận có deploy/demo/, docs/deployment/digitalocean-demo/ và postman/.
- Không đưa .env, access token, private SSH key hoặc dữ liệu bí mật vào gói source.

B. Chuyển source local sang server
- Tạo Git bundle tạm thời chỉ từ branch demo_Deploy, ví dụ animal-locket-demo.bundle.
- Dùng SCP với private key đã cung cấp để tải bundle lên /root/ trên Droplet.
- SSH vào root@<DROPLET_IP>.
- Clone bundle thành /opt/animal-locket và checkout demo_Deploy.
- Xác nhận commit server khớp commit local đã chọn.
- Xóa bundle tạm trên server và máy local sau khi clone thành công.
- Không phụ thuộc vào quyền push hoặc quyền đọc branch demo_Deploy trên GitHub.

C. Bootstrap server
- Cài Docker Engine, Docker Compose, Git, rsync, UFW và OpenSSL.
- Enable Docker.
- Tạo swap 4 GB và thêm vào /etc/fstab.
- UFW chỉ cho phép OpenSSH, 80/tcp và 443/tcp.
- Không mở public MySQL, PostgreSQL, MongoDB, Redis, Kafka, Eureka, Config Server hoặc Docker dashboard.

D. Sinh cấu hình
- Tạo PUBLIC_DOMAIN bằng cách đổi dấu chấm của DROPLET_IP thành dấu gạch ngang rồi thêm .nip.io.
- Chạy deploy/demo/generate-env.sh để sinh /opt/animal-locket/.env.
- Đặt permission .env là 600.
- Thay email ACME trong deploy/demo/traefik.demo.yml bằng tanvinhza2@gmail.com.
- Không in nội dung .env hoặc secret ra output.

E. Deploy tiết kiệm chi phí
- Chỉ dùng một Droplet hiện có.
- Không tạo Managed Database, Load Balancer, Volume, Kubernetes, Spaces hoặc paid backup.
- Chỉ chạy COMPOSE_PROFILES=core,app; không bật profile obs.
- Dùng docker-compose.yml kết hợp deploy/demo/docker-compose.demo.yml.
- Chạy docker compose config --quiet trước khi start.
- Khởi động core trước.
- Build lần lượt theo đúng thứ tự để tránh hết RAM:
  eureka-server, config-server, api-gateway, user-service, media-service,
  post-service, notification-service, discovery-service, chat-service, billing-service.
- Sau khi build, start app bằng --no-build.
- Cài client Postman bằng deploy/demo/install-postman-client.sh.

F. HTTPS và bảo mật
- Dùng Let's Encrypt HTTP-01 cho api, auth và files.<PUBLIC_DOMAIN>.
- Redirect HTTP sang HTTPS.
- Giữ Keycloak sslRequired=external; tuyệt đối không đổi thành none.
- Không public Keycloak Admin, actuator, database hoặc service nội bộ.
- Chứng chỉ phải được lưu trong letsencrypt-data volume để tự gia hạn.

G. Kiểm tra tối thiểu
- Chờ container dài hạn healthy; kafka-init và minio-init được phép Exited (0).
- Kiểm tra OIDC discovery HTTPS trả 200.
- Kiểm tra MinIO /minio/health/live trả 200.
- Kiểm tra /api/v1/users/me không JWT trả 401.
- Kiểm tra HTTP chuyển sang HTTPS.
- Không lặp lại các bài test thủ công chi tiết nếu các kiểm tra trên đạt.

H. Báo cáo cuối
- Public domain.
- API URL, Keycloak issuer, Files URL và WebSocket URL.
- Commit đã deploy.
- Trạng thái toàn bộ container.
- Kết quả bốn smoke checks.
- RAM, swap và dung lượng đĩa còn lại.
- Chi phí Droplet theo giờ và mức tối đa tháng; xác nhận không tạo dịch vụ trả phí khác.
- Lệnh flutter run đầy đủ với API_BASE_URL, WS_URL, KEYCLOAK_ISSUER,
  KEYCLOAK_CLIENT_ID=mobile và OAUTH_REDIRECT_URL.

Hãy tự tiếp tục qua các bước bình thường trong phạm vi trên. Chỉ dừng để hỏi tôi nếu:
- SSH không kết nối được;
- cần đăng nhập hoặc 2FA;
- thao tác có thể tạo thêm chi phí;
- cần xóa dữ liệu không được nêu trong prompt;
- hoặc kết quả triển khai sẽ khác đáng kể cấu hình đã mô tả.
```

## Sau khi Agent hoàn tất

1. Ghi lại `PUBLIC_DOMAIN` mới.
2. Sửa Postman environment theo `postman/docs/01-import-collection-and-environment.md`.
3. Lấy token mới theo `postman/docs/02-keycloak-oauth-pkce.md`.
4. Chạy collection theo `postman/docs/03-run-smoke-tests.md`.
5. Chạy Flutter bằng lệnh Agent báo cáo.

Token, tài khoản và dữ liệu của Droplet cũ không tồn tại trên server mới nếu không có backup.
