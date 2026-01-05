# Local Docker Compose

This stack runs Postgres, Redis, RabbitMQ, and the backend services with the `docker` profile.

## Start the stack

```bash
cd infra/local
docker compose up -d --build
```

## Redis expectations

- Redis runs as the `redis` service and is used by `analytics-service`.
- `analytics-service` readiness includes Redis and the database, so `/actuator/health/readiness` will be `UP` only when both are healthy.

## Validate health

```bash
./validate-health.sh
```
