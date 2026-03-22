# Terraform Infrastructure

Terraform under `infra/terraform/` provisions the AWS foundation for the platform.

## Modules

| Module | Purpose |
| --- | --- |
| `vpc` | VPC, public/private/database subnets, NAT, route tables |
| `eks` | EKS cluster, admin access entry, worker security groups, secrets KMS key |
| `aurora` | Aurora PostgreSQL cluster |
| `mq` | Amazon MQ broker |
| `secrets` | Secrets Manager secrets for Aurora, MQ, Redis, and Grafana |
| `iam` | Pod Identity roles and permissions |
| `ecr` | ECR repositories for service images |
| `acm` | ACM for gateway and Grafana ingress |
| `dns` | Route53 aliases for ingress ALBs |
| `ui` | S3 bucket, CloudFront, ACM in `us-east-1`, and Route53 alias for the UI |

## Key Inputs

The most important variables are:
- `aws_region`
- `environment`
- `cluster_name`
- `admin_principal_arn`
- `route53_zone_name`
- `gateway_ingress_host`
- `grafana_ingress_host`
- `ui_subdomain`
- `ui_bucket_name_override`

## Common Commands

Initialize:

```bash
terraform -chdir=infra/terraform init
```

Plan:

```bash
terraform -chdir=infra/terraform plan
```

Apply:

```bash
terraform -chdir=infra/terraform apply
```

Inspect outputs:

```bash
terraform -chdir=infra/terraform output
terraform -chdir=infra/terraform output ui_cloudfront_url
terraform -chdir=infra/terraform output ui_custom_url
terraform -chdir=infra/terraform output gateway_ingress_host
```

## Important Outputs

Infrastructure:
- `cluster_name`
- `cluster_endpoint`
- `vpc_id`
- `private_subnet_ids`
- `aurora_endpoint`
- `mq_broker_endpoint`

UI hosting:
- `ui_bucket_name`
- `ui_cloudfront_domain_name`
- `ui_cloudfront_url`
- `ui_cloudfront_distribution_id`
- `ui_custom_domain`
- `ui_custom_url`

Gateway and DNS:
- `gateway_ingress_host`
- `grafana_ingress_host`
- `route53_zone_id`

## UI Hosting Notes

The `ui` module creates:
- a private S3 bucket
- CloudFront with Origin Access Control
- an ACM certificate in `us-east-1`
- Route53 validation records
- Route53 alias records for the UI custom domain

Terraform provisions the hosting infrastructure, but it does **not** upload UI assets. Asset upload happens through GitHub Actions or manual `aws s3 sync`.

Continue with [platform-deployment.md](platform-deployment.md) and [ui-cloudfront.md](ui-cloudfront.md).
