variable "name_prefix" { type = string }
variable "broker_name" { type = string }
variable "deployment_mode" { type = string }
variable "broker_instance_type" {
  type    = string
  default = null
}
variable "mq_username" { type = string }
variable "mq_password" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "mq_client_security_group_ids" { type = list(string) }
variable "secret_arn" { type = string }

locals {
  resolved_broker_instance_type = var.broker_instance_type != null ? var.broker_instance_type : (
    "mq.m7g.medium"
  )

  broker_subnet_ids = var.deployment_mode == "SINGLE_INSTANCE" ? [var.private_subnet_ids[0]] : slice(var.private_subnet_ids, 0, 2)
  mq_client_security_group_ids_by_key = {
    for index, sg_id in var.mq_client_security_group_ids :
    tostring(index) => sg_id
  }
}

# ── Security group ──────────────────────────────────────────────────────────
resource "aws_security_group" "mq" {
  name        = "${var.name_prefix}-mq"
  description = "Amazon MQ - allow AMQPS from the explicit EKS Auto Mode node security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${var.name_prefix}-mq" }
}

resource "aws_security_group_rule" "mq_ingress" {
  for_each = local.mq_client_security_group_ids_by_key

  type                     = "ingress"
  from_port                = 5671
  to_port                  = 5671
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.mq.id
  description              = "AMQPS from EKS Auto Mode nodes ${each.value}"
}

resource "aws_security_group_rule" "mq_console_ingress" {
  for_each = local.mq_client_security_group_ids_by_key

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.mq.id
  description              = "MQ web console from EKS Auto Mode nodes ${each.value}"
}

# ── Amazon MQ broker ────────────────────────────────────────────────────────
resource "aws_mq_broker" "this" {
  broker_name                = var.broker_name
  engine_type                = "RabbitMQ"
  engine_version             = "3.13"
  auto_minor_version_upgrade = true
  host_instance_type         = local.resolved_broker_instance_type
  deployment_mode            = var.deployment_mode

  subnet_ids          = local.broker_subnet_ids
  security_groups     = [aws_security_group.mq.id]
  publicly_accessible = false

  user {
    username = var.mq_username
    password = var.mq_password
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
