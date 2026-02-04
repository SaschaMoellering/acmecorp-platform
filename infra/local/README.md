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

## CRaC checkpoint and restore (Spring Boot only)

Use the CRaC override so checkpoint artifacts are persisted in named volumes.

```bash
# Build Spring Boot service images serially
COMPOSE_PARALLEL_LIMIT=1 docker compose \
  -f docker-compose.yml \
  -f docker-compose.crac.yml \
  build gateway-service orders-service billing-service notification-service analytics-service
```

```bash
# Create a checkpoint
docker compose -f docker-compose.yml -f docker-compose.crac.yml run --rm \
  -e CRAC_MODE=checkpoint gateway-service

# Restore from the saved checkpoint
docker compose -f docker-compose.yml -f docker-compose.crac.yml run --rm \
  -e CRAC_MODE=restore gateway-service
```

Notes:
- CRaC is enabled only for Spring Boot services. Quarkus remains JVM-only.
- `/opt/crac` is persisted in one named volume (`crac-data`) shared by CRaC-enabled services.
- Health probing in CRaC mode is configurable with `CRAC_HEALTH_URL` (highest priority) or
  `CRAC_HEALTH_PORT` + `CRAC_HEALTH_PATH` (defaults: `8080` and `/actuator/health`).
- `orders-service` CRaC datasource lifecycle hook is gated by `CRAC_ENABLED=true` (set in the CRaC override).

### CRaC checkpoint directory convention

- Default checkpoint namespace is per service: `/opt/crac/<service>` (for example `/opt/crac/gateway-service`).
- `scripts/crac-demo.sh matrix` always uses `/opt/crac/<service>` for both checkpoint and restore (unless `FORCE_FLAT_CHECKPOINT_DIR=1` is set).
- `scripts/crac-restore-runs.sh` also defaults to `/opt/crac/<service>` and only falls back to flat `/opt/crac` when the service directory has no snapshot.

To fully reset CRaC snapshots (including old flat snapshots), run:

```bash
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml down
docker volume rm acmecorp-local_crac-data
```

Optional cleanup for legacy per-service volumes from older compose versions:

```bash
docker volume rm acmecorp-local_crac-gateway acmecorp-local_crac-orders \
  acmecorp-local_crac-billing acmecorp-local_crac-notification acmecorp-local_crac-analytics
```

## CRaC branch verification (Java 21 + Spring Boot 3.x)

From repository root:

```bash
# 1) Build and start base stack
COMPOSE_PARALLEL_LIMIT=1 docker compose -f infra/local/docker-compose.yml up -d --build --remove-orphans

# 2) Verify Java runtime version inside each service container (must be 21)
for s in gateway-service orders-service billing-service notification-service analytics-service catalog-service; do
  echo "== $s =="
  docker compose -f infra/local/docker-compose.yml exec -T "$s" java -version 2>&1 | head -n 1
done

# 3) Verify Spring Boot major version from startup logs (must show v3.x)
for s in gateway-service orders-service billing-service notification-service analytics-service; do
  echo "== $s =="
  docker compose -f infra/local/docker-compose.yml logs --tail=200 "$s" | grep -E ":: Spring Boot ::.*\\(v3\\."
done
```

CRaC checkpoint/restore verification for two representative services:

```bash
# Gateway
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml run --rm \
  -e CRAC_MODE=checkpoint gateway-service
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml run --rm \
  -e CRAC_MODE=restore gateway-service

# Orders
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml run --rm \
  -e CRAC_MODE=checkpoint orders-service
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml run --rm \
  -e CRAC_MODE=restore orders-service
```

Matrix demo (Spring Boot services by default):

```bash
scripts/crac-demo.sh matrix

# Include catalog-service explicitly if needed
CRAC_MATRIX_SERVICES=gateway-service,orders-service,billing-service,notification-service,analytics-service,catalog-service \
  scripts/crac-demo.sh matrix
```

Expected checks:
- Java output starts with `openjdk version "21..."`
- Spring startup log line contains `:: Spring Boot ::` with `(v3...)`
- Checkpoint logs include `Checkpoint successful` or `Checkpoint created successfully`
- Restore run starts successfully and reaches `/actuator/health`
