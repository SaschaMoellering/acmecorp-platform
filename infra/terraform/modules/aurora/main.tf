variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "database_subnet_ids" { type = list(string) }
variable "eks_node_sg_id" { type = string }
variable "db_name" { type = string }
variable "master_username" { type = string }
variable "deletion_protection" { type = bool }
variable "secret_arn" { type = string }

# ── Security group ──────────────────────────────────────────────────────────
resource "aws_security_group" "aurora" {
  name        = "${var.name_prefix}-aurora"
  description = "Aurora Serverless v2 — allow access from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
    description     = "PostgreSQL from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${var.name_prefix}-aurora" }
}

# ── Subnet group ────────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.name_prefix}-aurora"
  subnet_ids = var.database_subnet_ids
}

# ── Parameter group ─────────────────────────────────────────────────────────
resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.name_prefix}-aurora-pg16"
  family      = "aurora-postgresql16"
  description = "AcmeCorp Aurora PostgreSQL 16 parameter group"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
}

# ── Aurora Serverless v2 cluster ────────────────────────────────────────────
resource "aws_rds_cluster" "this" {
  cluster_identifier        = "${var.name_prefix}-aurora"
  engine                    = "aurora-postgresql"
  engine_mode               = "provisioned"
  engine_version            = "16.4"
  database_name             = var.db_name
  master_username           = var.master_username
  manage_master_user_password = false
  master_password           = jsondecode(data.aws_secretsmanager_secret_version.aurora.secret_string)["password"]

  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  storage_encrypted       = true
  deletion_protection     = var.deletion_protection
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.name_prefix}-aurora-final"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 8.0
  }
}

data "aws_secretsmanager_secret_version" "aurora" {
  secret_id = var.secret_arn
}

# ── Aurora Serverless v2 instance ───────────────────────────────────────────
resource "aws_rds_cluster_instance" "this" {
  identifier         = "${var.name_prefix}-aurora-instance-1"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
}

# ── Enhanced monitoring role ────────────────────────────────────────────────
data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "${var.name_prefix}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

output "cluster_endpoint" { value = aws_rds_cluster.this.endpoint }
output "cluster_reader_endpoint" { value = aws_rds_cluster.this.reader_endpoint }
output "port" { value = aws_rds_cluster.this.port }
output "cluster_arn" { value = aws_rds_cluster.this.arn }
output "security_group_id" { value = aws_security_group.aurora.id }
