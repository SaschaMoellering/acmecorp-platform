# Integration Tests

## Base URL

The integration tests target the gateway and derive the base URL from:

- `-Dacmecorp.baseUrl=...` (preferred)
- `ACMECORP_BASE_URL` (fallback)

Default: `http://localhost:8080`.

## Local run (same as CI)

1. `cd infra/local && docker compose up -d --build`
2. `bash scripts/wait-for-compose-health.sh`
3. `cd integration-tests && mvn -Dacmecorp.baseUrl=http://localhost:8080 test`
4. `cd infra/local && docker compose down`

CI uses `scripts/wait-for-compose-health.sh` to gate tests on service readiness.
