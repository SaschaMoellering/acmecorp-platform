# Terraform Infrastructure

Terraform under `infra/terraform/` provisions the AWS foundation for the platform.

## Modules

| Module | Purpose |
| --- | --- |
| `vpc` | VPC, public/private/database subnets, NAT, route tables |
| `eks` | EKS cluster, Auto Mode node role, EKS-managed cluster security group, access entries, secrets KMS key |
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
- `eks_secrets_kms_key_arn`
- `enable_aurora`
- `enable_mq`
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

Bootstrap the cluster after Terraform succeeds:

```bash
scripts/bootstrap-first-cluster.sh
```

Inspect the Auto Mode network and admin-access inputs:

```bash
terraform -chdir=infra/terraform output eks_cluster_security_group_id
terraform -chdir=infra/terraform output cluster_admin_access_entry_principal_arn
```

Inspect outputs:

```bash
terraform -chdir=infra/terraform output
terraform -chdir=infra/terraform output ui_cloudfront_url
terraform -chdir=infra/terraform output ui_custom_url
terraform -chdir=infra/terraform output gateway_ingress_host
terraform -chdir=infra/terraform output aurora_ingress_source_security_group_ids
terraform -chdir=infra/terraform output mq_ingress_source_security_group_ids
```

Equivalent `tfvars` examples:

```hcl
# full stack
admin_principal_arn    = ""
eks_secrets_kms_key_arn = null
enable_aurora = true
enable_mq     = true
```

```hcl
# optional staged bring-up
admin_principal_arn    = ""
eks_secrets_kms_key_arn = null
enable_aurora = false
enable_mq     = false
```

## Cluster Admin Access

The EKS cluster uses `authentication_mode = "API"`, so Kubernetes access is granted through EKS access entries.

Terraform now creates:

- a standard EKS access entry for the resolved cluster admin principal
- an `AmazonEKSClusterAdminPolicy` association with cluster-wide scope

Resolution order for the admin principal:

1. Use `admin_principal_arn` when it is set explicitly
2. Otherwise, derive the underlying IAM role ARN from the current caller when Terraform is running under an assumed role

You can confirm the principal Terraform is using with:

```bash
terraform -chdir=infra/terraform output cluster_admin_access_entry_principal_arn
```

## KMS Ownership

The repository currently manages one customer-managed KMS key:

- `cluster_secrets_kms_key_arn`: the EKS Kubernetes secrets envelope-encryption key

That key is intentionally long-lived:

- Terraform creates it once by default
- the managed key and alias are protected with `prevent_destroy`
- the AWS cleanup helper intentionally leaves the key and alias in place

Normal rebuild model:

1. Keep the existing KMS key
2. Rebuild EKS and the rest of the environment around it
3. Reuse the existing key ARN when rebuilding from fresh state

Example fresh-state rebuild using an existing key:

```bash
terraform -chdir=infra/terraform apply \
  -var='eks_secrets_kms_key_arn=arn:aws:kms:eu-west-1:851073193649:key/12345678-1234-1234-1234-123456789012' \
  -var='enable_aurora=false' \
  -var='enable_mq=false'
```

If `eks_secrets_kms_key_arn` is left `null`, Terraform uses the retained key it manages in-state.

## Auto Mode Networking

Aurora and Amazon MQ no longer infer ingress sources from currently running Auto Mode EC2 instances.

They now default to the EKS-managed cluster security group that Auto Mode uses in the built-in networking model unless one of the break-glass overrides is set:

- `eks_database_client_sg_id_override`
- `mq_client_sg_id_override`

## Important Outputs

Infrastructure:
- `cluster_name`
- `cluster_endpoint`
- `cluster_secrets_kms_key_arn`
- `eks_cluster_security_group_id`
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

When `enable_aurora = false`, Aurora outputs return `null` and Aurora ingress source security group outputs return `[]`.
When `enable_mq = false`, Amazon MQ outputs return `null` and MQ ingress source security group outputs return `[]`.

Two-phase Terraform is no longer required for Aurora and MQ ingress planning, because the EKS cluster security group is explicit and deterministic. The `enable_aurora` and `enable_mq` flags remain available for optional staged provisioning.

## Intentional KMS Replacement

Do not replace the EKS secrets KMS key as part of normal rebuilds.

If you must rotate to a different customer-managed key intentionally:

1. Create the replacement key first
2. Update `eks_secrets_kms_key_arn` to the new ARN
3. Apply Terraform and confirm EKS is using the new key
4. Remove or retire the old key only after all dependent infrastructure and state have been migrated deliberately

## Manual Recovery Note

If an older environment already scheduled the retained key for deletion, recover it manually before running Terraform:

```bash
aws kms cancel-key-deletion --key-id <key-id-or-arn> --region eu-west-1
aws kms enable-key --key-id <key-id-or-arn> --region eu-west-1
```

Then either:

- reconnect Terraform to the existing managed key state, or
- pass the recovered key ARN through `eks_secrets_kms_key_arn` for the rebuild

This recovery path is operator guidance only. Terraform does not automate KMS recovery.

Continue with [platform-deployment.md](platform-deployment.md) and [ui-cloudfront.md](ui-cloudfront.md).
