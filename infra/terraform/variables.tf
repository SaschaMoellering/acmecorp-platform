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

variable "eks_public_access_cidrs" {
  description = "Explicit IPv4 CIDR blocks allowed to reach the public EKS API endpoint. Leave empty to disable public endpoint access and require private connectivity."
  type        = list(string)
  default     = []
}

variable "eks_database_client_sg_id_override" {
  description = "Optional explicit EKS data-plane security group ID that should be allowed to reach Aurora on tcp/5432. Use this when the actual worker-node SG differs from the Terraform-managed EKS SG output."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "nat_gateway_mode" {
  description = "NAT gateway topology for the VPC. Use single for lowest recurring cost in demo/dev, ha for one NAT per AZ, or none to disable NAT entirely."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "ha", "none"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be one of: single, ha, none."
  }
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

variable "mq_deployment_mode" {
  description = "Amazon MQ deployment mode. SINGLE_INSTANCE is the lowest-cost option for demo/dev."
  type        = string
  default     = "SINGLE_INSTANCE"

  validation {
    condition = contains([
      "SINGLE_INSTANCE",
      "ACTIVE_STANDBY_MULTI_AZ",
      "CLUSTER_MULTI_AZ",
    ], var.mq_deployment_mode)
    error_message = "mq_deployment_mode must be one of: SINGLE_INSTANCE, ACTIVE_STANDBY_MULTI_AZ, CLUSTER_MULTI_AZ."
  }
}

variable "mq_broker_instance_type" {
  description = "Optional explicit Amazon MQ broker instance type override. Leave null to use the demo-cost default for the selected deployment mode."
  type        = string
  default     = null
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
