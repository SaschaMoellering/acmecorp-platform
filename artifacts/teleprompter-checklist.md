# Teleprompter Episode 5 Verification Checklist

Source script: `docs/episodes/episode-05/Teleprompter-Script-Episode-5-Polished.md`

## Checklist

- step-id: `C01-script-path`
  - action (command): `test -f docs/episodes/episode-05/Teleprompter-Script-Episode-5-Polished.md`
  - expected outcome: teleprompter markdown exists and is readable in this repo.
  - verification method: command exit code `0`.

- step-id: `C02-compose-dir-detect`
  - action (command): detect compose dir from script references (`cd infra/local`) and validate compose file presence (`docker-compose.yml` or `compose.yaml`).
  - expected outcome: compose directory resolved to `infra/local` with a valid compose file.
  - verification method: grep script for compose path + filesystem checks.

- step-id: `C03-compose-up`
  - action (command): `docker compose up -d` in detected compose directory.
  - expected outcome: stack starts without destructive reset; services needed for demo are running.
  - verification method: command success + `docker compose ps` shows `gateway-service` and `orders-service` in running/healthy state.

- step-id: `C04-endpoint-reachability`
  - action (command): HTTP probes against `http://localhost:8080/actuator/health` and `http://localhost:8081/actuator/health` (or API endpoint fallback).
  - expected outcome: required endpoints are reachable (2xx preferred; non-2xx recorded with body).
  - verification method: `curl` status code + response body snapshot.

- step-id: `C05-seed-data`
  - action (command): `curl -sS -X POST http://localhost:8080/api/gateway/seed` with status capture.
  - expected outcome: seed call succeeds (2xx/201), and data is created for order endpoints.
  - verification method: status code + response body + follow-up order endpoint returns non-empty data.

- step-id: `C06-nplus1-endpoint-limit5`
  - action (command): `curl -sS "http://localhost:8081/api/orders/demo/nplus1?limit=5"`.
  - expected outcome: endpoint returns 5 orders with nested items.
  - verification method: response JSON parsed for list size and item presence.

- step-id: `C07-nplus1-sql-evidence`
  - action (command): after invoking limit=5 endpoint, capture bounded logs:
    - `docker compose logs --no-color --tail <N> orders-service | grep -i "select"`
  - expected outcome: visible `1 + N` pattern for `limit=5` (1 orders select + ~5 order_items selects).
  - verification method: log snippet + counted matching statements.

- step-id: `C08-optimized-endpoint`
  - action (command): `curl -sS "http://localhost:8081/api/orders/latest"`.
  - expected outcome: endpoint returns latest orders with items.
  - verification method: response JSON is non-empty and includes items.

- step-id: `C09-optimized-sql-evidence`
  - action (command): capture bounded SQL logs corresponding to optimized request.
  - expected outcome: query pattern is approximately 1-2 SQL selects (join fetch/preload style), not `N+1`.
  - verification method: log snippet + counted statements for this request window.

- step-id: `C10-query-count-test`
  - action (command): `./mvnw test -Dtest=OrderServiceQueryCountTest`
  - expected outcome: test passes and validates query bound (`<=3` queries per teleprompter claim).
  - verification method: surefire output indicates success; failure output preserved if failing.

- step-id: `C11-claim-vs-observed-analysis`
  - action (command): compare all expected outcomes above vs observed outputs.
  - expected outcome: either all claims verified, or deviations documented with root cause evidence.
  - verification method: `artifacts/teleprompter-analysis.md` produced when any deviation/unverified step exists.
