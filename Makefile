.PHONY: up build seed setup fresh test

up:
	docker compose up

build:
	docker compose build

seed:
	docker compose exec backend bundle exec rails db:seed

setup: build
	docker compose up -d db
	docker compose run --rm backend bundle exec rails db:create db:migrate db:seed
	docker compose up

fresh:
	docker compose down -v
	$(MAKE) setup

test:
	docker compose exec backend bash -c "RAILS_ENV=test bundle exec rspec --format documentation"
