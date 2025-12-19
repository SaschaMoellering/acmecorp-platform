.PHONY: test-backend test-frontend test-all smoke-local up down build-backend clean logs help

help: ## Show this help message
	@echo "AcmeCorp Platform Development Commands"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test-backend: ## Run backend service tests
	for svc in services/spring-boot/* services/quarkus/*; do \
		if [ -d "$$svc" ] && [ -f "$$svc/pom.xml" ]; then \
			echo "Testing $$svc"; \
			(cd "$$svc" && mvn -q test); \
		fi; \
	done

test-frontend: ## Run frontend tests
	cd webapp && npm test

test-integration: ## Run integration tests
	cd integration-tests && mvn test

test-all: test-backend test-frontend test-integration ## Run all tests

smoke-local: ## Run smoke tests against local stack
	./scripts/smoke-local.sh

up: ## Start local Docker Compose stack
	cd infra/local && docker compose up -d

down: ## Stop local Docker Compose stack
	cd infra/local && docker compose down

logs: ## Show logs from Docker Compose stack
	cd infra/local && docker compose logs -f

build-backend: ## Build backend services
	for svc in services/spring-boot/* services/quarkus/*; do \
		if [ -d "$$svc" ] && [ -f "$$svc/pom.xml" ]; then \
			echo "Building $$svc"; \
			(cd "$$svc" && mvn -q package -DskipTests); \
		fi; \
	done

build-frontend: ## Build frontend application
	cd webapp && npm run build

clean: ## Clean build artifacts
	for svc in services/spring-boot/* services/quarkus/*; do \
		if [ -d "$$svc" ] && [ -f "$$svc/pom.xml" ]; then \
			(cd "$$svc" && mvn clean); \
		fi; \
	done
	cd webapp && rm -rf dist/ node_modules/.cache/

dev-setup: ## Setup development environment
	cd webapp && npm install
	$(MAKE) build-backend

full-test: up test-all smoke-local down ## Full test cycle with Docker stack
