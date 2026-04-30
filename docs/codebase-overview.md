# Codebase Overview

## Executive Summary

AcmeCorp Platform is a runnable teaching and demonstration repository for a modern Java microservice system. It is intentionally broader than a sample application: the backend services, React UI, Docker Compose topology, Terraform stack, Helm chart, observability assets, benchmark harness, and course material all live in the same repository and are treated as part of the product.

The canonical runtime path is:

- local development through Docker Compose under `infra/local/`
- cloud infrastructure through Terraform under `infra/terraform/`
- Kubernetes packaging through the Helm chart under `helm/acmecorp-platform/`
- observability through Prometheus and Grafana

For detailed runbooks, use the linked canonical docs instead of treating this page as the only source of truth.

For the shorter repository and runtime mental model, use [system-map.md](system-map.md). This page is the fuller onboarding view for a senior engineer joining the project.

## Repository Purpose

This project exists to demonstrate:

- service boundaries in a Java microservice architecture
- mixed Spring Boot and Quarkus service development
- a local-to-cloud deployment path
- EKS-oriented infrastructure and Helm packaging
- Prometheus and Grafana observability
- benchmark-driven comparison across long-lived Java platform branches

This is a teaching and demo platform, not a generic production template. The repository preserves explicit implementations, explainable workflows, and course-facing assets even when a smaller or more abstract codebase would be possible.

Canonical references:

- [README.md](../README.md)
- [system-map.md](system-map.md)
- [branch-model.md](branch-model.md)

## System Architecture

### Main Services

| Service | Stack | Public API Base | Primary Responsibility | Main Dependencies |
| --- | --- | --- | --- | --- |
| `gateway-service` | Spring Boot WebFlux | `/api/gateway` | browser-facing API entry point and downstream proxy | backend services |
| `orders-service` | Spring Boot | `/api/orders` | order lifecycle and benchmark hot path | PostgreSQL/Aurora, catalog, billing, analytics, RabbitMQ/Amazon MQ |
| `catalog-service` | Quarkus | `/api/catalog` | product catalog CRUD | PostgreSQL/Aurora, Redis |
| `billing-service` | Spring Boot | `/api/billing` | invoice creation and payment flows | PostgreSQL/Aurora, analytics |
| `notification-service` | Spring Boot | `/api/notification` | notification enqueue, consume, retry, and deduplication | PostgreSQL/Aurora, RabbitMQ/Amazon MQ |
| `analytics-service` | Spring Boot | `/api/analytics` | event counters and analytics tracking | Redis; readiness also checks configured DB connectivity |

Concrete API/controller entry points:

- [services/spring-boot/gateway-service/src/main/java/com/acmecorp/gateway/api/GatewayController.java](../services/spring-boot/gateway-service/src/main/java/com/acmecorp/gateway/api/GatewayController.java)
- [services/spring-boot/orders-service/src/main/java/com/acmecorp/orders/api/OrdersController.java](../services/spring-boot/orders-service/src/main/java/com/acmecorp/orders/api/OrdersController.java)
- [services/quarkus/catalog-service/src/main/java/com/acmecorp/catalog/CatalogResource.java](../services/quarkus/catalog-service/src/main/java/com/acmecorp/catalog/CatalogResource.java)
- [services/spring-boot/billing-service/src/main/java/com/acmecorp/billing/api/BillingController.java](../services/spring-boot/billing-service/src/main/java/com/acmecorp/billing/api/BillingController.java)
- [services/spring-boot/notification-service/src/main/java/com/acmecorp/notification/api/NotificationController.java](../services/spring-boot/notification-service/src/main/java/com/acmecorp/notification/api/NotificationController.java)
- [services/spring-boot/analytics-service/src/main/java/com/acmecorp/analytics/api/AnalyticsController.java](../services/spring-boot/analytics-service/src/main/java/com/acmecorp/analytics/api/AnalyticsController.java)

### Service Boundaries

- `gateway-service` owns the browser-facing API and CORS boundary.
- backend services own their own persistence, API models, and operational endpoints.
- `orders-service` is the most connected backend service and drives confirmation, billing, analytics, and notification side effects.
- `catalog-service` is the Quarkus service and is intentionally distinct from the Spring Boot services.

### Request Flow

Deployed flow:

1. The browser loads static assets from the UI hostname served through CloudFront and S3.
2. The UI calls the gateway hostname.
3. The ALB-backed ingress routes traffic to `gateway-service`.
4. `gateway-service` proxies or aggregates calls to downstream services.
5. Backend services use Aurora, Redis, RabbitMQ, and Secrets Manager-backed credentials.

Local flow:

1. Vite serves the UI on `http://localhost:5173`.
2. The browser calls `http://localhost:8080`.
3. The gateway routes to backend containers on the Compose network.

Architecture references:

- [architecture/system-overview.md](architecture/system-overview.md)
- [system-map.md](system-map.md)

### Messaging And Event Flow

The repository has a direct RabbitMQ-backed notification flow:

- `orders-service` publishes order confirmation messages through `RabbitTemplate`
- `notification-service` consumes `notifications-queue`
- retry and dead-letter behavior are part of the notification path
- `notification-service` deduplicates processed messages before persisting them

Concrete code:

- [services/spring-boot/orders-service/src/main/java/com/acmecorp/orders/messaging/NotificationPublisher.java](../services/spring-boot/orders-service/src/main/java/com/acmecorp/orders/messaging/NotificationPublisher.java)
- [services/spring-boot/notification-service/src/main/java/com/acmecorp/notification/messaging/NotificationListener.java](../services/spring-boot/notification-service/src/main/java/com/acmecorp/notification/messaging/NotificationListener.java)
- [services/spring-boot/notification-service/src/main/java/com/acmecorp/notification/service/NotificationService.java](../services/spring-boot/notification-service/src/main/java/com/acmecorp/notification/service/NotificationService.java)

### Data Stores And Infrastructure Dependencies

- PostgreSQL locally, Aurora in AWS for relational persistence
- Redis for cache/counter support
- RabbitMQ locally, Amazon MQ in AWS for brokered messaging
- Secrets Manager for deployed secret storage
- ECR for image repositories
- EKS for workload execution
- Route 53, ACM, and ALB for public ingress
- S3 and CloudFront for UI hosting

## Local Development Model

### Docker Compose Topology

The supported local runtime is:

- [infra/local/docker-compose.yml](../infra/local/docker-compose.yml)
- optional observability overlay: [infra/local/docker-compose.observability.yml](../infra/local/docker-compose.observability.yml)

Main local stack contents:

- PostgreSQL
- Redis
- RabbitMQ
- `gateway-service`
- `orders-service`
- `billing-service`
- `notification-service`
- `analytics-service`
- `catalog-service`

### Important Ports

| Component | Address |
| --- | --- |
| UI | `http://localhost:5173` |
| Gateway | `http://localhost:8080` |
| Orders | `http://localhost:8081` |
| Billing | `http://localhost:8082` |
| Notification | `http://localhost:8083` |
| Analytics | `http://localhost:8084` |
| Catalog | `http://localhost:8085` |
| PostgreSQL | `localhost:5432` |
| Redis | `localhost:6379` |
| RabbitMQ | `localhost:5672` |
| RabbitMQ UI | `http://localhost:15672` |
| Prometheus overlay | `http://localhost:9090` |
| Grafana overlay | `http://localhost:3000` |
| Alertmanager overlay | `http://localhost:9093` |

### How Services Are Started Locally

```bash
cd infra/local
docker compose up -d --build
```

Wait for the stack:

```bash
bash ../../scripts/wait-for-compose-health.sh
```

Smoke-check the gateway path:

```bash
BASE_URL=http://localhost:8080 bash ../../scripts/smoke-local.sh
```

### How Observability Is Started Locally

```bash
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.observability.yml up --build
```

### How The UI Fits In

The UI is a separate Vite app under `webapp/`. It does not run inside the main Compose file.

```bash
cd webapp
npm ci
npm run dev
```

The local UI is configured to call the gateway on `http://localhost:8080`.

Canonical local docs:

- [development/local-setup.md](development/local-setup.md)
- [../infra/local/README.md](../infra/local/README.md)

## Cloud Deployment Model

### Terraform Responsibilities

The Terraform stack under `infra/terraform/` owns the AWS foundation:

- VPC and subnets
- EKS
- Aurora
- Amazon MQ
- Secrets Manager
- IAM and Pod Identity support
- ECR repositories
- ACM certificates
- Route 53 DNS
- S3 + CloudFront UI hosting

Terraform does not build application images and does not upload UI assets.

### Helm Responsibilities

The canonical Helm chart is [helm/acmecorp-platform](../helm/acmecorp-platform/README.md). It packages:

- application services
- Redis
- Prometheus
- Grafana
- External Secrets
- namespaces and network policies

### Kubernetes And EKS Topology

Canonical namespaces:

| Namespace | Main Contents |
| --- | --- |
| `acmecorp` | application services |
| `data` | Redis |
| `observability` | Prometheus and Grafana |
| `external-secrets` | External Secrets operator |

There is also a plain Kubernetes compatibility path under `infra/k8s/base/`, but the canonical cloud deployment path is Terraform + Helm on EKS.

### DNS, CloudFront, S3, ALB, ACM, And Route 53

- Route 53 provides the public hosted-zone records
- ACM provides gateway, Grafana, and UI certificates
- ALB-backed ingress fronts the gateway and Grafana in Kubernetes
- the UI is hosted separately through S3 and CloudFront
- the UI CloudFront certificate is created in `us-east-1` because CloudFront requires that region

Cloud deployment references:

- [deployment/terraform.md](deployment/terraform.md)
- [deployment/platform-deployment.md](deployment/platform-deployment.md)
- [deployment/ui-cloudfront.md](deployment/ui-cloudfront.md)
- [../infra/terraform/README.md](../infra/terraform/README.md)
- [../helm/acmecorp-platform/README.md](../helm/acmecorp-platform/README.md)

### Terraform-To-Helm Boundary Contract

The boundary is explicit:

1. Terraform produces infrastructure outputs.
2. `scripts/render-prod-values.sh` reads those outputs as the source of truth for the Terraform-to-Helm boundary contract.
3. The script renders `/tmp/acmecorp-values-prod.generated.yaml`.
4. Helm consumes the rendered values for deployment.

Boundary outputs currently exposed for this contract:

- `aws_region`
- `name_prefix`
- `app_namespace`
- `observability_namespace`
- `external_secrets_namespace`

Other rendered production values include:

- gateway and Grafana hosts
- gateway and Grafana certificate ARNs
- Aurora endpoint
- MQ host
- ECR repository URLs
- image tag
- UI CORS origin

Relevant files:

- [../infra/terraform/outputs.tf](../infra/terraform/outputs.tf)
- [../scripts/render-prod-values.sh](../scripts/render-prod-values.sh)
- [../helm/acmecorp-platform/values.yaml](../helm/acmecorp-platform/values.yaml)
- [../helm/acmecorp-platform/values-prod.yaml](../helm/acmecorp-platform/values-prod.yaml)

## Observability Model

The repository uses Prometheus and Grafana for metrics-based observability.

### Prometheus

- local Prometheus runs through the Compose observability overlay
- EKS Prometheus is packaged through the Helm chart
- infrastructure-side assets also live under `infra/observability/`

### Grafana

- local Grafana runs through the Compose observability overlay
- EKS Grafana is chart-managed in the `observability` namespace
- dashboard assets live under `infra/observability/grafana/`

### Metrics Endpoints

| Component Type | Metrics Endpoint |
| --- | --- |
| Spring Boot services | `/actuator/prometheus` |
| Quarkus catalog service | `/q/metrics` |

### Dashboards And Alerting

- dashboard JSON assets are stored in `infra/observability/grafana/`
- ServiceMonitor manifests are stored in `infra/observability/k8s/`
- local Alertmanager exists in the Compose overlay
- this repository does not currently implement a full OpenTelemetry pipeline

### What Operators Should Look At First

- service health endpoints
- Prometheus target status
- Grafana dashboards for JVM and HTTP behavior
- gateway and backend service logs
- `kubectl get pods` in `acmecorp` and `observability` for cloud deployments

Canonical references:

- [operations/observability.md](operations/observability.md)
- [../infra/observability/README.md](../infra/observability/README.md)

## Configuration Model

### Where Defaults Live

- local defaults: `infra/local/docker-compose.yml`
- Terraform inputs/defaults: `infra/terraform/variables.tf`
- Terraform outputs: `infra/terraform/outputs.tf`
- shared Helm defaults: `helm/acmecorp-platform/values.yaml`
- production baseline before rendering: `helm/acmecorp-platform/values-prod.yaml`
- frontend environment files: `webapp/.env.development`, `webapp/.env.production`

### Which Values Are Intentionally Hardcoded

Some values remain as stable project defaults or provider-driven assumptions:

- namespace defaults such as `acmecorp`, `data`, `observability`, and `external-secrets`
- example ingress hosts under `acmecorp.example.com`
- local Compose credentials `acmecorp` / `acmecorp`
- the `us-east-1` UI certificate region requirement for CloudFront
- baseline storage class and image defaults in the chart

### Which Values Are Rendered From Terraform Outputs

The production render step currently writes or verifies:

- `global.awsRegion`
- `global.secretsNamePrefix`
- Aurora host
- MQ host
- gateway ingress host
- Grafana ingress host
- gateway and Grafana ACM certificate ARNs
- ECR image repositories
- image tags
- gateway UI CORS origin

### Which Values Must Not Drift Between Terraform And Helm

- Terraform `name_prefix` and Helm `global.secretsNamePrefix`
- namespace assumptions used across Terraform, External Secrets, and Helm
- Route 53 hostnames and Helm ingress hosts
- ACM outputs and ingress certificate annotations
- ECR repository URLs and rendered image references
- UI hostname and gateway CORS origin

Reference docs:

- [reference/configuration.md](reference/configuration.md)
- [../infra/terraform/README.md](../infra/terraform/README.md)
- [../helm/acmecorp-platform/README.md](../helm/acmecorp-platform/README.md)

## Benchmarking Model

The benchmark harness lives under `bench/` and measures the runnable local platform, not only isolated JVM behavior.

Main scripts:

- `bench/run-once.sh`
- `bench/run-matrix.sh`
- `bench/run-java21-vs-java25.sh`
- `bench/run-episode07-refresh.sh`

What the harness measures:

- platform readiness/startup timing
- `orders-service` startup milestones from `/api/orders/startup`
- gateway-facing throughput and latency
- container RSS snapshots

Branch comparison model:

- most branch comparisons are maintained-platform comparisons
- `java21` versus `java25` is not automatically a pure JVM-only comparison
- experiment branches such as `cds`, `crac`, and `graalvm` are separate experiment lines

Canonical docs:

- [benchmarking.md](benchmarking.md)
- [branch-model.md](branch-model.md)
- [../bench/README.md](../bench/README.md)

## Important Directories

| Directory | Purpose |
| --- | --- |
| `services/` | backend service code, split between Spring Boot and Quarkus |
| `infra/` | local Compose assets, Terraform stack, plain Kubernetes compatibility manifests, and observability assets |
| `helm/` | canonical Helm packaging for the EKS deployment path |
| `scripts/` | operational helpers for deploy, validation, smoke, teardown, and branch maintenance |
| `bench/` | benchmark harness and result layout |
| `docs/` | canonical operational docs plus historical and course material |
| `webapp/` | React + Vite frontend |

## Operational Workflows

### Local Startup

```bash
cd infra/local
docker compose up -d --build
bash ../../scripts/wait-for-compose-health.sh
```

Then:

```bash
BASE_URL=http://localhost:8080 bash ../../scripts/smoke-local.sh
cd ../../webapp
npm ci
npm run dev
```

### Production Setup

```bash
terraform -chdir=infra/terraform init
terraform -chdir=infra/terraform apply
scripts/bootstrap-first-cluster.sh
IMAGE_TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)" scripts/build-and-push-ecr.sh
IMAGE_TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)" scripts/render-prod-values.sh /tmp/acmecorp-values-prod.generated.yaml
helm upgrade --install acmecorp-platform helm/acmecorp-platform -n acmecorp -f /tmp/acmecorp-values-prod.generated.yaml
```

### UI Deployment

Verified helper:

```bash
scripts/deploy-ui.sh
```

### Observability Deployment

- local: add `infra/local/docker-compose.observability.yml`
- cloud: Prometheus and Grafana are included in the Helm release

### Destroy And Cleanup

- Terraform destroy is intentionally guarded by documentation and helper scripts
- teardown helper exists: `scripts/destroy-acmecorp-aws-resources.sh`
- secret and KMS lifecycle recovery helpers also exist

### Common Troubleshooting Entry Points

- [operations/troubleshooting.md](operations/troubleshooting.md)
- `scripts/validate-deploy.sh`
- `scripts/verify-first-deploy.sh`
- `scripts/restore-secrets-if-pending-deletion.sh`

## Sanity Checklist

### Before Deploying

- confirm Terraform outputs are from the intended state and environment
- build and push images before rendering values for Helm
- treat `/tmp/acmecorp-values-prod.generated.yaml` as rendered values from the boundary contract, not a hand-edited file

### Before Benchmarking

- confirm which branch you are benchmarking and describe results as platform-branch results unless the harness isolates only the JVM
- keep warmup, duration, concurrency, and run counts consistent across compared branches
- cite `summary.md`, `load.json`, `containers.json`, and `orders-startup.json` instead of older artifact names

### Before Changing Infra

- review the Terraform-to-Helm boundary contract before changing outputs, namespaces, ingress hosts, or secret-prefix behavior
- update this document if `scripts/render-prod-values.sh`, `infra/terraform/outputs.tf`, or `helm/acmecorp-platform/values.yaml` changes the contract
- validate with `terraform fmt -check`, `helm template`, and relevant script syntax checks before merging

## Automated Validation And Drift Detection

Use the lightweight validation helpers before opening a PR or before running a deployment workflow:

- `scripts/validate-repo.sh`: repo-wide best-effort validation for shell syntax, Terraform formatting, Helm rendering, and boundary checks
- `scripts/validate-boundary-contract.sh`: read-only validation of the Terraform-to-Helm boundary contract against a rendered values file
- `.github/workflows/repo-validation.yml`: CI wiring for the same lightweight repository validation on pull requests and pushes to `main`

Typical usage:

```bash
scripts/validate-repo.sh
scripts/validate-boundary-contract.sh /tmp/acmecorp-values-prod.generated.yaml
```

These checks are intentionally lightweight. They help catch drift early, but they do not replace review of Terraform state, rendered values, or branch-specific benchmark assumptions.

In CI, this validation currently covers repo shape, shell syntax, Terraform formatting, and Helm rendering. Full rendered Terraform-to-Helm boundary alignment still requires a rendered production values file and remains best-effort/local unless such a file is present.

## Risks And Gotchas

- DNS drift: Terraform-managed hostnames and Helm ingress values must stay aligned.
- Rendered Helm values drift: treat `scripts/render-prod-values.sh` as the boundary contract instead of editing generated values by hand.
- Namespace assumptions: Terraform, Helm, and External Secrets depend on coordinated namespace names.
- Secret-prefix assumptions: Terraform `name_prefix` and Helm `global.secretsNamePrefix` must stay aligned.
- Image tag and ECR mismatch: image build/push and Helm render/deploy must use the same tag set.
- Terraform provider availability: local validation may fail if providers are not initialized or cached.
- Benchmark branch drift: branch benchmarks are platform comparisons unless the harness proves stronger isolation.
- `main` is the canonical docs/integration branch, not a promise of exact runtime parity with `java21`.

## What To Read First

- [README.md](../README.md)
- [system-map.md](system-map.md)
- [architecture/system-overview.md](architecture/system-overview.md)
- [development/local-setup.md](development/local-setup.md)
- [deployment/platform-deployment.md](deployment/platform-deployment.md)
- [branch-model.md](branch-model.md)

## What To Run First

```bash
cd infra/local
docker compose up -d --build
bash ../../scripts/wait-for-compose-health.sh
```

Then:

```bash
BASE_URL=http://localhost:8080 bash ../../scripts/smoke-local.sh
cd ../../webapp
npm ci
npm run dev
```

## What To Be Careful With

- Do not assume the plain Kubernetes manifests under `infra/k8s/base/` reflect the canonical AWS/EKS deployment path.
- Do not treat branch comparisons as pure JVM conclusions unless the benchmark setup explicitly isolates only the JVM.
- Do not hand-edit rendered production values.
- Do not assume `main` is the clean Java baseline branch; use [branch-model.md](branch-model.md).
- Do not treat this repository as a generic production template; it intentionally preserves teaching and demonstration concerns alongside runnable software.
