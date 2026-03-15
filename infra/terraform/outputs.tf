# Cluster
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
  description = "IAM principal ARN configured for explicit first-admin EKS access"
  value       = module.eks.admin_access_principal_arn
}

# Aurora
output "aurora_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = module.aurora.cluster_endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = module.aurora.cluster_reader_endpoint
}

output "aurora_port" {
  description = "Aurora port"
  value       = module.aurora.port
}

output "aurora_database_name" {
  description = "Aurora initial database name"
  value       = var.aurora_db_name
}

# Amazon MQ
output "mq_broker_endpoint" {
  description = "Amazon MQ AMQP endpoint"
  value       = module.mq.amqp_endpoint
}

output "mq_console_url" {
  description = "Amazon MQ web console URL"
  value       = module.mq.console_url
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
