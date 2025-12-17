# Cost Monitoring Module - Well-Architected: Cost Optimization
# Creates budgets and cost alerts for AWS spending control

# Monthly budget with alerts
resource "aws_budgets_budget" "monthly" {
  name         = "${var.environment}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  cost_filters = {
    Tag = {
      "Environment" = [var.environment]
    }
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
  }
}

# Service-specific budget for EKS
resource "aws_budgets_budget" "eks" {
  name         = "${var.environment}-eks-budget"
  budget_type  = "COST"
  limit_amount = var.eks_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  cost_filters = {
    Service = ["Amazon Elastic Kubernetes Service"]
    Tag = {
      "Environment" = [var.environment]
    }
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 90
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }
}