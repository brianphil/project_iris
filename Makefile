.PHONY: up down rebuild migrate seed reset verify test

up:
	docker compose up -d db
	docker compose exec -T db sh -c 'until pg_isready -U iris -d iris; do sleep 1; done'

down:
	docker compose down

rebuild:
	python -m iris.migrate rebuild

migrate:
	python -m iris.migrate migrate

seed:
	python -m iris.migrate seed

reset:
	python -m iris.migrate reset

verify:
	psql "$${DATABASE_URL:-postgresql://iris:iris@localhost:55432/iris}" -f verification/verify.sql

test:
	pytest -q
