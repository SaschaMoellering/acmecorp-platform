# Getting Started (Local)

## 1) What this project is

AcmeCorp Platform is a local microservices demo with Spring Boot and Quarkus services, a React + Vite webapp, and Docker Compose for orchestration. The local runtime is defined in `infra/local/docker-compose.yml`.

## 2) Prerequisites

- Docker with Docker Compose v2
- Node.js >= 20 (only if you want to run the webapp)
- Java + Maven (only if you want to run JVM tests locally)

## 3) Clone & setup

```bash
git clone https://github.com/SaschaMoellering/acmecorp-platform.git
cd acmecorp-platform
```

## 4) Start local stack (Docker Compose)

```bash
cd infra/local
docker compose up -d --build
```

To stop and remove containers:

```bash
cd infra/local
docker compose down --volumes
```

## 5) Verify it works

- Gateway health: `http://localhost:8080/api/gateway/status`
- Orders: `http://localhost:8081`
- Billing: `http://localhost:8082`
- Notification: `http://localhost:8083`
- Analytics: `http://localhost:8084`
- Catalog: `http://localhost:8085`
- RabbitMQ UI: `http://localhost:15672`

Quick check:

```bash
curl http://localhost:8080/api/gateway/status
```

Optional webapp:

```bash
cd webapp
npm install
npm run dev
```

Webapp URL: `http://localhost:5173`

## 6) Common first errors and fixes

- `docker compose: command not found` — install Docker Desktop or the Docker Compose v2 plugin.
- `Bind for 0.0.0.0:8080 failed` (or 5432/6379/5672) — stop the conflicting local service or change the port mappings in `infra/local/docker-compose.yml`.
- Gateway returns `5xx` right after startup — wait a few seconds for the services and dependencies to initialize, then retry the health check.

## 7) Where to go next

- README: [`README.md`](../README.md)
- Architecture diagram: [`docs/architecture/docker-compose.svg`](architecture/docker-compose.svg) (source: [`docs/architecture/docker-compose.mmd`](architecture/docker-compose.mmd))
- Infrastructure entry point: [`scripts/tf.sh`](../scripts/tf.sh)
