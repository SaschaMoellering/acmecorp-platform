# Platform Deployment

This is the canonical AWS deployment flow for the backend platform and supporting infrastructure.

## Flow

1. Apply Terraform for the foundation and platform services
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
- VPC, EKS, Secrets Manager, IAM, ECR, ACM, Route53, and UI hosting are provisioned
- Aurora and Amazon MQ can be provisioned deterministically in the same apply
- The long-lived EKS secrets KMS key is created once and retained
- The EKS-managed cluster security group is available as the Auto Mode ingress source
- Terraform creates an EKS access entry and cluster-admin policy association for the resolved admin principal

Equivalent default `tfvars` settings:

```hcl
eks_secrets_kms_key_arn = null
enable_aurora = true
enable_mq     = true
```

If you are rebuilding from fresh Terraform state and already have the retained EKS secrets KMS key, supply its ARN explicitly:

```bash
terraform -chdir=infra/terraform apply \
  -var='eks_secrets_kms_key_arn=arn:aws:kms:eu-west-1:851073193649:key/12345678-1234-1234-1234-123456789012'
```

Optional staged bring-up remains available:

```hcl
eks_secrets_kms_key_arn = null
enable_aurora = false
enable_mq     = false
```

Optional break-glass overrides:

- `eks_database_client_sg_id_override`
- `mq_client_sg_id_override`

Aurora and MQ ingress now default to the EKS-managed cluster security group instead of discovering SGs from live EC2 instances.

Inspect the resulting node-network outputs:

```bash
terraform -chdir=infra/terraform output eks_cluster_security_group_id
terraform -chdir=infra/terraform output cluster_admin_access_entry_principal_arn
terraform -chdir=infra/terraform output aurora_ingress_source_security_group_ids
terraform -chdir=infra/terraform output mq_ingress_source_security_group_ids
terraform -chdir=infra/terraform output cluster_secrets_kms_key_arn
```

KMS note:

- The customer-managed EKS secrets KMS key is intentionally protected from destroy
- Normal environment rebuilds should reuse that key rather than delete and recreate it
- The cleanup helper leaves the key and alias intact on purpose

## 2. Bootstrap The Cluster

```bash
scripts/bootstrap-first-cluster.sh
```

Expected result:
- namespaces exist
- External Secrets is installed
- CRDs are present
- `auto-ebs-sc` exists for stateful workloads

Verify the EKS Auto Mode security group and built-in node pools:

```bash
terraform -chdir=infra/terraform output eks_cluster_security_group_id
aws eks describe-cluster --name acmecorp-platform --region eu-west-1 --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId'
```

If `kubectl` access fails, first confirm the admin access entry principal Terraform created:

```bash
terraform -chdir=infra/terraform output cluster_admin_access_entry_principal_arn
aws eks list-access-entries --cluster-name acmecorp-platform --region eu-west-1
```

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

## Manual Recovery For Older Broken Environments

If a previous teardown already put the EKS secrets KMS key into `PendingDeletion`, recover it manually before rerunning Terraform:

```bash
aws kms cancel-key-deletion --key-id <key-id-or-arn> --region eu-west-1
aws kms enable-key --key-id <key-id-or-arn> --region eu-west-1
```

Then either reconnect Terraform state to that key or pass it back in through `eks_secrets_kms_key_arn`.
