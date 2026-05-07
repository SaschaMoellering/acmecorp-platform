# Architecture Steering

This file is a Codex compatibility note.

Canonical architecture facts live in:

- `../../docs/system-map.md`
- `../../docs/codebase-overview.md`
- `../../docs/architecture/system-overview.md`
- `../../docs/reference/services.md`

Current application services:

- `gateway-service`
- `orders-service`
- `billing-service`
- `notification-service`
- `analytics-service`
- `catalog-service`

Guardrails:

- Preserve the gateway boundary between the UI and backend services.
- Do not invent or reference removed services such as `inventory-service`.
- Treat `infra/k8s/base/` as a compatibility/demo path and `helm/acmecorp-platform/` as the canonical AWS packaging path.
