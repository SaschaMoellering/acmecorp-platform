# Platform Deployment

This is the canonical AWS deployment flow for the backend platform and supporting infrastructure.

## Flow

1. Apply Terraform foundation
2. Bootstrap the cluster
3. Build and push service images to ECR
4. Generate production Helm values from Terraform outputs
5. Deploy the Helm release
6. Verify ingress, workloads, and observability
7. Deploy or update the UI through the UI deploy workflow

## 1. Apply Terraform

```bash
terraform -chdir=infra/terraform init
scripts/restore-secrets-if-pending-deletion.sh
terraform -chdir=infra/terraform apply
```

Expected result:
- VPC, EKS, Aurora, MQ, Secrets Manager, ECR, ACM, Route53, and UI hosting are provisioned

## 2. Bootstrap The Cluster

```bash
scripts/bootstrap-first-cluster.sh
```

Expected result:
- namespaces exist
- External Secrets is installed
- CRDs are present
- `auto-ebs-sc` exists for stateful workloads

## 3. Build And Push Images

```bash
export IMAGE_TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)"
terraform -chdir=infra/terraform output -json > /tmp/acmecorp-tf-outputs.json
scripts/build-and-push-ecr.sh "$IMAGE_TAG"
```

## 4. Render Helm Values

```bash
IMAGE_TAG="$IMAGE_TAG" scripts/render-prod-values.sh /tmp/acmecorp-values-prod.generated.yaml
```

Generated values include:
- ECR image URLs
- image tags
- Aurora endpoint
- MQ endpoint
- ingress hostnames
- certificate ARNs
- Redis DNS host for analytics

## 5. Deploy The Helm Release

```bash
helm dependency update helm/acmecorp-platform
helm upgrade --install acmecorp-platform helm/acmecorp-platform \
  -n acmecorp \
  -f /tmp/acmecorp-values-prod.generated.yaml
```

Expected result:
- application services in `acmecorp`
- Redis in `data`
- Prometheus and Grafana in `observability`
- gateway ALB ingress

## 6. Verify Deployment

```bash
kubectl get pods -n acmecorp
kubectl get pods -n data
kubectl get pods -n observability
kubectl get ingress -n acmecorp
scripts/verify-first-deploy.sh
```

## 7. Deploy The UI

Use GitHub Actions:
- workflow: `UI Deploy`
- trigger: push to `main` affecting `webapp/**`, or manual `workflow_dispatch`

Manual fallback:

```bash
VITE_API_BASE_URL="https://$(terraform -chdir=infra/terraform output -raw gateway_ingress_host)" \
  npm --prefix webapp ci
VITE_API_BASE_URL="https://$(terraform -chdir=infra/terraform output -raw gateway_ingress_host)" \
  npm --prefix webapp run build

aws s3 sync webapp/dist/ "s3://$(terraform -chdir=infra/terraform output -raw ui_bucket_name)" \
  --delete \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "index.html"

aws s3 cp webapp/dist/index.html \
  "s3://$(terraform -chdir=infra/terraform output -raw ui_bucket_name)/index.html" \
  --cache-control "no-cache,no-store,must-revalidate" \
  --content-type "text/html"

aws cloudfront create-invalidation \
  --distribution-id "$(terraform -chdir=infra/terraform output -raw ui_cloudfront_distribution_id)" \
  --paths "/*"
```

## Domains

- UI: `https://app.acmecorp.autoscaling.io`
- API: `https://api.acmecorp.autoscaling.io`
- Grafana: `https://grafana.acmecorp.autoscaling.io`

For the UI-specific hosting path, see [ui-cloudfront.md](ui-cloudfront.md).
