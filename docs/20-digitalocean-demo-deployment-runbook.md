# 20. Triển khai demo DigitalOcean

Tài liệu triển khai đã được tách theo từng giai đoạn để người vận hành hoặc Agent chỉ cần mở đúng phần đang thực hiện.

## Mục lục triển khai

1. [Tổng quan, kiến trúc và chi phí](deployment/digitalocean-demo/01-overview-and-cost.md)
2. [Tạo Droplet và SSH key](deployment/digitalocean-demo/02-create-droplet-and-ssh.md)
3. [Bootstrap Ubuntu, Docker, swap và firewall](deployment/digitalocean-demo/03-bootstrap-server.md)
4. [Clone source, sinh cấu hình và deploy stack](deployment/digitalocean-demo/04-deploy-stack.md)
5. [Cấu hình HTTPS, Keycloak và Postman client](deployment/digitalocean-demo/05-https-and-keycloak.md)
6. [Smoke check và kết nối Flutter local](deployment/digitalocean-demo/06-smoke-check-and-flutter.md)
7. [Vận hành, destroy và tạo lại](deployment/digitalocean-demo/07-operations-and-redeploy.md)
8. [Prompt giao việc cho Agent](deployment/digitalocean-demo/08-agent-handoff.md)

Trang bắt đầu: [DigitalOcean Demo Deployment](deployment/digitalocean-demo/README.md).

## Postman

- [Hướng dẫn Postman](../postman/README.md)
- [Import collection và environment](../postman/docs/01-import-collection-and-environment.md)
- [Lấy JWT bằng Authorization Code + PKCE](../postman/docs/02-keycloak-oauth-pkce.md)
- [Chạy smoke tests](../postman/docs/03-run-smoke-tests.md)
- [Đọc kết quả và xử lý lỗi](../postman/docs/04-troubleshooting.md)

## File máy đọc

- `deploy/demo/docker-compose.demo.yml`
- `deploy/demo/generate-env.sh`
- `deploy/demo/traefik.demo.yml`
- `deploy/demo/install-postman-client.sh`
- `postman/Animal-Locket-Demo-Smoke.postman_collection.json`
- `postman/Animal-Locket-Demo.postman_environment.json`

Không commit `.env`, private SSH key, `acme.json`, access token hoặc dữ liệu database.
