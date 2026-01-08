# Integration Tests

## Base URL

The integration tests derive service URLs from `ACMECORP_BASE_URL` (default: `http://localhost:8080`).

## Local run (same as CI)

1. `cd infra/local && docker compose up -d --build`
2. `bash scripts/wait-for-compose-health.sh`
3. `cd integration-tests && ACMECORP_BASE_URL=http://localhost:8080 mvn test`
4. `cd infra/local && docker compose down`

CI uses `scripts/wait-for-compose-health.sh` to gate tests on service readiness.
