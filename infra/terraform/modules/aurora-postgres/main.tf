# Aurora PostgreSQL Module - Well-Architected: Security (IAM auth), Reliability (Multi-AZ)
# Creates Aurora PostgreSQL cluster with IAM authentication enabled

# DB Subnet Group for Aurora
resource "aws_db_subnet_group" "main" {
  name       = "${var.cluster_name}-subnet-group"
  subnet_ids = var.subnet_ids
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-subnet-group"
  })
}

# Security Group for Aurora
resource "aws_security_group" "aurora" {
  name_prefix = "${var.cluster_name}-aurora"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "PostgreSQL access from VPC"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-aurora-sg"
  })
}

# KMS Key for Aurora encryption
resource "aws_kms_key" "aurora" {
  description             = "Aurora PostgreSQL encryption key"
  deletion_window_in_days = 7
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-aurora-key"
  })
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/${var.cluster_name}-aurora"
  target_key_id = aws_kms_key.aurora.key_id
}

# DB Parameter Group for production tuning
resource "aws_db_parameter_group" "aurora_postgres" {
  family = "aurora-postgresql16"
  name   = "${var.cluster_name}-params"
  
  # Production tuning parameters
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }
  
  parameter {
    name  = "log_statement"
    value = "all"
  }
  
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
  
  tags = var.tags
}

# Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier     = var.cluster_name
  engine                 = "aurora-postgresql"
  engine_version         = "16.4"
  database_name          = var.database_name
  master_username        = "postgres"
  manage_master_user_password = true
  
  # IAM Database Authentication
  iam_database_authentication_enabled = true
  
  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.aurora.id]
  
  # Encryption
  storage_encrypted = true
  kms_key_id       = aws_kms_key.aurora.arn
  
  # Backup configuration
  backup_retention_period = var.environment == "prod" ? 7 : 3
  preferred_backup_window = "03:00-04:00"
  
  # Maintenance
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  
  # Performance Insights
  performance_insights_enabled = true
  
  # Parameter group
  db_cluster_parameter_group_name = aws_db_parameter_group.aurora_postgres.name
  
  # Deletion protection for production
  deletion_protection = var.environment == "prod"
  
  # Skip final snapshot for non-prod
  skip_final_snapshot = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.cluster_name}-final-snapshot" : null
  
  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}

# Aurora Cluster Instances
resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = var.environment == "prod" ? 2 : 1
  identifier         = "${var.cluster_name}-${count.index}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.environment == "prod" ? "db.r6g.large" : "db.t4g.medium"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
  
  # Performance Insights
  performance_insights_enabled = true
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${count.index}"
  })
}

# Create IAM database user (requires manual setup post-deployment)
# This is documented in the outputs for manual execution
locals {
  create_iam_user_sql = <<-EOF
    -- Run this SQL as postgres superuser after cluster creation:
    CREATE USER ${var.username} WITH LOGIN;
    GRANT rds_iam TO ${var.username};
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${var.username};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${var.username};
  EOF
}