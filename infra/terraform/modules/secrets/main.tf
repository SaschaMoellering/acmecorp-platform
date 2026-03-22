variable "name_prefix" { type = string }
variable "aurora_master_username" { type = string }
variable "mq_username" { type = string }

# ── Random passwords ────────────────────────────────────────────────────────
resource "random_password" "aurora" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "mq" {
  length           = 32
  special          = true
  override_special = "!#$%&*()+-.?@"
}

resource "random_password" "redis" {
  length  = 32
  special = false
}

resource "random_password" "grafana" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ── Secrets Manager secrets ─────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "aurora" {
  name                    = "${var.name_prefix}/aurora"
  description             = "Aurora Serverless v2 master credentials"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "aurora" {
  secret_id = aws_secretsmanager_secret.aurora.id
  secret_string = jsonencode({
    username = var.aurora_master_username
    password = random_password.aurora.result
  })
}

resource "aws_secretsmanager_secret" "mq" {
  name                    = "${var.name_prefix}/mq"
  description             = "Amazon MQ broker credentials"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "mq" {
  secret_id = aws_secretsmanager_secret.mq.id
  secret_string = jsonencode({
    username = var.mq_username
    password = random_password.mq.result
  })
}

resource "aws_secretsmanager_secret" "redis" {
  name                    = "${var.name_prefix}/redis"
  description             = "Redis authentication password"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    password = random_password.redis.result
  })
}

resource "aws_secretsmanager_secret" "grafana" {
  name                    = "${var.name_prefix}/grafana"
  description             = "Grafana admin password"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id = aws_secretsmanager_secret.grafana.id
  secret_string = jsonencode({
    admin-password = random_password.grafana.result
  })
}

# ── Outputs (ARNs only — no secret values) ──────────────────────────────────
output "aurora_secret_arn" { value = aws_secretsmanager_secret.aurora.arn }
output "mq_secret_arn" { value = aws_secretsmanager_secret.mq.arn }
output "redis_secret_arn" { value = aws_secretsmanager_secret.redis.arn }
output "grafana_secret_arn" { value = aws_secretsmanager_secret.grafana.arn }
output "aurora_password" {
  value     = random_password.aurora.result
  sensitive = true
}
output "mq_password" {
  value     = random_password.mq.result
  sensitive = true
}
