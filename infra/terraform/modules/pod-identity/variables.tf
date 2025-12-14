variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "orders_service_role_arn" {
  description = "Orders service IAM role ARN"
  type        = string
}

variable "catalog_service_role_arn" {
  description = "Catalog service IAM role ARN"
  type        = string
}

variable "gateway_service_role_arn" {
  description = "Gateway service IAM role ARN"
  type        = string
}