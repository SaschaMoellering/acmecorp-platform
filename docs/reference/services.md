# Services Reference

## Application Services

| Service | Stack | Default Port | Health | Metrics | Notes |
| --- | --- | --- | --- | --- | --- |
| `gateway-service` | Spring Boot WebFlux | `8080` | `/actuator/health` | `/actuator/prometheus` | browser-facing API |
| `orders-service` | Spring Boot | `8081` | `/actuator/health` | `/actuator/prometheus` | order management |
| `billing-service` | Spring Boot | `8082` | `/actuator/health` | `/actuator/prometheus` | billing / invoices |
| `notification-service` | Spring Boot | `8083` | `/actuator/health` | `/actuator/prometheus` | messaging / notifications |
| `analytics-service` | Spring Boot | `8084` | `/actuator/health` | `/actuator/prometheus` | counters and analytics |
| `catalog-service` | Quarkus | `8085` | `/q/health` | `/q/metrics` | product catalog |

## Supporting Components

| Component | Port / Endpoint | Purpose |
| --- | --- | --- |
| PostgreSQL | `5432` | relational data |
| Redis | `6379` | analytics cache / counters |
| RabbitMQ | `5672` local / `5671` AWS TLS | broker |
| RabbitMQ UI | `15672` local | debugging |
| Prometheus | `9090` | metrics |
| Grafana | `3000` local | dashboards |

## Public Entry Points

- UI: `https://app.acmecorp.autoscaling.io`
- API: `https://api.acmecorp.autoscaling.io`
- Grafana: `https://grafana.acmecorp.autoscaling.io`

## Namespaces

| Namespace | Purpose |
| --- | --- |
| `acmecorp` | application workloads |
| `data` | Redis and related data workloads |
| `observability` | Prometheus and Grafana |
| `external-secrets` | External Secrets operator |
