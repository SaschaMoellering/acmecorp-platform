# Local Docker Compose

This stack runs Postgres, Redis, RabbitMQ, and the backend services with the `docker` profile.

Canonical local-development guidance also lives in:

- [../../docs/development/local-setup.md](../../docs/development/local-setup.md)
- [../../docs/operations/observability.md](../../docs/operations/observability.md)

## Compose Files

- `infra/local/docker-compose.yml`: main local stack
- `infra/local/docker-compose.observability.yml`: Prometheus, Grafana, Alertmanager, and optional `k6`

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

## Default Ports

- Gateway: `http://localhost:8080`
- Orders: `http://localhost:8081`
- Billing: `http://localhost:8082`
- Notification: `http://localhost:8083`
- Analytics: `http://localhost:8084`
- Catalog: `http://localhost:8085`
- PostgreSQL: `localhost:5432`
- Redis: `localhost:6379`
- RabbitMQ: `localhost:5672`
- RabbitMQ UI: `http://localhost:15672`

## Local Credentials

- PostgreSQL: `acmecorp` / `acmecorp`
- RabbitMQ: `acmecorp` / `acmecorp`

These are the local Compose defaults. They are not the same as the older plain Kubernetes base manifests under `infra/k8s/base/`.

## Redis expectations

- Redis runs as the `redis` service and is used by `analytics-service`.
- `analytics-service` readiness includes Redis and the database, so `/actuator/health/readiness` will be `UP` only when both are healthy.

## Validate health

```bash
./validate-health.sh
```

Wait for the full stack from the repo root:

```bash
bash scripts/wait-for-compose-health.sh
```

Run the local smoke checks from the repo root:

```bash
BASE_URL=http://localhost:8080 bash scripts/smoke-local.sh
```

## RabbitMQ DLQ demo

The local notification pipeline now declares its RabbitMQ topology on startup:

- main exchange: `notifications-exchange`
- main queue: `notifications-queue`
- dead-letter exchange: `notifications-dlx`
- dead-letter queue: `notifications-queue.dlq`

Inspect the topology from the repo root:

```bash
docker compose -f infra/local/docker-compose.yml exec rabbitmq rabbitmqctl list_queues name arguments
docker compose -f infra/local/docker-compose.yml exec rabbitmq rabbitmqctl list_exchanges name type
```

To demonstrate bounded retry followed by dead-lettering, restart `notification-service` with a deterministic local failure target:

```bash
docker compose -f infra/local/docker-compose.yml stop notification-service
NOTIFICATION_FAIL_ON_RECIPIENT=dlq-demo@acme.test \
docker compose -f infra/local/docker-compose.yml up -d notification-service
```

Then publish a matching notification, for example by creating an order that uses `dlq-demo@acme.test` as the customer email. The notification listener will retry a bounded number of times, reject the message, and RabbitMQ will route it to `notifications-queue.dlq` instead of requeueing it forever.

## Load tests (k6)

The `k6` service is behind the `load` profile, so it only appears when the profile is enabled.

```bash
# From repo root
docker compose \
  -f infra/local/docker-compose.yml \
  -f infra/local/docker-compose.observability.yml \
  --profile load \
  config --services | sort
```

Run a one-off load test:

```bash
# From repo root
docker compose \
  -f infra/local/docker-compose.yml \
  -f infra/local/docker-compose.observability.yml \
  --profile load \
  run --rm k6
```

Run and exit when the k6 container finishes:

```bash
# From repo root
docker compose \
  -f infra/local/docker-compose.yml \
  -f infra/local/docker-compose.observability.yml \
  --profile load \
  up --abort-on-container-exit k6
```

## Stop Safely

From `infra/local/`:

```bash
docker compose down
```

From the repo root with the observability overlay:

```bash
docker compose \
  -f infra/local/docker-compose.yml \
  -f infra/local/docker-compose.observability.yml \
  down
```
