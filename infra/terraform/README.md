# Terraform Usage

This directory contains the Terraform configuration for the AWS foundation used by the platform.

Canonical deployment guidance also lives in:

- [../../docs/deployment/terraform.md](../../docs/deployment/terraform.md)
- [../../docs/deployment/platform-deployment.md](../../docs/deployment/platform-deployment.md)

## What This Stack Owns

The Terraform stack provisions the AWS-side foundation for:

- VPC and subnets
- EKS
- Aurora
- Amazon MQ
- Secrets Manager
- IAM and Pod Identity support
- ECR repositories
- ACM certificates
- Route53 DNS
- S3 + CloudFront UI hosting

Terraform creates the hosting and cluster foundation. It does not build or push application images, and it does not upload UI assets.

## Directory

- path: `infra/terraform/`
- main files: `main.tf`, `variables.tf`, `outputs.tf`, `backend.tf`, `backend.tf.example`, `versions.tf`

## Safe Command Sequence

Initialize:

```bash
terraform -chdir=infra/terraform init
```

Validate:

```bash
terraform -chdir=infra/terraform validate
```

Review a plan before applying:

```bash
terraform -chdir=infra/terraform plan
```

Apply only after reviewing the plan:

```bash
terraform -chdir=infra/terraform apply
```

Useful output inspection:

```bash
terraform -chdir=infra/terraform output
terraform -chdir=infra/terraform output gateway_ingress_host
terraform -chdir=infra/terraform output ui_custom_url
terraform -chdir=infra/terraform output cluster_secrets_kms_key_arn
```

## Important Inputs

Commonly reviewed inputs include:

- `aws_region`
- `environment`
- `cluster_name`
- `admin_principal_arn`
- `eks_public_access_cidrs`
- `eks_secrets_kms_key_arn`
- `manage_eks_secrets_kms_key`
- `enable_aurora`
- `enable_mq`
- `public_hosted_zone_name`
- `route53_zone_name` as the deprecated alias
- `gateway_ingress_host`
- `grafana_ingress_host`
- `ui_subdomain`
- `ui_bucket_name_override`

## Important Outputs

Frequently used outputs include:

- `cluster_name`
- `cluster_endpoint`
- `cluster_admin_access_entry_principal_arn`
- `cluster_secrets_kms_key_arn`
- `eks_cluster_security_group_id`
- `aurora_endpoint`
- `mq_broker_endpoint`
- `gateway_ingress_host`
- `grafana_ingress_host`
- `ui_bucket_name`
- `ui_cloudfront_distribution_id`
- `ui_cloudfront_url`
- `ui_custom_url`

## State And Hosted-Zone Assumptions

- The backend configuration lives in `backend.tf`; `backend.tf.example` is the compatibility example.
- The stack expects a public hosted zone for ACM validation and DNS records.
- Prefer `public_hosted_zone_name`; `route53_zone_name` is a compatibility alias.
- The UI ACM certificate is created in `us-east-1` because CloudFront requires that region.

## Safety Notes

- Do not run `terraform apply` casually from a stale shell or stale `tfvars` context.
- Review the plan before applying.
- Do not run destroy commands unless teardown is explicitly intended and reviewed.
- The EKS secrets KMS key is intentionally long-lived; normal rebuilds should reuse it rather than replace it.
- Terraform creates infrastructure only. Application deployment continues through the Helm and UI deployment flows after Terraform succeeds.
