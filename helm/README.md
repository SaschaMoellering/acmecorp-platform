# Helm charts for AcmeCorp Platform

This directory introduces the canonical umbrella Helm chart (`helm/acmecorp-platform`) for deploying the backend services (gateway, orders, catalog) to Amazon EKS. Do **not** edit the older `charts/acmecorp-platform` chart; the one under `helm/` is the active source of truth moving forward.

## Install (example)

```bash
helm upgrade --install acmecorp helm/acmecorp-platform -f helm/acmecorp-platform/values-dev.yaml
```

Customize values files or pass `--set` overrides for secrets (Postgres/RabbitMQ credentials) and ingress host/ALB settings. The chart expects the following secrets before install:

- `postgres.passwordSecret.name` (`acmecorp-postgres` by default)
- `rabbitmq.passwordSecret.name` (`acmecorp-rabbitmq`)
- `orders-service.secret.name` (`orders-service-credentials`)
- `catalog-service.secret.name` (`catalog-service-db`)

Each secret must expose the keys referenced in the values (e.g., `password`, `username`, `rabbitmqPassword`).

## Upgrade

```bash
helm upgrade acmecorp helm/acmecorp-platform -f helm/acmecorp-platform/values-prod.yaml
```

Secrets referenced via `postgres.passwordSecret.name`/`key` and `rabbitmq.passwordSecret` must exist before install.
