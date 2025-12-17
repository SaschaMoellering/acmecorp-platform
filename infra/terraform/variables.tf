variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "owner" {
  description = "Resource owner for tagging"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "acmecorp"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for VPC subnets"
  type        = list(string)
  default     = []
}

variable "db_name" {
  description = "Aurora PostgreSQL database name"
  type        = string
  default     = "acmecorp"
}

variable "db_username" {
  description = "Aurora PostgreSQL IAM username"
  type        = string
  default     = "iam_user"
}

variable "frontend_domain" {
  description = "Domain for frontend CloudFront distribution"
  type        = string
  default     = ""
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "500"
}

variable "eks_budget_limit" {
  description = "EKS monthly budget limit in USD"
  type        = string
  default     = "200"
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
  default     = ["admin@acmecorp.example.com"]
}