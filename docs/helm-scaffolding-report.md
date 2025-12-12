# Helm Scaffolding Requirements Report

## Overview

This report captures everything required to scaffold an umbrella Helm chart for the **backend only** (gateway, orders, catalog) so it can be deployed to Amazon EKS while the React SPA lives outside Helm (S3/CloudFront via Terraform). The details derive directly from the existing Docker Compose stack (`infra/local/docker-compose.yml`), Spring Boot / Quarkus configuration, current Kubernetes manifests (`infra/k8s/base/`), and the Java build artifacts in `services/`. No assumptions beyond repository facts are introduced.

## Backend Services Inventory

| Service | Path | Framework | Container port(s) | Health endpoints | Metrics endpoint | Notes |
|---|---|---|---|---|---|---|
| Gateway Service | `services/spring-boot/gateway-service` | Spring Boot WebFlux | 8080 (`EXPOSE` + Spring server.port) | `/actuator/health` (management exposure) | `/actuator/prometheus` | Entry point for `/api/gateway/**` (see controller) |
| Orders Service | `services/spring-boot/orders-service` | Spring Boot | 8081 | `/actuator/health` | `/actuator/prometheus` | Exposes `/api/orders/*` and `/api/orders/demo/nplus1` |
| Catalog Service | `services/quarkus/catalog-service` | Quarkus | 8085 | (Quarkus health not explicitly enabled; rely on readiness from Kubernetes manifest/health probe) | `/q/metrics` | Connects to PostgreSQL via `CATALOG_JDBC_URL` |

## Current Deployment Artifacts

- **Docker Compose (infra/local/docker-compose.yml)**
  - Ports: Gateway 8080, Orders 8081, Billing 8082, Notification 8083, Analytics 8084, Catalog 8085, Postgres 5432, Redis 6379, RabbitMQ 5672/15672.
  - Each service builds from its Dockerfile (Spring Boot services under `services/spring-boot/*`, catalog from `services/quarkus/catalog-service`).
  - Env vars: Spring services read `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`, plus RabbitMQ/Redis host/port defaults; gateway uses `ORDERS_BASE_URL`, `CATALOG_BASE_URL`, etc.
  - Depends: orders/billing/analytics/catalog → Postgres; notification → Postgres + RabbitMQ; analytics → Postgres + Redis; gateway → all backend services.

- **Existing Kubernetes manifests**
  - Base manifests in `infra/k8s/base/` deploy all services plus dependencies (Postgres, Redis, RabbitMQ) and include `ServiceMonitor` YAMLs under `infra/observability/k8s/*-servicemonitor.yaml`.
  - Observability stack wires Prometheus scraping for `/actuator/prometheus` (Spring) and `/q/metrics` (Quarkus).

- **Existing Helm chart**
  - Chart scaffold at `charts/acmecorp-platform/` (umbrella chart). Review this as a starting point; completeness relative to new requirements must be verified.

## Runtime Configuration per Service

### Gateway
- **Env vars**: `ORDERS_BASE_URL`, `CATALOG_BASE_URL`, `BILLING_BASE_URL`, `NOTIFICATION_BASE_URL`, `ANALYTICS_BASE_URL`, `SPRING_PROFILES_ACTIVE` (e.g., `docker`).
- **Config keys**: `spring.application.name`, `server.port`, management exposures under `management.endpoints.web.exposure.include=health,info,prometheus`.
- **Secrets/external deps**: none beyond downstream service URLs (should be provided via ConfigMaps/values).
- **External dependencies**: requires the downstream Spring/Quarkus services (orders, catalog, billing, analytics, notification).

### Orders Service
- **Env vars**: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`, `RABBITMQ_HOST`, `RABBITMQ_PORT`, `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`, `ACMECORP_SERVICES_*` (catalog/billing/analytics/notification base URLs).
- **Config keys**: `spring.datasource.*`, `spring.jpa.hibernate.ddl-auto`, `spring.jpa.properties.hibernate.format_sql`.
- **Secrets/external deps**: PostgreSQL, RabbitMQ, downstream service endpoints (catalog/billing/analytics/notification) injected via values/secrets.
- **Notes**: Additional runtime behavior (N+1 demo endpoint, analytics tracking) assumes network connectivity to messaging clients; no IRSA/IAM references.

### Catalog Service
- **Env vars**: `DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `CATALOG_JDBC_URL`.
- **Config keys**: Quarkus datasource and Hibernate (`quarkus.datasource.*`, `quarkus.hibernate-orm.database.generation`).
- **Secrets/external deps**: PostgreSQL connection string (secret). Observes no messaging dependencies.

### Shared infrastructure (from compose + manifests)
- **PostgreSQL**: hosts multiple services; connection env vars listed above. Could be an external managed RDS instance (recommended for EKS) with credentials injected via Kubernetes Secret.
- **Redis**: used by analytics-service (Config not covered here but part of backend). Provide `REDIS_HOST`, `REDIS_PORT`.
- **RabbitMQ**: used by notification-service/orders-service for messaging; provide `RABBITMQ_HOST`, `RABBITMQ_PORT`, `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`.

## Networking & Ingress Plan (EKS)

- **External entry point**: `gateway-service` exposes `/api/gateway/**` and proxies to backend REST endpoints (`/api/orders`, `/api/catalog`, `/api/analytics`, etc.). React UI expects the gateway at `http://localhost:8080` in dev but can be hosted under a custom domain in production.
- **ALB Ingress proposal**:
  - **Host**: value (e.g., `api.acmecorp.example.com`) supporting TLS via ACM (value-driven).
  - **Paths**:
    - `/*` → `gateway-service` for HTTP API (optionally scope to `/api/gateway/*` if future separation desired).
  - **TLS**: assume ACM certificate (value `tls.certificateArn`).
  - **Internal flag**: values can toggle `alb.ingress.kubernetes.io/scheme` between `internet-facing` and `internal`.
  - **Annotations**: `alb.ingress.kubernetes.io/target-type=ip`, `alb.ingress.kubernetes.io/listen-ports=[{"HTTP":80,"HTTPS":443}]`.

- **Path routing summary**:
  - `/api/gateway/orders/**` → gateway reacts and proxies to `orders-service`.
  - `/api/gateway/catalog/**` → proxied to `catalog-service`.
  - `/api/gateway/analytics/**`, `/api/gateway/notification/**` → same gateway.

- **Gateway-origin expectation**: SPA expects gateway under the same origin used in `VITE_API_BASE_URL` (not baked into Helm). Ensure the ALB hostname matches the UI configuration.

## Observability Hooks

- **Prometheus**: each Spring Boot service exposes `/actuator/prometheus`; the Quarkus catalog exposes `/q/metrics`.
- **ServiceMonitor config**: `infra/observability/k8s/*-servicemonitor.yaml` scrape those endpoints every 15s. Helm chart should annotate Services with `prometheus.io/scrape` (true) and `prometheus.io/path` as appropriate.
- **OpenTelemetry**: no explicit OTEL env vars found in the backend; rely on Prometheus endpoints.

## Helm Chart Scaffolding Plan

- **Umbrella chart**: `helm/acmecorp-platform` that stitches together subcharts for the backend runtime.
- **Subcharts**:
  1. `gateway-service`
  2. `orders-service`
  3. `catalog-service`
  4. (Optional) `postgres`, `redis`, `rabbitmq` if desired, or leave as external dependencies.

- **Templates per service**:
  - `deployment.yaml` – pods using Dockerfile-built images, env vars referencing values/secrets, resource requests/limits (defaults TBD).
  - `service.yaml` – ClusterIP services on configured ports.
  - `serviceaccount.yaml` (optional) – only if RBAC needed (none detected currently).
  - `ingress.yaml` – only required for `gateway-service` (ALB ingress via chart-wide host/path).
  - `configmap.yaml` – for non-secret settings (management exposures, downstream URLs).
  - `secret.yaml` – Postgres/RabbitMQ credentials, Quarkus JDBC URL.
  - `prometheus-scrape-config.yaml` or annotations – ensure metrics endpoints are discoverable.

- **Values keys** (non-exhaustive):
  - `gateway.image.repository` / `gateway.image.tag`
  - `orders.image.repository` / `orders.image.tag`
  - `catalog.image.repository` / `catalog.image.tag`
  - `postgres.host`, `postgres.port`, `postgres.database`, `postgres.username`, `postgres.passwordSecretName`
  - `redis.host`, `redis.port`
  - `rabbitmq.host`, `rabbitmq.port`, `rabbitmq.username`, `rabbitmq.passwordSecretName`
  - `gateway.baseUrl` / `orders.baseUrl` etc. for downstream service discovery in `gateway-service`
  - `resources.*` for each deployment (requests/limits)
  - `ingress.host`, `ingress.tls.certificateArn`, `ingress.internal` (boolean)
  - `observability.prometheus.enabled` (toggles annotations)

- **Secrets & config strategy**:
  - Use ConfigMaps for downstream base URLs and Spring/Quarkus non-sensitive config (`spring.datasource.*`, `quarkus.datasource.*`).
  - Use Kubernetes Secrets (optionally sealed/external) for DB credentials and RabbitMQ secrets referenced in env vars.
  - Consider providing `values.yaml` placeholders for secret names so operators can inject existing credentials.

## Open Questions / Unknowns

- Resource requests/limits are not defined anywhere; should defaults be introduced per service or left for operators?
- No service account / RBAC needs surfaced in the code; should Helm create dedicated ServiceAccounts proactively?
- Metrics scraping currently via ServiceMonitor; should Helm chart automatically label Services for Prometheus Operator or rely on separate manifests?
