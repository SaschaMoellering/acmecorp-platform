# AcmeCorp Platform

AcmeCorp Platform is a cloud-native demo built as a learning ground for JVM + modern infra projects: it ties together Spring Boot, Quarkus, React, Docker Compose, Helm/EKS, observing tools, and benchmarking around performance regressions (Hibernate N+1, Java 11/17/21/25). The repo exists to power deep-dive videos that cover architecture, observability, DevOps automation, and the performance implications of each stack layer.

## What’s inside

- **Gateway** – Spring WebFlux entrypoint (`gateway-service`) that routes `/api/gateway/*` traffic to downstream services.
- **Orders, Billing, Notification, Analytics** – Spring Boot microservices backed by Postgres, RabbitMQ, and Redis.
- **Catalog** – Quarkus-based catalog service (optional) consumed by the webapp and gateway.
- **Webapp** – React + Vite SPA (`webapp/`) wired to the gateway via `VITE_API_BASE_URL` with full notification UI integration.
- **Observability & monitoring** – `infra/observability/` contains Grafana dashboards (`grafana/`) and Kubernetes ServiceMonitors (`k8s/`) for Prometheus integration.

## Repository layout

```
services/                   # Java + Quarkus service sources
infra/local/docker-compose.yml  # local stack (Postgres, Redis, RabbitMQ, services)
infra/k8s/base/             # Kubernetes manifests with security policies
infra/terraform/            # AWS infrastructure (VPC, EKS, Aurora, S3/CloudFront)
helm/acmecorp-platform/     # backend Helm umbrella chart (gateway, orders, catalog)
scripts/                    # automation scripts (k3d setup, validation, deployment)
bench/                      # benchmarking harness + scripts
webapp/                     # React + Vite single-page app
docs/                       # supplementary guides (AWS, benchmarking, etc.)
```

## Quick start (Local)

```bash
cd infra/local
docker compose up -d --build
```

- Check gateway health: `curl http://localhost:8080/api/gateway/status`
- View system status: `curl http://localhost:8080/api/gateway/system/status`
- Check analytics: `curl http://localhost:8080/api/gateway/analytics/counters`
- Browse catalog: `curl http://localhost:8085/api/catalog/products`
- Create test order: `curl -X POST http://localhost:8080/api/gateway/orders -H "Content-Type: application/json" -d '{"customerId": 1, "customerEmail": "test@example.com", "items": [{"productId": 1, "quantity": 2}]}'`
- Teardown: `docker compose down --volumes`

The webapp defaults to `VITE_API_BASE_URL=http://localhost:8080`; run `npm install && npm run dev` inside `webapp/`.

## Kubernetes deployment

See `helm/README.md` for install/upgrade guidance.

```bash
kubectl create namespace acmecorp
helm upgrade --install acmecorp helm/acmecorp-platform -n acmecorp -f helm/acmecorp-platform/values-prod.yaml
```

- Helm deploys **only the backend** services; the React SPA stays on S3/CloudFront (Terraform-managed).
- Ingress is handled via AWS Load Balancer Controller (ALB) when `ingress.enabled=true`.
- ServiceMonitors are optional; enable `prometheus.serviceMonitor.enabled=true` per subchart when running kube-prometheus-stack.
- **Security**: Network policies, resource quotas, and pod disruption budgets included for production readiness.

## Java versions & performance benchmarking

Branches follow the Java matrix in `VERSION_MATRIX.md`: `main` is Java 21, while `java11`, `java17`, `java21`, `java25` are configuration-only variants that swap JDK/JRE images/toolchains (no Aurora or docs changes). Benchmarks run via the `bench/` scripts:

```bash
./bench/run-once.sh      # capture startup + median RSS for current branch
./bench/run-matrix.sh    # iterate java11/java17/java21/main/java25
```

The harness expects Docker Compose v2 (or `docker-compose` as fallback) and records memory snapshots at T0/T+30s/T+60s to reduce sampling noise.

## Notification System

**RabbitMQ-based messaging** between Orders and Notification services:

- **Message Flow**: Orders Service → RabbitMQ → Notification Service → Database
- **Message Flow**: Billing Service → RabbitMQ → Notification Service → Database
- **UI Integration**: React frontend displays notifications via Gateway API (`/api/gateway/notifications`)
- **Invoice Management**: React frontend manages invoices via Gateway API (`/api/gateway/billing/invoices`)
- **Message Types**: Order confirmations, invoice payments, generic messages
- **Frontend Features**: Real-time notification list with status badges and filtering, invoice payment interface

**Test the system**:
```bash
# Create order
curl -X POST http://localhost:8080/api/gateway/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId": 1, "customerEmail": "test@example.com", "items": [{"productId": 1, "quantity": 2}]}'

# Confirm order to trigger notification (replace {id} with order ID from response)
curl -X POST http://localhost:8080/api/gateway/orders/{id}/confirm

# Pay invoice to trigger payment notification (replace {invoice_id} with invoice ID)
curl -X POST http://localhost:8080/api/gateway/billing/invoices/{invoice_id}/pay \
  -H "Content-Type: application/json" \
  -d '{"paymentMethod": "DEMO"}'

# View notifications in UI
# Navigate to "Notifications" in webapp sidebar
# Navigate to "Invoices" in webapp sidebar
```

## Performance demo: Hibernate N+1

- Path vs fix: `GET /api/orders/demo/nplus1` exercises the naive per-row item fetch; `listOrders`/`latestOrders` call `preloadItems(...)` which batches with `OrderRepository.findAllWithItemsByIds(ids)` to avoid the 1+N queries.
- Regression guard: `OrderServiceQueryCountTest` seeds 10 orders × 5 items, enables `hibernate.generate_statistics`, and asserts the optimized path issues ≤3 SQL statements. Run it via:

```bash
cd services/spring-boot/orders-service
mvn test -Dtest=OrderServiceQueryCountTest
```

## AWS deployment overview

- **Infrastructure**: Terraform modules in `infra/terraform/` for VPC, EKS Auto Mode, Aurora, S3/CloudFront
- **Backend**: deployed to EKS via `helm/acmecorp-platform`.
- **Frontend**: hosted on S3 (optionally fronted by CloudFront) with `VITE_API_BASE_URL` pointing to the gateway.
- **Database**: Aurora PostgreSQL with IAM authentication (shared via `infra/local/docker-compose` for local dev).
- **Cache**: Redis for session management, rate limiting, and application caching (ElastiCache in production).

### Aurora IAM auth + EKS Pod Identity

See `docs/aws/aurora-iam-auth.md` for enablement. In short:

- Enable IAM DB authentication and grant `rds_iam` to the target user.
- Apply the IAM policy in `docs/aws/iam/policy-rds-db-connect.json` (fill in account/region/resource/user).
- Create IAMRoleBindings (`docs/aws/pod-identity/*.yaml`) to associate Pod service accounts with the IAM role that has `rds-db:connect`.
- When IAM auth is active, set env vars `ACMECORP_PG_IAM_AUTH=true`, `ACMECORP_PG_HOST`, `ACMECORP_PG_PORT`, `ACMECORP_PG_DB`, `ACMECORP_PG_USER`, and `AWS_REGION`; the services generate short-lived tokens (orders: 9m max lifetime, catalog similar).

## Scripts

- `scripts/validate-k8s.sh` - Validate Kubernetes manifests
- `scripts/push-images.sh` - Build container images
- `scripts/smoke-local.sh` - Local smoke tests
- `scripts/test-redis-local.sh` - Test Redis integration locally
- `scripts/test-redis-units.sh` - Run Redis unit tests

## Docs index

- [`infra/terraform/README.md`](infra/terraform/README.md) - AWS infrastructure deployment
- [`docs/aws/aurora-iam-auth.md`](docs/aws/aurora-iam-auth.md) - Aurora PostgreSQL IAM authentication
- [`docs/notification-system.md`](docs/notification-system.md) - RabbitMQ messaging and UI integration
- [`docs/redis-testing-guide.md`](docs/redis-testing-guide.md) - Redis integration testing
- [`docs/getting-started.md`](docs/getting-started.md) - Platform setup guide
- [`docs/kubernetes-deployment.md`](docs/kubernetes-deployment.md) - Production Kubernetes deployment guide
- [`docs/testing-guide.md`](docs/testing-guide.md) - Comprehensive testing guide
- [`docs/app-architecture-and-branches.md`](docs/app-architecture-and-branches.md) - Application architecture overview
- [`services/spring-boot/orders-service/README.md`](services/spring-boot/orders-service/README.md) - Orders service IAM auth
- [`helm/README.md`](helm/README.md) - Kubernetes deployment
- [`bench/README.md`](bench/README.md) - Performance benchmarking
- [`VERSION_MATRIX.md`](VERSION_MATRIX.md) - Java version matrix

## License / Contributing

No formal `LICENSE`/`CONTRIBUTING.md` is included; coordinate with the AcmeCorp maintainers before extending or sharing this code.
