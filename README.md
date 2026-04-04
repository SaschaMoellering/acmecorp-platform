# AcmeCorp Platform

AcmeCorp Platform is a cloud-native reference system for learning, building, and operating a modern Java microservice platform on local Docker Compose and AWS.

It combines:
- Spring Boot and Quarkus services
- a React + Vite UI
- Terraform-managed AWS infrastructure
- Helm-managed Kubernetes workloads on EKS
- Prometheus and Grafana observability
- GitHub Actions CI/CD, including UI deployment to S3 + CloudFront

## Architecture Summary

At runtime, the platform is split into three layers:
- **UI**: static frontend assets hosted from S3 and served through CloudFront at `https://app.acmecorp.autoscaling.io`
- **API entry point**: `gateway-service`, exposed at `https://api.acmecorp.autoscaling.io`
- **Backend services**: orders, catalog, billing, notification, and analytics, backed by Aurora, Redis, RabbitMQ, and Secrets Manager

High-level request path:
- Browser -> CloudFront -> gateway-service -> backend services

For the full architecture and request flow, see [docs/architecture/system-overview.md](docs/architecture/system-overview.md).

## Key Features

- Terraform foundation for VPC, EKS, Aurora, Amazon MQ, Secrets Manager, ECR, ACM, Route53, and UI hosting
- Helm umbrella chart for application services, observability, Redis, and External Secrets
- Environment-driven UI API configuration through `VITE_API_BASE_URL`
- Strict gateway CORS for local UI development and the deployed UI domain
- GitHub Actions CI for backend, frontend, integration, and smoke tests
- GitHub Actions UI deploy workflow for S3 sync and CloudFront invalidation

## Quickstart

### Local Platform

Start the local stack:

```bash
cd infra/local
docker compose up --build
```

Run the UI separately:

```bash
cd webapp
npm ci
npm run dev
```

Default local endpoints:
- UI: `http://localhost:5173`
- Gateway: `http://localhost:8080`
- Orders: `http://localhost:8081`
- Billing: `http://localhost:8082`
- Notification: `http://localhost:8083`
- Analytics: `http://localhost:8084`
- Catalog: `http://localhost:8085`
- RabbitMQ UI: `http://localhost:15672`

### AWS Platform

High-level deploy order:

```bash
terraform -chdir=infra/terraform init
terraform -chdir=infra/terraform apply
scripts/bootstrap-first-cluster.sh
IMAGE_TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)" scripts/build-and-push-ecr.sh
IMAGE_TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)" scripts/render-prod-values.sh /tmp/acmecorp-values-prod.generated.yaml
helm upgrade --install acmecorp-platform helm/acmecorp-platform -n acmecorp -f /tmp/acmecorp-values-prod.generated.yaml
scripts/deploy-ui.sh
```

Terraform provisions the AWS infrastructure, Kubernetes foundation, DNS, certificates, and the S3 + CloudFront hosting resources for the frontend. It does not upload frontend assets into the UI bucket.

### Deploy Frontend

Build and publish the React UI after Terraform has created the UI hosting infrastructure:

```bash
scripts/deploy-ui.sh
```

The script builds `webapp`, syncs `webapp/dist/` to the Terraform-managed S3 bucket, and invalidates the Terraform-managed CloudFront distribution.

See the full production runbooks under [docs/deployment/](docs/deployment/).

## Documentation Map

- [docs/README.md](docs/README.md): documentation hub
- [docs/getting-started/quickstart.md](docs/getting-started/quickstart.md): onboarding and quickstart
- [docs/development/local-setup.md](docs/development/local-setup.md): local development flow
- [docs/architecture/system-overview.md](docs/architecture/system-overview.md): system design and request flow
- [docs/deployment/terraform.md](docs/deployment/terraform.md): Terraform foundation
- [docs/deployment/platform-deployment.md](docs/deployment/platform-deployment.md): AWS + Helm deployment flow
- [docs/deployment/ui-cloudfront.md](docs/deployment/ui-cloudfront.md): UI hosting, CloudFront, and UI deploy workflow
- [docs/operations/observability.md](docs/operations/observability.md): metrics, dashboards, and observability
- [docs/operations/troubleshooting.md](docs/operations/troubleshooting.md): troubleshooting and recovery
- [docs/reference/configuration.md](docs/reference/configuration.md): important env vars, domains, and outputs
- [docs/reference/services.md](docs/reference/services.md): service inventory

## Tech Stack

- **Languages**: Java 21, TypeScript
- **Backend frameworks**: Spring Boot 3, Quarkus 3
- **Frontend**: React 18, Vite 5
- **Infrastructure**: Terraform, AWS, EKS, Route53, ACM, CloudFront, S3
- **Packaging / deployment**: Docker Compose, Helm, Kubernetes
- **Observability**: Spring Actuator, Quarkus metrics, Prometheus, Grafana
- **CI/CD**: GitHub Actions

## Repo Notes

- `docs/course/`, `docs/episodes/`, and `docs/steering/` are preserved as learning and course material.
- The files under `docs/getting-started/`, `docs/architecture/`, `docs/deployment/`, `docs/operations/`, `docs/development/`, and `docs/reference/` are the canonical operational docs.
