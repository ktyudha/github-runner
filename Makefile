-include .env

.PHONY: help up down restart rebuild logs ps shell

help:
	@echo "up       - jalankan github-runner"
	@echo "down     - stop + hapus container (runner di-unregister)"
	@echo "restart  - down lalu up"
	@echo "rebuild  - pull image terbaru + recreate"
	@echo "logs     - ikuti log runner"
	@echo "ps       - status container"
	@echo "shell    - masuk ke container"

up:
	docker compose up -d

down:
	docker compose down --remove-orphans

restart: down up

rebuild:
	docker compose pull
	docker compose up -d --force-recreate

logs:
	docker compose logs -f

ps:
	docker compose ps

shell:
	docker exec -it github-runner bash
