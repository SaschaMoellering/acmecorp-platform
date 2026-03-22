# AWS First Deploy

This document is the first real deployment runbook for AcmeCorp on AWS.

Target architecture:
- Amazon EKS Auto Mode
- EKS Pod Identity
- Terraform-managed infrastructure
- Helm-managed workloads
- AWS Secrets Manager with External Secrets
- Canonical Helm chart at `helm/acmecorp-platform`

This runbook assumes the Terraform and Helm implementation already present in this repository.

## Prerequisites

You need:
- an AWS account and credentials with permission to provision EKS, VPC, ECR, ACM, Route53, Aurora, Amazon MQ, IAM, and Secrets Manager
- a public Route53 hosted zone that already exists for your chosen domain
- Docker
- AWS CLI
- Terraform
- `kubectl`
- `helm`
- `jq`
- `yq`

Expected local context:
- repo root is your working directory
- the IAM principal you are using matches `admin_principal_arn` in Terraform so the explicit EKS access entry applies to you

## Deployment flow

The first deployment is a two-phase infrastructure and workload rollout:

1. Apply Terraform foundation
2. Bootstrap the fresh cluster for namespaces and External Secrets
3. Build and push service images to ECR
4. Generate production Helm values from Terraform outputs
5. Deploy the canonical Helm chart
6. Wait for the ALB-backed ingresses to be created
7. Run a second Terraform apply to create the Route53 alias records that point at those ALBs
8. Verify the platform end to end

## 1. Configure Terraform inputs

Create `infra/terraform/terraform.tfvars` with at least:

```hcl
aws_region           = "eu-west-1"
environment          = "prod"
cluster_name         = "acmecorp-platform"
admin_principal_arn  = "arn:aws:iam::<ACCOUNT_ID>:role/<YOUR_ADMIN_ROLE_OR_USER>"
eks_public_access_cidrs = ["0.0.0.0/0"]
nat_gateway_mode     = "single"
mq_deployment_mode   = "SINGLE_INSTANCE"
route53_zone_name    = "acmecorp.example.com"
gateway_ingress_host = "api.acmecorp.example.com"
grafana_ingress_host = "grafana.acmecorp.example.com"
```

Important:
- for the lowest recurring demo/dev cost, keep `nat_gateway_mode = "single"` and `mq_deployment_mode = "SINGLE_INSTANCE"` so Terraform uses one shared NAT gateway and the smallest practical RabbitMQ broker size
- the EKS cluster is managed in API-only authentication mode; keep `admin_principal_arn` set to an IAM principal that should retain cluster-admin access through EKS access entries
- do not set the ALB alias variables yet
- those values do not exist until after Helm has created the ingresses and AWS has provisioned the ALBs

## 2. Apply Terraform foundation

Before `terraform apply`, restore any expected Secrets Manager secrets that still exist by name but are pending deletion:

```bash
scripts/restore-secrets-if-pending-deletion.sh
```

This preflight step:
- checks these exact secret names:
  - `acmecorp-platform-prod/aurora`
  - `acmecorp-platform-prod/mq`
  - `acmecorp-platform-prod/redis`
  - `acmecorp-platform-prod/grafana`
- does nothing when a secret does not exist yet
- does nothing when a secret already exists and is active
- restores a secret automatically when AWS still has it scheduled for deletion

Run it again before retrying `terraform apply` after a failed or interrupted deployment.

```bash
terraform -chdir=infra/terraform init
scripts/restore-secrets-if-pending-deletion.sh
terraform -chdir=infra/terraform apply -var-file=terraform.tfvars
```

This provisions:
- VPC and subnets
- EKS Auto Mode cluster
- EKS admin access entry
- Aurora Serverless v2
- Amazon MQ
- Secrets Manager secrets
- Pod Identity IAM roles and associations
- ECR repositories
- ACM certificates and DNS validation

## 3. Bootstrap the fresh cluster

Bootstrap the fresh cluster before building images or installing the umbrella chart:

```bash
scripts/bootstrap-first-cluster.sh
```

What the bootstrap script does:
- updates kubeconfig for the Terraform-managed EKS cluster
- updates Helm dependencies for `helm/acmecorp-platform`
- creates the required namespaces from the chart template:
  - `acmecorp`
  - `observability`
  - `external-secrets`
  - `data`
- creates the EKS Auto Mode storage class required by Redis and Prometheus:
  - `auto-ebs-sc`
- installs the bundled `external-secrets` subchart as a separate Helm release
- configures the operator only for the repo's required resources:
  - `ClusterSecretStore`
  - `ExternalSecret`
- waits for the `external-secrets` deployment rollout
- verifies these CRDs exist:
  - `externalsecrets.external-secrets.io`
  - `secretstores.external-secrets.io`
  - `clustersecretstores.external-secrets.io`

This step is required on a fresh cluster because the umbrella chart cannot reliably install CRDs and `ExternalSecret` resources in the same first-time release.

The generated production values also disable namespace rendering for the umbrella release, so the main app install does not try to take ownership of namespaces that bootstrap already created.
The generated production values also disable `storageClass.create`, because bootstrap precreates the shared `auto-ebs-sc` class before the StatefulSets are installed.

## 4. Capture Terraform outputs

Write Terraform outputs to JSON for downstream scripts:

```bash
terraform -chdir=infra/terraform output -json > /tmp/acmecorp-tf-outputs.json
```

These outputs drive:
- ECR image destinations
- production Helm values
- ingress certificate ARNs
- database and MQ endpoints

## 5. Build and push all service images to ECR

Choose a release tag:

```bash
export IMAGE_TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)"
```

Use a unique tag on each deployment attempt so Helm updates the workload templates and Kubernetes pulls the fresh images built from the current Dockerfiles.

Build and push all six services:

```bash
scripts/build-and-push-ecr.sh "$IMAGE_TAG"
```

What the script does:
- reads ECR repository URLs from Terraform outputs
- logs in to ECR
- builds each service image from the explicit service directory
- tags each image with the required release tag
- pushes all six images

## 6. Generate production Helm values

Generate a deployment-specific production values file:

```bash
IMAGE_TAG="$IMAGE_TAG" scripts/render-prod-values.sh /tmp/acmecorp-values-prod.generated.yaml
```

The generated file is based on:
- `helm/acmecorp-platform/values-prod.yaml`

It fills in:
- AWS region
- Aurora endpoint
- MQ endpoint
- gateway and Grafana hosts
- ACM certificate ARNs
- all six ECR repository URLs
- image tags for all six services
- `image.pullPolicy: Always` for all six backend services so upgraded pods pull the new ECR image for the requested tag

Important runtime expectations for the generated production values:
- Amazon MQ RabbitMQ is exposed to the applications over AMQPS on port `5671`
- `global.mq.host` must be the broker hostname only, without scheme and without port
- `global.mq.port` stays `5671`
- application TLS stays separate from the host/port split; Spring Boot services that connect to Amazon MQ on `5671` must set `SPRING_RABBITMQ_SSL_ENABLED=true`
- analytics must use the EKS Redis service DNS name, not the local Docker Compose hostname `redis`

Example production values after rendering:

```yaml
global:
  aurora:
    host: acmecorp-platform-prod.cluster-abcdefghijkl.eu-west-1.rds.amazonaws.com
    port: "5432"
  mq:
    host: b-12345678-90ab-cdef-1234-567890abcdef.mq.eu-west-1.on.aws
    port: "5671"
  redis:
    host: redis.data.svc.cluster.local
    port: "6379"
```

Expected effective runtime configuration for the MQ-connected Spring Boot services:

```yaml
env:
  - name: RABBITMQ_HOST
    value: b-12345678-90ab-cdef-1234-567890abcdef.mq.eu-west-1.on.aws
  - name: RABBITMQ_PORT
    value: "5671"
  - name: SPRING_RABBITMQ_SSL_ENABLED
    value: "true"
```

## 7. Connect kubectl to the cluster

```bash
CLUSTER_NAME=$(terraform -chdir=infra/terraform output -raw cluster_name)
AWS_REGION=$(terraform -chdir=infra/terraform console <<'EOF' | tr -d '\r'
var.aws_region
EOF
)
AWS_REGION="${AWS_REGION//\"/}"

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
kubectl get nodes
```

## 8. Pre-deployment validation

Before the first Helm install, run the full validation workflow:

```bash
PROD_VALUES=/tmp/acmecorp-values-prod.generated.yaml scripts/validate-deploy.sh
```

This validates:
- Terraform formatting
- Terraform configuration and plan
- Helm lint
- Helm template rendering
- Kubernetes manifest conformance with `kubeconform`
- Helm dry-run using the generated production values

Outputs:
- rendered manifests at `/tmp/acmecorp-rendered.yaml`
- Terraform plan at `/tmp/acmecorp-tfplan`

If this step fails, fix the issue before attempting the real install.

## 9. Validate Helm input before install

```bash
helm dependency update helm/acmecorp-platform
helm lint helm/acmecorp-platform \
  -f helm/acmecorp-platform/values.yaml \
  -f /tmp/acmecorp-values-prod.generated.yaml

helm template acmecorp-platform helm/acmecorp-platform \
  -f helm/acmecorp-platform/values.yaml \
  -f /tmp/acmecorp-values-prod.generated.yaml \
  > /tmp/acmecorp-rendered.yaml
```

## 10. Deploy the canonical Helm chart

```bash
helm upgrade --install acmecorp-platform helm/acmecorp-platform \
  -n acmecorp --create-namespace \
  -f helm/acmecorp-platform/values.yaml \
  -f /tmp/acmecorp-values-prod.generated.yaml
```

This deploys:
- application services
- Redis
- Prometheus
- Grafana
- `ClusterSecretStore`
- `ExternalSecret` resources
- ingress resources for gateway and Grafana

The External Secrets Operator and CRDs are installed by `scripts/bootstrap-first-cluster.sh` before this step.
The generated production values disable `namespaces.enabled`, so this release does not attempt to recreate the pre-bootstrapped namespaces.

Probe behavior in the production chart:
- orders-service uses:
  - `/actuator/health/liveness`
  - `/actuator/health/readiness`
- notification-service uses:
  - `/actuator/health/liveness`
  - `/actuator/health/readiness`

Do not point Kubernetes liveness probes at `/actuator/health` directly for these services. That endpoint includes dependency-aware health contributors, so a temporary outage in RabbitMQ, Aurora, or Redis can make Kubernetes restart a healthy JVM process. The liveness and readiness probe groups separate "should this container be restarted?" from "should this pod receive traffic right now?".

## 11. Two-step ALB to Route53 alias handoff

The Terraform DNS module supports Route53 alias records for the gateway and Grafana ingresses, but those alias targets are only known after AWS creates the ALBs for the ingresses.

That means the first real deployment is intentionally a two-step process:

1. Terraform apply without ALB alias inputs
2. Helm deploy to create the ingresses and ALBs
3. Read the ALB DNS names and zone IDs
4. Terraform apply again with:
   - `gateway_alb_dns_name`
   - `gateway_alb_zone_id`
   - `grafana_alb_dns_name`
   - `grafana_alb_zone_id`

Use the helper:

```bash
scripts/finalize-alb-dns.sh
```

What the script does:
- reads the concrete ingress objects:
  - `acmecorp-platform-gateway-service-ingress` in namespace `acmecorp`
  - `grafana` in namespace `observability`
- extracts their ALB hostnames from ingress status
- resolves ALB canonical hosted zone IDs with `aws elbv2 describe-load-balancers`
- re-runs `terraform apply` with the required alias variables

## 12. Verify the first deployment

Run the verification helper:

```bash
scripts/verify-first-deploy.sh
```

It verifies:
- namespaces
- rollout status
- service accounts
- `ClusterSecretStore`
- `ExternalSecret` resources
- synced Secrets
- gateway ingress HTTPS response
- Grafana ingress HTTPS response
- Prometheus active targets

You can also inspect the key pieces manually:

```bash
kubectl get pods -A
kubectl get sa -n acmecorp
kubectl get externalsecret -A
kubectl get secret -n acmecorp
kubectl get ingress -A
```

## Troubleshooting

### Terraform apply fails on ACM or DNS

Check:
- the public Route53 hosted zone already exists
- `route53_zone_name` matches the actual hosted zone
- the requested ingress hostnames belong to that zone

### ECR push fails

Check:
- AWS credentials
- ECR login region
- repository URLs from Terraform output
- image tag supplied to `scripts/build-and-push-ecr.sh`

### RabbitMQ EOFException on port 5671

Symptoms:
- TLS network checks succeed, for example `openssl s_client` to the Amazon MQ endpoint works
- Spring Boot logs still show `EOFException` or connection startup failure against RabbitMQ

Check:
- `global.mq.host` rendered as hostname only, with no `amqps://` prefix and no `:5671` suffix
- `global.mq.port` is `"5671"`
- the service has `SPRING_RABBITMQ_SSL_ENABLED=true`
- credentials come from `mq-credentials`

Why this happens:
- Amazon MQ listens with TLS on `5671`
- if Spring Boot is pointed at the TLS listener but SSL is not enabled, the TCP connection can succeed while the AMQP protocol negotiation fails immediately
- that failure often surfaces as `EOFException`, even though basic network reachability and TLS handshake tests look healthy

Useful checks:

```bash
kubectl get configmap acmecorp-platform-orders-service-config -n acmecorp -o yaml
kubectl get configmap acmecorp-platform-notification-service-config -n acmecorp -o yaml
kubectl get deploy acmecorp-platform-orders-service -n acmecorp -o yaml | rg 'SPRING_RABBITMQ_SSL_ENABLED|RABBITMQ_HOST|RABBITMQ_PORT'
kubectl get deploy acmecorp-platform-notification-service -n acmecorp -o yaml | rg 'SPRING_RABBITMQ_SSL_ENABLED|RABBITMQ_HOST|RABBITMQ_PORT'
```

### Redis UnknownHostException for `redis`

Symptoms:
- analytics logs show `UnknownHostException: redis`

Check:
- the analytics ConfigMap renders `REDIS_HOST=redis.data.svc.cluster.local`
- `REDIS_PORT="6379"`
- the `redis` StatefulSet and Service are present in namespace `data`

Why this happens:
- `redis` is the local Docker Compose hostname
- in EKS, analytics must use the cluster DNS name for the Redis Service in namespace `data`

Useful checks:

```bash
kubectl get configmap acmecorp-platform-analytics-service-config -n acmecorp -o yaml
kubectl get svc -n data
kubectl logs deployment/acmecorp-platform-analytics-service -n acmecorp --tail=200
```

### Helm deploy succeeds but pods crash

Check:
- `/tmp/acmecorp-values-prod.generated.yaml`
- Aurora endpoint and MQ endpoint values
- image repository and tag values
- namespace-scoped pod logs

Examples:

```bash
kubectl logs deploy/gateway-service -n acmecorp
kubectl logs deploy/orders-service -n acmecorp
kubectl logs deploy/external-secrets -n external-secrets
```

### External Secrets do not reconcile

Check:
- `ClusterSecretStore` status
- External Secrets Operator logs
- Pod Identity association correctness
- target Secrets Manager ARNs and secret names

Commands:

```bash
kubectl get clustersecretstore aws-secrets-manager -o yaml
kubectl get externalsecret -A
kubectl logs deploy/external-secrets -n external-secrets
```

### Ingress exists but DNS does not resolve

Check:
- the second Terraform apply was actually run
- ingress status contains ALB hostnames
- Route53 alias records were created in the correct hosted zone

### Prometheus is running but no targets are active

Check:
- pod annotations / ServiceMonitors
- network policies
- Prometheus pod logs

Commands:

```bash
kubectl port-forward svc/prometheus -n observability 9090:9090
curl -sS http://127.0.0.1:9090/api/v1/targets | jq .
```

## Supporting scripts

This repository now includes:
- `scripts/build-and-push-ecr.sh`
- `scripts/render-prod-values.sh`
- `scripts/finalize-alb-dns.sh`
- `scripts/verify-first-deploy.sh`

These scripts are repo-root oriented and assume the canonical infrastructure and chart layout already present in the repository.
