variable "environment" {
  description = "Environment name"
  type        = string
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
}

variable "eks_budget_limit" {
  description = "EKS monthly budget limit in USD"
  type        = string
}

variable "alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
}

