variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "aurora_resource_id" {
  description = "Aurora cluster resource ID"
  type        = string
}

variable "db_username" {
  description = "Database username for IAM authentication"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}