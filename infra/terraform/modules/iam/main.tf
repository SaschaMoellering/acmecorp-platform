# IAM Module - Well-Architected: Security (least privilege, no static credentials)
# Creates IAM roles for EKS Pod Identity with minimal required permissions

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Trust policy for Pod Identity
locals {
  pod_identity_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
  
  # RDS connect policy for database access
  rds_connect_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "rds-db:connect"
        Resource = "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${var.aurora_resource_id}/${var.db_username}"
      }
    ]
  })
}

# Orders Service IAM Role
resource "aws_iam_role" "orders_service" {
  name               = "${var.cluster_name}-orders-service-role"
  assume_role_policy = local.pod_identity_trust_policy
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-orders-service-role"
    Service = "orders-service"
  })
}

resource "aws_iam_policy" "orders_service_rds" {
  name   = "${var.cluster_name}-orders-service-rds-policy"
  policy = local.rds_connect_policy
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "orders_service_rds" {
  role       = aws_iam_role.orders_service.name
  policy_arn = aws_iam_policy.orders_service_rds.arn
}

# CloudWatch Logs policy for orders service
resource "aws_iam_policy" "orders_service_logs" {
  name = "${var.cluster_name}-orders-service-logs-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/orders-service*"
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "orders_service_logs" {
  role       = aws_iam_role.orders_service.name
  policy_arn = aws_iam_policy.orders_service_logs.arn
}

# Catalog Service IAM Role
resource "aws_iam_role" "catalog_service" {
  name               = "${var.cluster_name}-catalog-service-role"
  assume_role_policy = local.pod_identity_trust_policy
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-catalog-service-role"
    Service = "catalog-service"
  })
}

resource "aws_iam_policy" "catalog_service_rds" {
  name   = "${var.cluster_name}-catalog-service-rds-policy"
  policy = local.rds_connect_policy
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "catalog_service_rds" {
  role       = aws_iam_role.catalog_service.name
  policy_arn = aws_iam_policy.catalog_service_rds.arn
}

# CloudWatch Logs policy for catalog service
resource "aws_iam_policy" "catalog_service_logs" {
  name = "${var.cluster_name}-catalog-service-logs-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/catalog-service*"
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "catalog_service_logs" {
  role       = aws_iam_role.catalog_service.name
  policy_arn = aws_iam_policy.catalog_service_logs.arn
}

# Gateway Service IAM Role (minimal permissions)
resource "aws_iam_role" "gateway_service" {
  name               = "${var.cluster_name}-gateway-service-role"
  assume_role_policy = local.pod_identity_trust_policy
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-gateway-service-role"
    Service = "gateway-service"
  })
}

# CloudWatch Logs policy for gateway service
resource "aws_iam_policy" "gateway_service_logs" {
  name = "${var.cluster_name}-gateway-service-logs-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/gateway-service*"
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "gateway_service_logs" {
  role       = aws_iam_role.gateway_service.name
  policy_arn = aws_iam_policy.gateway_service_logs.arn
}

# Billing Service IAM Role
resource "aws_iam_role" "billing_service" {
  name               = "${var.cluster_name}-billing-service-role"
  assume_role_policy = local.pod_identity_trust_policy
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-billing-service-role"
    Service = "billing-service"
  })
}

# CloudWatch Logs policy for billing service
resource "aws_iam_policy" "billing_service_logs" {
  name = "${var.cluster_name}-billing-service-logs-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/billing-service*"
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "billing_service_logs" {
  role       = aws_iam_role.billing_service.name
  policy_arn = aws_iam_policy.billing_service_logs.arn
}

# Notification Service IAM Role
resource "aws_iam_role" "notification_service" {
  name               = "${var.cluster_name}-notification-service-role"
  assume_role_policy = local.pod_identity_trust_policy
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-notification-service-role"
    Service = "notification-service"
  })
}

# CloudWatch Logs policy for notification service
resource "aws_iam_policy" "notification_service_logs" {
  name = "${var.cluster_name}-notification-service-logs-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/notification-service*"
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "notification_service_logs" {
  role       = aws_iam_role.notification_service.name
  policy_arn = aws_iam_policy.notification_service_logs.arn
}

# Analytics Service IAM Role
resource "aws_iam_role" "analytics_service" {
  name               = "${var.cluster_name}-analytics-service-role"
  assume_role_policy = local.pod_identity_trust_policy
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-analytics-service-role"
    Service = "analytics-service"
  })
}

# CloudWatch Logs policy for analytics service
resource "aws_iam_policy" "analytics_service_logs" {
  name = "${var.cluster_name}-analytics-service-logs-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/analytics-service*"
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "analytics_service_logs" {
  role       = aws_iam_role.analytics_service.name
  policy_arn = aws_iam_policy.analytics_service_logs.arn
}