# Observability Standards

This file is a Codex compatibility note.

Canonical observability guidance lives in:

- `../../docs/operations/observability.md`
- `../../infra/observability/README.md`
- `../../docs/reference/services.md`

Current endpoint rules:

- Spring Boot services expose metrics at `/actuator/prometheus`.
- The Quarkus `catalog-service` exposes metrics at `/q/metrics`.
- Observability assets live under `infra/observability/` and `infra/local/observability/`.

Do not rename scrape paths, metric names, or dashboard assumptions without updating the matching observability assets and docs.
