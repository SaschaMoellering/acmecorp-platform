# Quickstart

This guide gets a new developer from clone to a working local platform and then points to the AWS deployment path.

## Prerequisites

Required:
- Docker Engine with Docker Compose v2
- Java 21
- Maven 3.9+
- Node.js 20+
- `kubectl`
- Helm 3
- Terraform 1.7+
- AWS CLI for cloud deployment

## Local Quickstart

### 1. Start the platform

```bash
cd infra/local
docker compose up --build
```

Expected local services:
- Gateway: `http://localhost:8080`
- Orders: `http://localhost:8081`
- Billing: `http://localhost:8082`
- Notification: `http://localhost:8083`
- Analytics: `http://localhost:8084`
- Catalog: `http://localhost:8085`
- PostgreSQL: `localhost:5432`
- Redis: `localhost:6379`
- RabbitMQ: `localhost:5672`

### 2. Start the UI

```bash
cd webapp
npm ci
npm run dev
```

Expected UI URL:
- `http://localhost:5173`

The Vite app reads `VITE_API_BASE_URL` from `webapp/.env.development`, which points at `http://localhost:8080`.

### 3. Verify the gateway

```bash
curl http://localhost:8080/api/gateway/status
curl http://localhost:8080/api/gateway/catalog
curl http://localhost:8080/api/gateway/orders/latest
```

Expected result:
- JSON responses from the gateway
- no CORS errors in the browser when using the local UI

## AWS Quickstart

High-level sequence:

1. Apply Terraform phase 1 for base infrastructure and EKS
2. Bootstrap the cluster
3. Build and push service images to ECR
4. Generate production Helm values
5. Deploy the Helm release
6. Deploy the UI to S3 + CloudFront

Commands:

```bash
terraform -chdir=infra/terraform init
terraform -chdir=infra/terraform apply
scripts/bootstrap-first-cluster.sh
terraform -chdir=infra/terraform output -json > /tmp/acmecorp-tf-outputs.json
IMAGE_TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)" scripts/build-and-push-ecr.sh
IMAGE_TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)" scripts/render-prod-values.sh /tmp/acmecorp-values-prod.generated.yaml
helm upgrade --install acmecorp-platform helm/acmecorp-platform -n acmecorp -f /tmp/acmecorp-values-prod.generated.yaml
```

Continue with:
- [../deployment/terraform.md](../deployment/terraform.md)
- [../deployment/platform-deployment.md](../deployment/platform-deployment.md)
- [../deployment/ui-cloudfront.md](../deployment/ui-cloudfront.md)

## Recommended Next Reads

- [../development/local-setup.md](../development/local-setup.md)
- [../architecture/system-overview.md](../architecture/system-overview.md)
- [../reference/configuration.md](../reference/configuration.md)
