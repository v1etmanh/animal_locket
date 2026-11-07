# Lối tắt cho docker compose. Cần file .env (make env). Chạy `make help` để xem danh sách.
COMPOSE ?= docker compose

.PHONY: help env up down core app obs logs ps build rebuild clean reset check

help:
	@echo "make env      Tạo .env từ .env.example (nhớ ĐỔI mật khẩu)"
	@echo "make core     Chỉ hạ tầng (DB, Kafka, Redis, Keycloak, Traefik)"
	@echo "make up       core + app (theo COMPOSE_PROFILES trong .env)"
	@echo "make app      Dựng/chạy lại các service Java"
	@echo "make obs      Thêm Prometheus/Loki/Tempo/Grafana"
	@echo "make logs S=user-service   Xem log một service"
	@echo "make ps | down | clean (xoá container, GIỮ dữ liệu) | reset (xoá cả dữ liệu!)"

env:
	@test -f .env && echo ".env đã có" || (cp .env.example .env && echo "Đã tạo .env, hãy sửa mật khẩu trước khi chạy")

up:
	$(COMPOSE) up -d --build

core:
	$(COMPOSE) --profile core up -d

app:
	$(COMPOSE) --profile core --profile app up -d --build

obs:
	$(COMPOSE) --profile core --profile obs up -d

logs:
	$(COMPOSE) logs -f --tail=200 $(S)

ps:
	$(COMPOSE) ps -a

build:
	$(COMPOSE) build

down:
	$(COMPOSE) --profile core --profile app --profile obs down

clean: down

# CẢNH BÁO: xoá toàn bộ volume (DB, ảnh, Kafka, Grafana...). Chỉ dùng cho môi trường dev.
reset:
	$(COMPOSE) --profile core --profile app --profile obs down -v

check:
	$(COMPOSE) config --quiet && echo "compose hợp lệ"
