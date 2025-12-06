## AcmeCorp Platform – Current Architecture (Implementation Snapshot)

### Overview

The AcmeCorp platform is a microservices-based demo application used to illustrate modern Java, container, and Kubernetes patterns (including EKS Auto Mode). It consists of:

- Six backend services (Spring Boot + Quarkus)
- A Vite/React/TypeScript single-page application
- Backing infrastructure (Postgres, Redis, RabbitMQ)
- Local Docker Compose setup
- Kubernetes base manifests (Kustomize-ready)
- A single Helm chart packaging all components

All services expose `/status` endpoints, use health/actuator probes, and are wired for both local and Kubernetes deployments.

---

### Backend Services

**Spring Boot services**

- **orders-service**
  - Responsibility: Owns the order lifecycle (create, list, detail, latest orders).
  - Interfaces:
    - REST endpoints for listing and inspecting orders.
    - `/status` health endpoint.
  - Data: Uses Postgres; configuration externalized via env vars (DB host/port/name/credentials).

- **billing-service**
  - Responsibility: Billing, invoices, and payment-related operations.
  - Interfaces:
    - REST endpoints for billing workflows.
    - `/status` health endpoint.
  - Data: Uses Postgres and RabbitMQ for messaging (both externalized via env vars).

- **notification-service**
  - Responsibility: Outbound notifications (e.g., email/queue-based notifications).
  - Interfaces:
    - REST endpoints to trigger or inspect notifications.
    - `/status` health endpoint.
  - Data: Uses RabbitMQ and/or Redis for message handling and caching.

- **analytics-service**
  - Responsibility: Aggregates counters and KPIs across the platform.
  - Interfaces:
    - `/api/analytics/counters` (via gateway) for dashboards.
    - `/status` health endpoint.
  - Data: Reads from Postgres/Redis; configuration driven by env vars.

- **gateway-service**
  - Responsibility: Acts as the single façade for the frontend.
  - Interfaces:
    - Proxies and aggregates calls to downstream services, including:
      - Orders and catalog operations.
      - Analytics counters.
      - Aggregated system status.
    - Key routes:
      - `GET /api/gateway/analytics/counters`
      - `GET /api/gateway/system/status`
      - Existing orders/catalog endpoints (list/detail/latest).
  - Config:
    - Downstream base URLs configured via `application.yml` and env vars.

**Quarkus service**

- **catalog-service (Quarkus)**
  - Responsibility: Product catalog with CRUD operations.
  - Tech:
    - Quarkus with Panache.
    - Seeds initial catalog data at startup.
  - Data:
    - Uses Postgres via JDBC URL, externalized through env vars.
  - Health:
    - Standard Quarkus metrics and health endpoints.

---

### Frontend (webapp)

- **Stack**: Vite + React + TypeScript SPA.
- **Structure**:
  - `src/api` – API clients (now aligned with gateway routes).
  - `src/views` – Pages for:
    - Dashboard
    - Orders
    - Catalog
    - Analytics
    - System Status
  - `src/components`, `src/styles` – Shared UI components and theme.

- **Backend integration**:
  - Uses `VITE_API_BASE_URL` to find the gateway:
    - Local dev: typically `http://localhost:8080`.
    - K8s/Ingress: e.g. `https://acmecorp.local/api`.
  - **Analytics view**:
    - Calls `GET /api/gateway/analytics/counters`.
    - Uses real KPIs with a graceful mock fallback (for demo robustness).
  - **System status view**:
    - Calls `GET /api/gateway/system/status`, which aggregates service `/status` endpoints behind the gateway.

---

### Backing Infrastructure

The platform uses three shared services:

- **Postgres**
  - Used by orders, billing, analytics, and catalog.
  - Provided in:
    - `infra/local/docker-compose.yml` (for local dev).
    - `infra/k8s/base` (plain K8s Deployments/Services).
    - `charts/acmecorp-platform` (Helm-managed Deployment/Service).
  - Credentials:
    - Demo defaults stored in a ConfigMap/Secret combination in Helm.
    - Overrideable via `values.yaml`.

- **Redis**
  - Used for caching / ephemeral data.
  - Deployed alongside the other services in both base K8s and Helm.
  - Configuration:
    - Host/port and optional password externalized via env vars and ConfigMaps/Secrets.

- **RabbitMQ**
  - Used for messaging (billing, notifications, potentially analytics).
  - Deployed as a separate Deployment/Service in base K8s and Helm.
  - Credentials:
    - Demo defaults via Secret; wired into services via env vars.

All three backing services have TCP-based liveness/readiness probes in the base K8s manifests to improve resilience in clusters.

---

### Deployment Topology

- **Local development**
  - `infra/local/docker-compose.yml` starts:
    - All Spring Boot + Quarkus services.
    - Postgres, Redis, RabbitMQ.
    - The platform is reachable via the gateway on `http://localhost:8080`.
  - The webapp runs via:
    - `npm run dev` (default Vite dev server), with `VITE_API_BASE_URL` pointing to the gateway.

- **Kubernetes base (Kustomize)**
  - `infra/k8s/base` contains:
    - Deployments and Services for all six application services.
    - Deployments and Services for Postgres, Redis, and RabbitMQ.
    - Liveness/readiness probes for the infra services.
  - Intended for:
    - Simple “plain YAML” demos.
    - Comparing raw manifests vs Helm/EKS Auto Mode deployments.

- **Helm chart**
  - `charts/acmecorp-platform` bundles:
    - All six services.
    - Postgres, Redis, RabbitMQ.
  - `values.yaml` controls:
    - Images and resources.
    - DB/Redis/RabbitMQ endpoints and credentials (via ConfigMaps/Secrets).
    - Gateway configuration.
  - This chart is the primary entry point for:
    - EKS / EKS Auto Mode demos.
    - Parameterizing the platform for different environments.

---

### Configuration & Credentials

- **Application configuration**
  - Spring Boot and Quarkus configs use placeholders that can be overridden by env vars.
  - Docker Compose continues to work with default values (service-name hostnames).

- **Helm configuration**
  - Credentials for Postgres and RabbitMQ are:
    - Defined in `values.yaml`.
    - Projected into Secrets referenced by the respective Deployments.
  - Non-sensitive config (database name, hostnames, ports) lives in ConfigMaps or `values.yaml`.
  - All demo credentials are overrideable via Helm values.

---

### Observability (Skeleton)

- An observability skeleton exists (ServiceMonitors and Grafana dashboard definitions).
- Full Prometheus setup is expected to be provided by an external monitoring stack (e.g., a separate Helm release or platform-wide Prometheus/Grafana installation).
- The current focus is:
  - Make all services “scrapable” and observable.
  - Provide a basis for future deep-dive episodes on JVM metrics, tracing, and EKS Auto Mode behavior.
