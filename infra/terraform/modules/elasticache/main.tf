# ElastiCache Redis Module - Well-Architected: Performance (caching), Reliability (Multi-AZ)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.cluster_name}-redis"
  subnet_ids = var.subnet_ids
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-redis-subnet-group"
  })
}

resource "aws_security_group" "redis" {
  name_prefix = "${var.cluster_name}-redis"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Redis access from VPC only"
  }
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-redis-sg"
  })
}

# Redis AUTH token
resource "random_password" "redis_auth" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name = "${var.cluster_name}-redis-auth"
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = random_password.redis_auth.result
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.cluster_name}-redis"
  description                = "Redis cluster for ${var.cluster_name}"
  
  node_type                  = var.environment == "prod" ? "cache.r7g.large" : "cache.t4g.micro"
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  num_cache_clusters         = var.environment == "prod" ? 2 : 1
  automatic_failover_enabled = var.environment == "prod"
  multi_az_enabled          = var.environment == "prod"
  
  subnet_group_name = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]
  
  # Security: Encryption and Authentication
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result
  
  # User group for RBAC (Redis 6.0+)
  user_group_ids = [aws_elasticache_user_group.redis.user_group_id]
  
  snapshot_retention_limit = var.environment == "prod" ? 5 : 1
  snapshot_window         = "03:00-05:00"
  maintenance_window      = "sun:05:00-sun:07:00"
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-redis"
  })
}

# Redis User for application access
resource "aws_elasticache_user" "app_user" {
  user_id       = "${var.cluster_name}-app-user"
  user_name     = "appuser"
  access_string = "on ~* +@all -flushall -flushdb -shutdown -debug"
  engine        = "REDIS"
  passwords     = [random_password.redis_auth.result]
  
  tags = var.tags
}

# Redis User Group
resource "aws_elasticache_user_group" "redis" {
  engine          = "REDIS"
  user_group_id   = "${var.cluster_name}-user-group"
  user_ids        = ["default", aws_elasticache_user.app_user.user_id]
  
  tags = var.tags
}