# Cluster
output "aws_region" {
  description = "AWS region for this Terraform deployment"
  value       = var.aws_region
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster CA data (base64)"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_admin_access_entry_principal_arn" {
  description = "IAM principal ARN that Terraform uses for the EKS standard admin access entry and cluster-admin policy association."
  value       = module.eks.admin_access_principal_arn
}

output "cluster_secrets_kms_key_arn" {
  description = "Customer-managed KMS key ARN used for EKS Kubernetes secrets envelope encryption"
  value       = module.eks.secrets_kms_key_arn
}

# Aurora
output "aurora_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = try(module.aurora[0].cluster_endpoint, null)
}

output "aurora_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = try(module.aurora[0].cluster_reader_endpoint, null)
}

output "aurora_port" {
  description = "Aurora port"
  value       = try(module.aurora[0].port, null)
}

output "aurora_database_name" {
  description = "Aurora initial database name"
  value       = var.enable_aurora ? var.aurora_db_name : null
}

output "eks_cluster_security_group_id" {
  description = "EKS-managed cluster security group ID used by the default EKS Auto Mode networking model."
  value       = module.eks.cluster_security_group_id
}

output "aurora_ingress_source_security_group_ids" {
  description = "Security group IDs currently allowed to reach Aurora on tcp/5432. Defaults to the EKS cluster security group unless an explicit override is set."
  value       = var.enable_aurora ? local.aurora_ingress_source_security_group_ids : []
}

# Amazon MQ
output "mq_broker_endpoint" {
  description = "Amazon MQ AMQP endpoint"
  value       = try(module.mq[0].amqp_endpoint, null)
}

output "mq_console_url" {
  description = "Amazon MQ web console URL"
  value       = try(module.mq[0].console_url, null)
}

output "mq_ingress_source_security_group_ids" {
  description = "Security group IDs currently allowed to reach Amazon MQ. Defaults to the EKS cluster security group unless an explicit override is set."
  value       = var.enable_mq ? local.mq_ingress_source_security_group_ids : []
}

# Secrets Manager ARNs (not values)
output "aurora_secret_arn" {
  description = "Secrets Manager ARN for Aurora credentials"
  value       = module.secrets.aurora_secret_arn
}

output "mq_secret_arn" {
  description = "Secrets Manager ARN for Amazon MQ credentials"
  value       = module.secrets.mq_secret_arn
}

output "redis_secret_arn" {
  description = "Secrets Manager ARN for Redis password"
  value       = module.secrets.redis_secret_arn
}

output "grafana_secret_arn" {
  description = "Secrets Manager ARN for Grafana admin password"
  value       = module.secrets.grafana_secret_arn
}

# IAM role ARNs for Pod Identity
output "app_role_arn" {
  description = "IAM role ARN for application workloads (secrets read)"
  value       = module.iam.app_role_arn
}

output "observability_role_arn" {
  description = "IAM role ARN for observability workloads (Grafana secrets read)"
  value       = module.iam.observability_role_arn
}

# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# ECR
output "ecr_repository_urls" {
  description = "Map of ECR repository URLs keyed by repository name"
  value       = module.ecr.repository_urls
}

# ACM / DNS
output "route53_zone_id" {
  description = "Route53 hosted zone ID used for ingress DNS and ACM validation"
  value       = module.dns.zone_id
}

output "gateway_ingress_host" {
  description = "Gateway public ingress hostname"
  value       = module.dns.gateway_hostname
}

output "grafana_ingress_host" {
  description = "Grafana public ingress hostname"
  value       = module.dns.grafana_hostname
}

output "gateway_certificate_arn" {
  description = "ACM certificate ARN for the gateway ingress hostname"
  value       = module.acm.gateway_certificate_arn
}

output "grafana_certificate_arn" {
  description = "ACM certificate ARN for the Grafana ingress hostname"
  value       = module.acm.grafana_certificate_arn
}

# UI hosting
output "ui_bucket_name" {
  description = "S3 bucket that stores the static UI assets"
  value       = module.ui.bucket_name
}

output "ui_cloudfront_domain_name" {
  description = "CloudFront distribution domain name for the UI"
  value       = module.ui.cloudfront_distribution_domain_name
}

output "ui_cloudfront_url" {
  description = "CloudFront distribution URL for the UI"
  value       = module.ui.cloudfront_distribution_url
}

output "ui_cloudfront_distribution_id" {
  description = "CloudFront distribution ID for the UI"
  value       = module.ui.cloudfront_distribution_id
}

output "ui_hostname" {
  description = "Frontend hostname"
  value       = module.ui.custom_domain
}

output "ui_custom_domain" {
  description = "Custom hostname for the UI served via CloudFront"
  value       = module.ui.custom_domain
}

output "ui_custom_url" {
  description = "Custom URL for the UI served via CloudFront"
  value       = module.ui.custom_url
}
