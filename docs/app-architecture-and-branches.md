# AcmeCorp Platform – Architecture & Branch Strategy

## Overview

AcmeCorp is a demo platform built to showcase:
- Mixed Java stacks (Spring Boot + Quarkus)
- Containerized microservices
- Kubernetes (Kustomize + Helm)
- EKS Auto Mode on AWS
- Observability with Prometheus & Grafana

## Services

### Spring Boot Services

- **orders-service**
  - HTTP: `/api/orders/status` (and more in later episodes)
  - Connects to PostgreSQL
  - Exposes `/actuator/prometheus`

- **billing-service**
  - HTTP: `/api/billing/status`
  - Connects to PostgreSQL
  - Exposes `/actuator/prometheus`

- **notification-service**
  - HTTP:
    - `/api/notification/status`
    - `/api/notification/send?recipient=...&message=...`
  - Publishes messages to RabbitMQ:
    - Exchange: `notifications-exchange`
    - Queue: `notifications-queue`
  - Exposes `/actuator/prometheus`

- **analytics-service**
  - HTTP:
    - `/api/analytics/status`
    - `/api/analytics/track?event=...`
  - Uses Redis as backing store for event counters
  - Exposes `/actuator/prometheus`

- **gateway-service**
  - API gateway / edge service
  - HTTP:
    - `/api/gateway/orders` → proxies to orders-service
    - `/api/gateway/catalog` → proxies to catalog-service
  - Uses `WebClient` to call internal services
  - Exposes `/actuator/prometheus`

### Quarkus Service

- **catalog-service**
  - HTTP:
    - `/api/catalog`
  - Health:
    - `/q/health/live`
    - `/q/health/ready`
  - Metrics:
    - `/q/metrics`

## Infrastructure

### Local (Docker Compose)

`infra/local/docker-compose.yml` defines:

- `postgres`
- `redis`
- `rabbitmq`
- `orders-service`
- `billing-service`
- `notification-service`
- `analytics-service`
- `catalog-service` (Quarkus)
- `gateway-service` (Spring, edge)

### Kubernetes

Base manifests under `infra/k8s/base/`:

- Namespace: `acmecorp`
- Deployments + Services for all services
- `gateway-service` is exposed as `LoadBalancer`

Use:

```bash
kubectl apply -k infra/k8s/base
```

### Helm

Helm chart in `charts/acmecorp-platform/` manages:

- All services with `enabled` flags
- Image repositories/tags
- Ports
- Namespace configuration

Install:

```bash
helm install acmecorp charts/acmecorp-platform -n acmecorp --create-namespace
```

### Observability

`infra/observability/k8s/` contains `ServiceMonitor` resources for:

- orders-service
- billing-service
- notification-service
- analytics-service
- gateway-service
- catalog-service

Assumes `kube-prometheus-stack` (Prometheus Operator) installed in `monitoring` namespace with label `release=monitoring`.

## Branch Strategy (Suggested)

- `main`
  - Always stable, demo-ready state.

- `season1`
  - Integration branch for Season 1 episodes.

- Feature / episode branches (examples):
  - `feature/episode1-foundation`
  - `feature/episode2-jvm-deep-dive`
  - `feature/episode3-eks-auto-mode`
  - `feature/episode4-observability`

- Java evolution branches:
  - `java-17-baseline`
  - `java-21-modern`
  - `java-25-latest`

- Experiment branches:
  - `perf/async-profiler-lab`
  - `quarkus/catalog-native`

Update this document as you refine branch names in your real repo.
