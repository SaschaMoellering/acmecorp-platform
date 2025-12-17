output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_port" {
  description = "Redis cluster port"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_auth_secret_arn" {
  description = "ARN of Redis AUTH token secret"
  value       = aws_secretsmanager_secret.redis_auth.arn
}

output "redis_auth_secret_name" {
  description = "Name of Redis AUTH token secret"
  value       = aws_secretsmanager_secret.redis_auth.name
}