.PHONY: test-backend test-frontend test-all smoke-local up down build-backend

test-backend:
	for svc in services/spring-boot/* services/quarkus/*; do \
		if [ -d "$$svc" ] && [ -f "$$svc/pom.xml" ]; then \
			echo "Testing $$svc"; \
			(cd "$$svc" && mvn -q test); \
		fi; \
	done

test-frontend:
	cd webapp && npm test

test-all: test-backend test-frontend

smoke-local:
	./scripts/smoke-local.sh

up:
	cd infra/local && docker compose up -d

down:
	cd infra/local && docker compose down

build-backend:
	for svc in services/spring-boot/* services/quarkus/*; do \
		if [ -d "$$svc" ] && [ -f "$$svc/pom.xml" ]; then \
			echo "Building $$svc"; \
			(cd "$$svc" && mvn -q package -DskipTests); \
		fi; \
	done
