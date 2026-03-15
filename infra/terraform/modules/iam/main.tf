variable "name_prefix" { type = string }
variable "cluster_name" { type = string }
variable "aws_region" { type = string }
variable "account_id" { type = string }
variable "aurora_secret_arn" { type = string }
variable "mq_secret_arn" { type = string }
variable "redis_secret_arn" { type = string }
variable "grafana_secret_arn" { type = string }
variable "aurora_cluster_arn" { type = string }

# ── Shared assume-role policy for Pod Identity ───────────────────────────────
data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# ── Application workload role ────────────────────────────────────────────────
# Used by: orders, billing, notification, analytics, catalog, gateway
resource "aws_iam_role" "app" {
  name               = "${var.name_prefix}-app-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

data "aws_iam_policy_document" "app" {
  statement {
    sid    = "ReadAppSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      var.aurora_secret_arn,
      var.mq_secret_arn,
      var.redis_secret_arn,
    ]
  }
}

resource "aws_iam_policy" "app" {
  name   = "${var.name_prefix}-app-policy"
  policy = data.aws_iam_policy_document.app.json
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app.arn
}

# ── Observability role ───────────────────────────────────────────────────────
# Used by: Grafana
resource "aws_iam_role" "observability" {
  name               = "${var.name_prefix}-observability-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

data "aws_iam_policy_document" "observability" {
  statement {
    sid    = "ReadGrafanaSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [var.grafana_secret_arn]
  }
}

resource "aws_iam_policy" "observability" {
  name   = "${var.name_prefix}-observability-policy"
  policy = data.aws_iam_policy_document.observability.json
}

resource "aws_iam_role_policy_attachment" "observability" {
  role       = aws_iam_role.observability.name
  policy_arn = aws_iam_policy.observability.arn
}

# ── External Secrets Operator role ──────────────────────────────────────────
# Used by: ESO ClusterSecretStore service account
resource "aws_iam_role" "eso" {
  name               = "${var.name_prefix}-eso-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

data "aws_iam_policy_document" "eso" {
  statement {
    sid    = "ESOReadAllPlatformSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = [
      var.aurora_secret_arn,
      var.mq_secret_arn,
      var.redis_secret_arn,
      var.grafana_secret_arn,
    ]
  }
}

resource "aws_iam_policy" "eso" {
  name   = "${var.name_prefix}-eso-policy"
  policy = data.aws_iam_policy_document.eso.json
}

resource "aws_iam_role_policy_attachment" "eso" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.eso.arn
}

# ── Pod Identity associations ────────────────────────────────────────────────
resource "aws_eks_pod_identity_association" "app_acmecorp" {
  for_each = toset([
    "orders-service",
    "billing-service",
    "notification-service",
    "analytics-service",
    "catalog-service",
    "gateway-service",
  ])

  cluster_name    = var.cluster_name
  namespace       = "acmecorp"
  service_account = each.key
  role_arn        = aws_iam_role.app.arn
}

resource "aws_eks_pod_identity_association" "grafana" {
  cluster_name    = var.cluster_name
  namespace       = "observability"
  service_account = "grafana"
  role_arn        = aws_iam_role.observability.arn
}

resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = var.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.eso.arn
}

output "app_role_arn" { value = aws_iam_role.app.arn }
output "observability_role_arn" { value = aws_iam_role.observability.arn }
output "eso_role_arn" { value = aws_iam_role.eso.arn }
