variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (e.g. prod, staging)"
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "acmecorp-platform"
}

variable "admin_principal_arn" {
  description = "IAM principal ARN that should receive explicit first-admin access to the EKS cluster"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aurora_db_name" {
  description = "Initial database name for Aurora"
  type        = string
  default     = "acmecorp"
}

variable "aurora_master_username" {
  description = "Master username for Aurora"
  type        = string
  default     = "acmecorp"
}

variable "mq_broker_name" {
  description = "Amazon MQ broker name"
  type        = string
  default     = "acmecorp-mq"
}

variable "mq_username" {
  description = "Amazon MQ admin username"
  type        = string
  default     = "acmecorp"
}

variable "grafana_ingress_host" {
  description = "Public hostname for Grafana Ingress"
  type        = string
  default     = "grafana.acmecorp.example.com"
}

variable "gateway_ingress_host" {
  description = "Public hostname for the gateway Ingress"
  type        = string
  default     = "api.acmecorp.example.com"
}

variable "route53_zone_name" {
  description = "Public Route53 hosted zone name used for ACM validation and ingress DNS records"
  type        = string
  default     = "acmecorp.example.com"
}

variable "gateway_alb_dns_name" {
  description = "Optional ALB DNS name for the gateway Ingress; when set with gateway_alb_zone_id, Terraform creates the Route53 alias"
  type        = string
  default     = null
}

variable "gateway_alb_zone_id" {
  description = "Optional ALB hosted zone ID for the gateway Ingress; when set with gateway_alb_dns_name, Terraform creates the Route53 alias"
  type        = string
  default     = null
}

variable "grafana_alb_dns_name" {
  description = "Optional ALB DNS name for the Grafana Ingress; when set with grafana_alb_zone_id, Terraform creates the Route53 alias"
  type        = string
  default     = null
}

variable "grafana_alb_zone_id" {
  description = "Optional ALB hosted zone ID for the Grafana Ingress; when set with grafana_alb_dns_name, Terraform creates the Route53 alias"
  type        = string
  default     = null
}

variable "aurora_deletion_protection" {
  description = "Enable deletion protection on Aurora cluster"
  type        = bool
  default     = true
}
