# Helm charts for AcmeCorp Platform

This directory holds the canonical umbrella Helm chart (`helm/acmecorp-platform`) for deploying the backend services (gateway, orders, catalog) to Amazon EKS. The previous `charts/acmecorp-platform` chart is archived and should not be modified.

## Install (example)

```bash
helm upgrade --install acmecorp helm/acmecorp-platform -f helm/acmecorp-platform/values-dev.yaml
```

Customize values files or pass `--set` overrides for image tags, ingress host, and downstream service URLs. Ensure the following secrets exist before installing:

- `postgres.passwordSecret.name` (default `acmecorp-postgres`) with key `password`
- `rabbitmq.passwordSecret.name` (default `acmecorp-rabbitmq`) with keys `password`, `username` if needed
- `orders-service.secret.name` (default `orders-service-credentials`) with keys `username`, `password`, `rabbitmqUsername`, `rabbitmqPassword`
- `catalog-service.secret.name` (default `catalog-service-db`) with keys `username`, `password`
When IAM authentication is enabled for Aurora, export the following vars so the Helm chart can inject them into the Pods:

- `ACMECORP_PG_IAM_AUTH=true`
- `ACMECORP_PG_HOST`, `ACMECORP_PG_PORT`, `ACMECORP_PG_DB`, `ACMECORP_PG_USER`
- `AWS_REGION` (or override `ACMECORP_PG_REGION`)
You can keep `DB_PASSWORD` unset when IAM auth is active; regular database credentials continue to flow through the existing secrets otherwise.

Use `helm template` to validate rendered manifests before applying them.

## Upgrade

```bash
helm upgrade acmecorp helm/acmecorp-platform -f helm/acmecorp-platform/values-prod.yaml
```

When using production values, ensure secrets (Postgres + RabbitMQ credentials) are created in the target namespace, and update `ingress.host`, `ingress.tls.certificateArn`, and resource requests/limits as needed.
