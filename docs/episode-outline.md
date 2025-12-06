# AcmeCorp Engineering Series – Season 1 Outline

This document links the video episodes to concrete services and infrastructure pieces
inside the AcmeCorp platform repository.

## Episode 1 – Foundation: Platform, Spring Boot & Quarkus on Kubernetes

Focus:
- High-level architecture
- Local Docker Compose stack
- Kubernetes base manifests
- Helm chart structure

Code touchpoints:
- `services/spring-boot/orders-service`
- `services/quarkus/catalog-service`
- `services/spring-boot/gateway-service`
- `infra/local/docker-compose.yml`
- `infra/k8s/base/`
- `charts/acmecorp-platform/`
- `docs/getting-started.md`
- `docs/app-architecture-and-branches.md`

## Episode 2 – JVM Deep Dive: Virtual Threads, N+1, Profiling

Focus:
- Orders Service as the main JVM subject
- Virtual Threads vs classic requests
- N+1 query problems and fixes
- Intro to profiling & metrics

Code touchpoints:
- `services/spring-boot/orders-service`
  - Controllers, repositories, configuration
- `infra/observability/grafana/acmecorp-jvm-http-overview.json` (used later)
- Scripts / commands (not yet in repo) for async-profiler and load testing

Services in play:
- orders-service (primary)
- Postgres from Docker Compose or K8s

## Episode 3 – Deploying & Optimizing on EKS Auto Mode

Focus:
- Taking the platform to a real EKS cluster
- Observing behavior under load
- Comparing Spring Boot vs Quarkus behavior

Code touchpoints:
- `infra/k8s/base/` (used as basis for EKS overlays)
- `charts/acmecorp-platform/` (Helm deployment to EKS)
- `infra/aws/terraform/` (if used to provision EKS in your setup)
- Services:
  - orders-service
  - catalog-service (Quarkus)
  - gateway-service

Conceptual topics:
- Pod sizing, CPU/memory requests
- EKS Auto Mode scheduling
- Impact of startup time & resource usage

## Episode 4 – Observability with Prometheus & Grafana (Spring + Quarkus + Gateway)

Focus:
- Platform-wide observability
- JVM + HTTP dashboards
- Comparing services via metrics

Code touchpoints:
- `infra/observability/k8s/*-servicemonitor.yaml`
- `infra/observability/grafana/acmecorp-jvm-http-overview.json`
- All Spring Boot services and catalog-service (Quarkus)
- gateway-service as the “edge” view of traffic

Metrics covered (examples):
- JVM memory (heap, non-heap)
- CPU usage
- HTTP request rate & latency (p95)
- Gateway traffic patterns

## Services and Episodes Matrix

| Service             | Ep1 | Ep2 | Ep3 | Ep4 |
|---------------------|:---:|:---:|:---:|:---:|
| orders-service      |  X  |  X  |  X  |  X  |
| billing-service     |  X  |     |  X  |  X  |
| notification-service|  X  |     |  X  |  X  |
| analytics-service   |  X  |     |  X  |  X  |
| catalog-service     |  X  | (teaser) | X | X |
| gateway-service     |  X  |     |  X  |  X  |

You can evolve this mapping as you refine the episodes and add more scenarios.
