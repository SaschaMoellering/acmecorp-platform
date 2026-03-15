variable "name_prefix" { type = string }
variable "broker_name" { type = string }
variable "mq_username" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "eks_node_sg_id" { type = string }
variable "secret_arn" { type = string }

data "aws_secretsmanager_secret_version" "mq" {
  secret_id = var.secret_arn
}

# ── Security group ──────────────────────────────────────────────────────────
resource "aws_security_group" "mq" {
  name        = "${var.name_prefix}-mq"
  description = "Amazon MQ — allow AMQP from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5671
    to_port         = 5671
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
    description     = "AMQPS from EKS nodes"
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
    description     = "MQ web console from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${var.name_prefix}-mq" }
}

# ── Amazon MQ broker ────────────────────────────────────────────────────────
resource "aws_mq_broker" "this" {
  broker_name        = var.broker_name
  engine_type        = "RabbitMQ"
  engine_version     = "3.13"
  host_instance_type = "mq.m5.large"
  deployment_mode    = "SINGLE_INSTANCE"

  subnet_ids         = [var.private_subnet_ids[0]]
  security_groups    = [aws_security_group.mq.id]
  publicly_accessible = false

  user {
    username = var.mq_username
    password = jsondecode(data.aws_secretsmanager_secret_version.mq.secret_string)["password"]
  }

  logs {
    general = true
  }

  maintenance_window_start_time {
    day_of_week = "SUNDAY"
    time_of_day = "03:00"
    time_zone   = "UTC"
  }
}

output "amqp_endpoint" {
  value = tolist(aws_mq_broker.this.instances)[0].endpoints[0]
}

output "console_url" {
  value = tolist(aws_mq_broker.this.instances)[0].console_url
}

output "security_group_id" { value = aws_security_group.mq.id }
