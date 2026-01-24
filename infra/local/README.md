# Local Docker Compose

This stack runs Postgres, Redis, RabbitMQ, and the backend services with the `docker` profile.

## Start the stack

```bash
cd infra/local
docker compose up -d --build
```

## Clean rebuild (no cache)

Use this when Docker BuildKit cache mounts need to be cleared (e.g., Maven cache under `/root/.m2`).

```bash
cd infra/local
docker compose down -v --remove-orphans
docker builder prune -af
docker buildx prune -af
docker compose build --no-cache --pull
docker compose up -d
```

## Redis expectations

- Redis runs as the `redis` service and is used by `analytics-service`.
- `analytics-service` readiness includes Redis and the database, so `/actuator/health/readiness` will be `UP` only when both are healthy.

## Validate health

```bash
./validate-health.sh
```
