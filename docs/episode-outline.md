# AcmeCorp Engineering Series – Season 1 Outline

This guide maps the episode lineup to the current AcmeCorp Platform repository. Each episode is scoped to ~10 minutes. Status reflects repository implementation.

## Episode 1 — AcmeCorp Platform Overview & Architecture (10 min)

Purpose: Establish the platform domain, architecture, and tech stack.

Key topics:
- Platform purpose as a JVM + modern infra reference stack
- Domain services: gateway, orders, billing, notification, analytics, catalog
- High-level request flow through the gateway to downstream services
- Tech stack inventory (Spring Boot, Quarkus, React, Docker Compose, Helm)
- Repository layout for services, infra, Helm, benchmarks, and docs

Status: implemented

Repo anchors:
- `README.md`
- `docs/app-architecture-and-branches.md`
- `services/`

## Episode 2 — Local Development & Docker Compose (10 min)

Purpose: Show how the platform runs locally and how services depend on each other.

Key topics:
- Docker Compose stack and service topology
- Local dependencies: PostgreSQL, Redis, RabbitMQ
- Service profiles and environment variables for local runs
- Gateway health and system status endpoints for verification
- Smoke testing workflow for local validation

Status: implemented

Repo anchors:
- `infra/local/docker-compose.yml`
- `scripts/smoke-local.sh`
- `docs/getting-started.md`
- `README.md`

## Episode 3 — API Design, Gateway & Service Boundaries (10 min)

Purpose: Explain how the gateway exposes APIs and isolates internal services.

Key topics:
- Spring WebFlux gateway as the single public entrypoint
- `/api/gateway/*` routing patterns and downstream delegation
- Service boundary rationale (only gateway exposed externally)
- Request aggregation for orders, catalog, billing, notifications, analytics
- System status endpoint for multi-service health visibility

Status: implemented

Repo anchors:
- `services/spring-boot/gateway-service`
- `docs/app-architecture-and-branches.md`
- `README.md`

## Episode 4 — Kubernetes & Helm Deployment (10 min)

Purpose: Move from local to Kubernetes using the Helm umbrella chart.

Key topics:
- Umbrella Helm chart structure (gateway, orders, catalog)
- Values files and environment separation (dev/prod)
- Gateway ingress configuration (ALB-ready)
- Backend-only Helm deployment (frontend handled elsewhere)
- Base Kubernetes manifests for network policies and PDBs

Status: implemented

Repo anchors:
- `helm/README.md`
- `helm/acmecorp-platform/`
- `infra/k8s/base/`

## Episode 5 — Observability: Metrics, Health & Prometheus (10 min)

Purpose: Demonstrate observability and how to monitor the platform.

Key topics:
- Spring Boot Actuator endpoints for health and metrics
- ServiceMonitors for Prometheus scraping
- Grafana JVM/HTTP dashboard usage
- Optional Helm serviceMonitor enablement per chart
- What to monitor first in production deployments

Status: implemented

Repo anchors:
- `infra/observability/k8s/`
- `infra/observability/grafana/acmecorp-jvm-http-overview.json`
- `helm/acmecorp-platform/values.yaml`

## Episode 6 — Performance Pitfalls: Hibernate N+1 Problem (10 min)

Purpose: Show a real performance issue and the repo-backed regression test.

Key topics:
- N+1 query pattern in orders data access
- Demo endpoint: `/api/orders/demo/nplus1`
- Optimized query path with batched item loading
- Hibernate statistics-based regression test
- Why query count caps matter in production

Status: implemented

Repo anchors:
- `services/spring-boot/orders-service/src/main/java/com/acmecorp/orders/api/OrdersController.java`
- `services/spring-boot/orders-service/src/test/java/com/acmecorp/orders/service/OrderServiceQueryCountTest.java`
- `README.md`

## Episode 7 — Java in Containers: Native Images & CRaC (10 min)

Purpose: Explore JVM startup and memory optimization strategies.

Key topics:
- Native images (GraalVM/Mandrel) vs JVM tradeoffs
- CRaC (Checkpoint/Restore at Runtime) basics
- AppCDS/AOT options for startup tuning
- Container startup and memory profile considerations
- Candidate integration points in the AcmeCorp services

Status: planned

## Episode 8 — Cloud Deployment Strategy (AWS) (10 min)

Purpose: Explain the AWS deployment topology and infrastructure modules.

Key topics:
- Terraform modules for VPC and EKS Auto Mode
- Frontend hosting on S3 with CloudFront
- Gateway ingress via AWS Load Balancer Controller (ALB)
- Environment separation under `infra/terraform/environments`
- Cost and operational considerations (budgets, logging, optimization)

Status: implemented

Repo anchors:
- `infra/terraform/README.md`
- `infra/terraform/`
- `helm/acmecorp-platform/values-prod.yaml`

## Episode 9 — Java Performance Baseline: Java 11 vs Java 17 (10 min)

Purpose: Establish a historical JVM baseline using the repo’s Java matrix.

Key topics:
- Version matrix policy and allowed configuration diffs
- Branch-based JVM swaps (build/runtime images)
- Startup time and RSS capture via benchmark harness
- Throughput and latency capture via load tests
- Parity validation: no business-logic changes across branches

Status: implemented

Repo anchors:
- `VERSION_MATRIX.md`
- `bench/run-matrix.sh`
- `bench/README.md`

## Episode 10 — Modern JVMs: Java 17 vs Java 21 (10 min)

Purpose: Validate Java 21 as the platform baseline using the same harness.

Key topics:
- Branch comparison: `java17` vs `java21`/`main`
- Identical application logic with version-only deltas
- Startup and memory measurements captured by scripts
- Load test metrics (throughput and latency percentiles)
- Criteria for choosing Java 21 as the baseline branch

Status: implemented

Repo anchors:
- `VERSION_MATRIX.md`
- `bench/run-matrix.sh`
- `bench/README.md`

## Episode 11 — Cutting Edge JVMs: Java 21 vs Java 25 (10 min)

Purpose: Evaluate the experimental Java 25 branch with controlled benchmarks.

Key topics:
- Java 25 branch policy and image selection notes
- Startup time and memory comparison against Java 21
- Load test metrics to compare tail latency behavior
- Risk/benefit framing for bleeding-edge upgrades
- How the matrix captures differences without code changes

Status: implemented

Repo anchors:
- `VERSION_MATRIX.md`
- `bench/run-matrix.sh`
- `bench/README.md`

## Episode 12 — Secure Data Plane: Aurora PostgreSQL IAM Auth (10 min)

Purpose: Implement IAM-based database authentication with Pod Identity.

Key topics:
- Aurora PostgreSQL IAM auth enablement
- `rds-db:connect` policy and IAM user setup
- EKS Pod Identity association for service accounts
- IAM auth env vars (`ACMECORP_PG_IAM_AUTH`, host, user, region)
- Orders and catalog service configuration alignment

Status: implemented

Repo anchors:
- `docs/aws/aurora-iam-auth.md`
- `services/spring-boot/orders-service/README.md`
- `helm/README.md`

## Episode 13 — Asynchronous Messaging with RabbitMQ (10 min)

Purpose: Walk through the event-driven notification pipeline.

Key topics:
- Orders and billing services publishing notifications
- Notification service consuming and persisting messages
- RabbitMQ in the local Docker Compose stack
- Gateway routing for notifications and invoices
- Webapp notifications and invoice payment UI

Status: implemented

Repo anchors:
- `docs/notification-system.md`
- `infra/local/docker-compose.yml`
- `services/spring-boot/orders-service/src/main/java/com/acmecorp/orders/messaging/NotificationPublisher.java`
- `services/spring-boot/notification-service/src/main/java/com/acmecorp/notification/messaging/NotificationListener.java`
- `webapp/src/views/Notifications.tsx`
- `webapp/src/components/Invoices.tsx`

## Episode 14 — AI in the Platform (10 min)

Purpose: Describe where AI could augment platform operations and development.

Key topics:
- AI-assisted diagnostics and alert triage
- Log/trace summarization and anomaly detection concepts
- Performance regression analysis workflows
- Developer productivity and automation ideas
- Integration boundaries and non-goals

Status: planned

## Episode 15 — Benchmarking & Performance Methodology (10 min)

Purpose: Make performance comparisons reproducible and credible.

Key topics:
- Benchmark harness structure and outputs
- Warmup vs measurement and load generation flow
- Fixed container resource limits for fair comparisons
- Per-branch results and matrix summaries
- How benchmark artifacts are stored and reviewed

Status: implemented

Repo anchors:
- `bench/README.md`
- `bench/run-once.sh`
- `bench/run-matrix.sh`
- `infra/local/docker-compose.yml`
- `VERSION_MATRIX.md`
