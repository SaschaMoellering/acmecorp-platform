# Integration Tests

## Base URL

The integration tests target the gateway and derive the base URL from:

- `-DbaseUrl=...` (preferred)
- `-Dacmecorp.baseUrl=...`
- `BASE_URL`
- `GATEWAY_BASE_URL`
- `ACMECORP_BASE_URL`

Default: `http://localhost:8080`.

## Local run (same as CI)

1. `cd infra/local && docker compose up -d --build`
2. `BASE_URL=http://localhost:8080 TIMEOUT_SECONDS=180 bash ../scripts/wait-for-compose-health.sh`
3. `cd ../integration-tests && mvn -DbaseUrl=http://localhost:8080 test`
4. `cd infra/local && docker compose down`

CI uses `scripts/wait-for-compose-health.sh` to gate tests on service readiness.
