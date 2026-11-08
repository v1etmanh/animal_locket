# 2. Tạo Droplet và SSH key

## Tạo SSH key trên Windows

Nếu chưa có key dành cho deployment:

```powershell
ssh-keygen -t ed25519 -a 64 -f "$env:USERPROFILE\.ssh\animal_locket_do"
Get-Content "$env:USERPROFILE\.ssh\animal_locket_do.pub"
```

Thêm nội dung `.pub` vào DigitalOcean. Không tải hoặc gửi private key cho DigitalOcean, Git hay chat.

## Tạo Droplet

1. Mở DigitalOcean → **Create → Droplets**.
2. Chọn Singapore `SGP1`.
3. Chọn Ubuntu 24.04 LTS.
4. Chọn Basic/Regular, 4 vCPU, 8 GB RAM, khoảng 160 GB SSD.
5. Authentication: chọn SSH key vừa thêm.
6. Không bật backup trả phí, volume, database hoặc load balancer.
7. Monitoring miễn phí có thể bật.
8. Tạo Droplet và ghi lại public IPv4.

## Kết nối

```powershell
ssh -i "<SSH_PRIVATE_KEY>" -o IdentitiesOnly=yes root@<DROPLET_IP>
```

Lần đầu SSH hỏi fingerprint, đối chiếu thông tin Droplet rồi nhập `yes`.

## Public domain

Đổi dấu chấm trong IPv4 thành dấu gạch ngang rồi thêm `.nip.io`.

```text
134.209.96.89 → 134-209-96-89.nip.io
```

Không tái sử dụng hostname cũ nếu Droplet mới có IP khác.
