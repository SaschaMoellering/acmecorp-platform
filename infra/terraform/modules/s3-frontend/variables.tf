variable "bucket_name" {
  description = "S3 bucket name for frontend"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}



variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}