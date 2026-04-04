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
  description = "Optional IAM principal ARN that should receive cluster-admin access to the EKS cluster. Leave empty to derive the current caller's IAM role ARN when Terraform runs under an assumed role."
  type        = string
  default     = ""
}

variable "eks_public_access_cidrs" {
  description = "Explicit IPv4 CIDR blocks allowed to reach the public EKS API endpoint. Leave empty to disable public endpoint access and require private connectivity."
  type        = list(string)
  default     = []
}

variable "eks_secrets_kms_key_arn" {
  description = "Optional existing customer-managed KMS key ARN for EKS Kubernetes secrets envelope encryption. Leave null to let Terraform create and retain the long-lived key."
  type        = string
  default     = null
}

variable "manage_eks_secrets_kms_key" {
  description = "When true, Terraform continues to manage and retain the EKS secrets KMS key and alias. Set false only when intentionally reusing an existing external key ARN."
  type        = bool
  default     = true

  validation {
    condition     = var.manage_eks_secrets_kms_key || var.eks_secrets_kms_key_arn != null
    error_message = "eks_secrets_kms_key_arn must be set when manage_eks_secrets_kms_key is false."
  }
}

variable "eks_database_client_sg_id_override" {
  description = "Optional explicit security group ID to allow Aurora ingress on tcp/5432. Leave null for the normal EKS Auto Mode path, which discovers the runtime EC2 compute security group dynamically. Use only as a break-glass override."
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

variable "enable_aurora" {
  description = "When true, provision Aurora. Aurora ingress defaults to the explicit EKS Auto Mode node security group unless an override is set."
  type        = bool
  default     = true
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

variable "enable_mq" {
  description = "When true, provision Amazon MQ. MQ ingress defaults to the explicit EKS Auto Mode node security group unless an override is set."
  type        = bool
  default     = true
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
  description = "Optional explicit Amazon MQ broker instance type override. Leave null to use the default supported RabbitMQ instance type for the selected deployment mode."
  type        = string
  default     = null
}

variable "mq_username" {
  description = "Amazon MQ admin username"
  type        = string
  default     = "acmecorp"
}

variable "mq_client_sg_id_override" {
  description = "Optional override for MQ ingress SG. Leave null for the normal EKS Auto Mode path, which discovers runtime EC2 compute security groups dynamically. Use only for break-glass debugging."
  type        = string
  default     = null
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

variable "enable_grafana_dns" {
  description = "Enable Route53 record for Grafana"
  type        = bool
  default     = false

  validation {
    condition = (
      var.enable_grafana_dns == false ||
      (var.grafana_alb_dns_name != null && var.grafana_alb_zone_id != null)
    )
    error_message = "grafana_alb_dns_name and grafana_alb_zone_id must be set when enable_grafana_dns = true"
  }
}

variable "aurora_deletion_protection" {
  description = "Enable deletion protection on Aurora cluster"
  type        = bool
  default     = true
}

variable "ui_bucket_name_override" {
  description = "Optional explicit S3 bucket name for the UI static assets. Leave null to derive a globally unique bucket name from the project, environment, account, and region."
  type        = string
  default     = null
}

variable "force_destroy_ui_bucket" {
  description = "When true, allows Terraform destroy to delete the UI S3 bucket even when it still contains objects."
  type        = bool
  default     = false
}

variable "ui_subdomain" {
  description = "UI hostname label created under the public Route53 zone for CloudFront, for example app -> app.example.com."
  type        = string
  default     = "app"
}

variable "ui_build_assets_path" {
  description = "Optional local path to the built UI assets used by deployment workflows. Terraform creates the hosting infrastructure but does not upload files."
  type        = string
  default     = "../../webapp/dist"
}
