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

variable "aurora_deletion_protection" {
  description = "Enable deletion protection on Aurora cluster"
  type        = bool
  default     = true
}
