# Observability

The platform uses Prometheus and Grafana for metrics-based observability.

## What Exists Today

- Prometheus configuration and packaging under `helm/acmecorp-platform/charts/prometheus`
- Grafana packaging under `helm/acmecorp-platform/charts/grafana`
- Service monitors and dashboards under `infra/observability/`
- Spring Boot Actuator metrics on Spring services
- Quarkus metrics on the catalog service

## Metrics Endpoints

| Component | Metrics Endpoint |
| --- | --- |
| Spring Boot services | `/actuator/prometheus` |
| Catalog (Quarkus) | `/q/metrics` |

## Local Observability

Bring up the local stack plus observability:

```bash
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.observability.yml up --build
```

Expected local URLs:
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`
- Alertmanager: `http://localhost:9093`

## Kubernetes Observability

Primary namespace:
- `observability`

Prometheus and Grafana are packaged in the Helm umbrella chart.

Useful checks:

```bash
kubectl get pods -n observability
kubectl get svc -n observability
kubectl get servicemonitor -A
```

## Dashboards

Tracked dashboard assets include:
- `infra/observability/grafana/acmecorp-jvm-http-overview.json`

Validation guidance:
- see `docs/observability/dashboard-validation.md`

## What Does Not Exist

This repository does **not** currently implement a full OpenTelemetry pipeline. The observability path is Prometheus + Grafana, plus service health endpoints.
