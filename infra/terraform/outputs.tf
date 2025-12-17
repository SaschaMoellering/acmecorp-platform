output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

output "aurora_writer_endpoint" {
  description = "Aurora PostgreSQL writer endpoint"
  value       = module.aurora.writer_endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora PostgreSQL reader endpoint"
  value       = module.aurora.reader_endpoint
}

output "aurora_port" {
  description = "Aurora PostgreSQL port"
  value       = module.aurora.port
}

output "aurora_database_name" {
  description = "Aurora PostgreSQL database name"
  value       = module.aurora.database_name
}

output "frontend_bucket_name" {
  description = "S3 bucket name for frontend"
  value       = module.s3_frontend.bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.domain_name
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.elasticache.redis_endpoint
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = module.elasticache.redis_port
}