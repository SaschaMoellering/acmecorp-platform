# Local Docker Compose

This stack runs Postgres, Redis, RabbitMQ, and the backend services with the `docker` profile.

## Start the stack

```bash
cd infra/local
docker compose up -d --build
```

Default builds use JVM Dockerfiles to keep local iteration fast and safe. Compose
loads `infra/local/.env`, which sets `COMPOSE_PARALLEL_LIMIT=1` so builds stay
serial and avoid host freezes during native-image compilation.

Recommended build helper (from repo root):

```bash
bash scripts/compose-build-safe.sh
```

To build native images explicitly (slow but safe/serial):

```bash
cd infra/local
docker compose -f docker-compose.yml -f docker-compose.native.yml build
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
