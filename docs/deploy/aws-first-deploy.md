# AWS First Deploy

This compatibility entry point now follows the canonical runbooks under:

- [docs/deployment/terraform.md](../deployment/terraform.md)
- [docs/deployment/platform-deployment.md](../deployment/platform-deployment.md)
- [docs/deployment/ui-cloudfront.md](../deployment/ui-cloudfront.md)

Aurora and Amazon MQ now use the EKS-managed cluster security group as their deterministic Auto Mode ingress source, so they no longer depend on discovering live EC2 instances to determine ingress.

## Recommended Flow

Apply Terraform:

```bash
terraform -chdir=infra/terraform init
scripts/restore-secrets-if-pending-deletion.sh
terraform -chdir=infra/terraform apply
```

Equivalent default `tfvars` settings:

```hcl
enable_aurora = true
enable_mq     = true
```

Expected result:

- VPC, EKS, Secrets Manager, IAM, ECR, ACM, Route53, and UI hosting are provisioned
- Aurora and Amazon MQ can be planned and applied immediately
- The long-lived EKS secrets KMS key is retained for reuse across rebuilds
- The EKS-managed cluster security group is available as the Auto Mode ingress source
- Terraform creates the EKS admin access entry and associates the cluster-admin access policy

Inspect the Auto Mode network and admin-access outputs from Terraform:

```bash
terraform -chdir=infra/terraform output eks_cluster_security_group_id
terraform -chdir=infra/terraform output cluster_admin_access_entry_principal_arn
terraform -chdir=infra/terraform output cluster_secrets_kms_key_arn
```

## Bootstrap The Cluster

After Terraform succeeds:

```bash
scripts/bootstrap-first-cluster.sh
```

The bootstrap script prepares the namespaces, storage class, and External Secrets operator. It no longer applies any custom Auto Mode `NodeClass` or `NodePool`.

Optional break-glass overrides remain available:

- `eks_database_client_sg_id_override`
- `mq_client_sg_id_override`

If you are rebuilding from fresh Terraform state, you can also point Terraform at the retained EKS secrets KMS key:

```bash
terraform -chdir=infra/terraform apply \
  -var='eks_secrets_kms_key_arn=arn:aws:kms:eu-west-1:851073193649:key/12345678-1234-1234-1234-123456789012'
```

You can inspect the final ingress source groups with:

```bash
terraform -chdir=infra/terraform output aurora_ingress_source_security_group_ids
terraform -chdir=infra/terraform output mq_ingress_source_security_group_ids
```

## Continue The Deployment

Then continue with:

1. Build and push the service images to ECR
2. Render production Helm values from Terraform outputs
3. Deploy the Helm chart
4. Finalize ALB to Route53 aliases
5. Run the deployment verification steps

Use the canonical runbooks linked at the top of this file for the full command sequence.

If you still want staged provisioning, the `enable_aurora` and `enable_mq` flags remain available, but they are no longer required for deterministic Aurora/MQ ingress planning.

If an older environment already scheduled the EKS secrets key for deletion, recover it manually before applying:

```bash
aws kms cancel-key-deletion --key-id <key-id-or-arn> --region eu-west-1
aws kms enable-key --key-id <key-id-or-arn> --region eu-west-1
```
