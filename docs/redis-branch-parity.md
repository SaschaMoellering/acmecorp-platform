# Redis Branch Parity (java21 vs java17)

## Differences Found

- `services/spring-boot/gateway-service/pom.xml`: java17 included `spring-boot-starter-data-redis-reactive`; java21 did not. This caused gateway to auto-configure Redis and attempt `localhost:6379`.
- `services/spring-boot/orders-service/pom.xml`: java17 included `spring-boot-starter-data-redis` + `spring-boot-starter-cache`; java21 did not.
- `infra/local/docker-compose.yml`: identical between branches (already includes `redis` service).
- `services/spring-boot/analytics-service/src/main/resources/application.yml`: Redis host/port set via `REDIS_HOST`/`REDIS_PORT` with default `redis`.

## Observed Behavior

Because host port access is blocked in this environment, health checks were executed inside containers.

### java17

- Gateway logs show Redis connection failures to `localhost:6379` due to Redis auto-config in gateway:
  - `RedisReactiveHealthIndicator : Redis health check failed`
  - `Unable to connect to localhost/<unresolved>:6379`
- Gateway health:
  - `/actuator/health` = `DOWN`
  - `/actuator/health/readiness` = `UP`
  - `/actuator/health/liveness` = `UP`
- Analytics health:
  - `/actuator/health` = `UP`
  - `/actuator/health/readiness` = `UP`
  - `/actuator/health/liveness` = `UP`

### java21

- Gateway logs show no Redis activity.
- Gateway health:
  - `/actuator/health` = `UP`
  - `/actuator/health/readiness` = `UP`
  - `/actuator/health/liveness` = `UP`
- Analytics health:
  - `/actuator/health` = `UP`
  - `/actuator/health/readiness` = `UP`
  - `/actuator/health/liveness` = `UP`

## Unified Local Behavior (Chosen)

- Redis is run via docker-compose as `redis`.
- Only `analytics-service` uses Redis; gateway/orders do not auto-configure Redis.
- `analytics-service` readiness includes both `db` and `redis` to be production-like.
- Local docker-compose exposes health details for analytics so Redis readiness can be validated.

## How to Run Locally

```bash
bash scripts/compose-build-safe.sh
cd infra/local
docker compose up -d
./validate-health.sh
```

## Notes

- If you are applying this to another branch, cherry-pick the same changes or re-apply the file edits listed in this doc.
