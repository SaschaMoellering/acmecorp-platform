# AcmeCorp Platform Helm Chart

This is the canonical Helm chart for the AWS and EKS deployment path.

Top-level references:

- chart path: `helm/acmecorp-platform`
- release name: `acmecorp-platform`
- application namespace: `acmecorp`
- data namespace: `data`
- observability namespace: `observability`
- External Secrets namespace: `external-secrets`

Related docs:

- [../../docs/deployment/platform-deployment.md](../../docs/deployment/platform-deployment.md)
- [../../docs/deployment/terraform.md](../../docs/deployment/terraform.md)
- [../../infra/terraform/README.md](../../infra/terraform/README.md)

## What The Chart Deploys

The chart packages:

- `gateway-service`
- `orders-service`
- `catalog-service`
- `billing-service`
- `notification-service`
- `analytics-service`
- `redis`
- `prometheus`
- `grafana`
- `external-secrets`

## Values Structure

The main values files are:

- `values.yaml` for shared defaults
- `values-dev.yaml` for development-oriented chart values
- `values-prod.yaml` for the production baseline used before rendering environment-specific values

Important top-level sections:

- `global.*` for region, namespace, Aurora, MQ, and Redis wiring
- per-service sections such as `gateway-service`, `orders-service`, and `catalog-service`
- `redis`, `prometheus`, `grafana`, and `storageClass`

## Render Safely

Lint:

```bash
helm lint helm/acmecorp-platform -f helm/acmecorp-platform/values.yaml
```

Render without applying:

```bash
helm template acmecorp-platform helm/acmecorp-platform \
  --namespace acmecorp \
  -f helm/acmecorp-platform/values.yaml
```

Render the production deployment form after generating values:

```bash
helm template acmecorp-platform helm/acmecorp-platform \
  --namespace acmecorp \
  -f helm/acmecorp-platform/values.yaml \
  -f /tmp/acmecorp-values-prod.generated.yaml
```

The generated production values file is expected to contain Terraform-derived boundary values such as:

- `global.awsRegion`
- `global.secretsNamePrefix`
- ingress hosts
- ACM certificate ARNs
- Aurora and MQ hosts

Treat that generated file as the rendered values output of the Terraform-to-Helm boundary contract. Terraform outputs are the source of truth; avoid hand-editing generated production values.

## Relation To Terraform And Images

- Terraform provides the AWS infrastructure, DNS hostnames, certificate ARNs, and ECR repository URLs.
- `scripts/render-prod-values.sh` reads Terraform outputs and generates `/tmp/acmecorp-values-prod.generated.yaml`.
- the render step now enforces production-critical guardrails before Helm deployment
- Application images must be built and pushed before the production Helm upgrade.

## Ingress And Observability Assumptions

- The gateway uses an ALB-oriented ingress configuration in the canonical AWS path.
- Grafana ingress is also values-driven and expects certificate ARN wiring.
- Prometheus and Grafana are chart-managed in the `observability` namespace.
- External Secrets integration is part of the charted deployment model.

## Documented Defaults And Assumptions

Some values remain intentionally hardcoded as chart defaults or project assumptions, for example:

- default namespaces such as `acmecorp`, `data`, and `observability`
- example ingress hosts under `acmecorp.example.com`
- the default UI CORS origin
- the default storage class name
- default image repositories and resource requests
- the secret-prefix pattern, which must stay aligned with Terraform's `name_prefix`

This pass does not change those behaviors. See `/tmp/helm-hardcoded-values-audit.md` and `/tmp/terraform-helm-boundary-audit.md` for the audit classification.
