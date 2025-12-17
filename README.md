# AcmeCorp Platform

AcmeCorp Platform is a cloud-native demo built as a learning ground for JVM + modern infra projects: it ties together Spring Boot, Quarkus, React, Docker Compose, Helm/EKS, observing tools, and benchmarking around performance regressions (Hibernate N+1, Java 11/17/21/25). The repo exists to power deep-dive videos that cover architecture, observability, DevOps automation, and the performance implications of each stack layer.

## What’s inside

- **Gateway** – Spring WebFlux entrypoint (`gateway-service`) that routes `/api/gateway/*` traffic to downstream services.
- **Orders, Billing, Notification, Analytics** – Spring Boot microservices backed by Postgres, RabbitMQ, and Redis.
- **Catalog** – Quarkus-based catalog service (optional) consumed by the webapp and gateway.
- **Webapp** – React + Vite SPA (`webapp/`) wired to the gateway via `VITE_API_BASE_URL`.
- **Observability & monitoring** – `infra/observability/` contains Grafana dashboards (`grafana/`) and Kubernetes ServiceMonitors (`k8s/`) for Prometheus integration.

## Repository layout

```
services/                   # Java + Quarkus service sources
infra/local/docker-compose.yml  # local stack (Postgres, Redis, RabbitMQ, services)
infra/terraform/            # AWS infrastructure (VPC, EKS, Aurora, S3/CloudFront)
helm/acmecorp-platform/     # backend Helm umbrella chart (gateway, orders, catalog)
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
- Seed deterministic data: `curl -X POST http://localhost:8080/api/gateway/seed`
- Teardown: `docker compose down --volumes`

The webapp defaults to `VITE_API_BASE_URL=http://localhost:8080`; run `npm install && npm run dev` inside `webapp/`.

## Kubernetes deployment (Helm)

See `helm/README.md` for install/upgrade guidance.

```bash
kubectl create namespace acmecorp
helm upgrade --install acmecorp helm/acmecorp-platform -n acmecorp -f helm/acmecorp-platform/values-prod.yaml
```

- Helm deploys **only the backend** services; the React SPA stays on S3/CloudFront (Terraform-managed).
- Ingress is handled via AWS Load Balancer Controller (ALB) when `ingress.enabled=true`.
- ServiceMonitors are optional; enable `prometheus.serviceMonitor.enabled=true` per subchart when running kube-prometheus-stack.

## Java versions & performance benchmarking

Branches follow the Java matrix in `VERSION_MATRIX.md`: `main` is Java 21, while `java11`, `java17`, `java21`, `java25` are configuration-only variants that swap JDK/JRE images/toolchains (no Aurora or docs changes). Benchmarks run via the `bench/` scripts:

```bash
./bench/run-once.sh      # capture startup + median RSS for current branch
./bench/run-matrix.sh    # iterate java11/java17/java21/main/java25
```

The harness expects Docker Compose v2 (or `docker-compose` as fallback) and records memory snapshots at T0/T+30s/T+60s to reduce sampling noise.

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

## Docs index

- [`infra/terraform/README.md`](infra/terraform/README.md) - AWS infrastructure deployment
- [`docs/aws/aurora-iam-auth.md`](docs/aws/aurora-iam-auth.md)
- [`helm/README.md`](helm/README.md)
- [`bench/README.md`](bench/README.md)
- [`VERSION_MATRIX.md`](VERSION_MATRIX.md)

## License / Contributing

No formal `LICENSE`/`CONTRIBUTING.md` is included; coordinate with the AcmeCorp maintainers before extending or sharing this code.
