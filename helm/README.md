# Helm charts for AcmeCorp Platform

This directory holds the canonical Helm deployment tree for the platform.

Primary chart:

- [acmecorp-platform/README.md](acmecorp-platform/README.md)

The canonical chart under `helm/acmecorp-platform` deploys the application services, Redis, Prometheus, Grafana, and External Secrets for the AWS / EKS path.

The previous `charts/acmecorp-platform` chart is a legacy compatibility artifact and should not be modified for new deployment work.

## Install (example)

```bash
helm upgrade --install acmecorp-platform helm/acmecorp-platform \
  -n acmecorp \
  -f helm/acmecorp-platform/values-dev.yaml
```

Customize values files or pass `--set` overrides for image tags, ingress host, and downstream service URLs. Ensure the following secrets exist before installing:

- `postgres.passwordSecret.name` (default `acmecorp-postgres`) with key `password`
- `rabbitmq.passwordSecret.name` (default `acmecorp-rabbitmq`) with keys `password`, `username` if needed
- `orders-service.secret.name` (default `orders-service-credentials`) with keys `username`, `password`, `rabbitmqUsername`, `rabbitmqPassword`
- `catalog-service.secret.name` (default `catalog-service-db`) with keys `username`, `password`

Use `helm template` to validate rendered manifests before applying them.

For full chart structure, namespaces, rendering, and Terraform integration details, use [acmecorp-platform/README.md](acmecorp-platform/README.md).

## Upgrade

```bash
helm upgrade acmecorp-platform helm/acmecorp-platform \
  -n acmecorp \
  -f helm/acmecorp-platform/values-prod.yaml
```

When using production values, ensure secrets (Postgres + RabbitMQ credentials) are created in the target namespace, and update `ingress.host`, `ingress.tls.certificateArn`, and resource requests/limits as needed.
