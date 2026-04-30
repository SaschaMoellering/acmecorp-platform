# Observability Assets

This directory contains infrastructure-side observability assets for the platform.

## What Lives Here

- Grafana dashboards under `grafana/`
- Kubernetes ServiceMonitor manifests under `k8s/`
- local Compose-side Prometheus, Grafana, and Alertmanager configuration under `../local/observability/`

Canonical operational guidance also lives in:

- [../../docs/operations/observability.md](../../docs/operations/observability.md)
- [../local/README.md](../local/README.md)
- [../../helm/acmecorp-platform/README.md](../../helm/acmecorp-platform/README.md)

## Local Observability

The local observability overlay uses:

- `infra/local/docker-compose.observability.yml`
- Prometheus on `http://localhost:9090`
- Grafana on `http://localhost:3000`
- Alertmanager on `http://localhost:9093`

## Kubernetes Observability

ServiceMonitor manifests are kept under `infra/observability/k8s/` for the application services.

The canonical AWS deployment path packages Prometheus and Grafana through the Helm chart under `helm/acmecorp-platform/`.
