# Production Environment Configuration
# Well-Architected: All pillars (security, reliability, performance, cost optimization, operational excellence)

terraform {
  required_version = ">= 1.0"
  # Configure backend for state management
  # backend "s3" {
  #   bucket = "acmecorp-terraform-state-prod"
  #   key    = "prod/terraform.tfstate"
  #   region = "us-west-2"
  # }
}

# Use parent module
module "acmecorp_platform" {
  source = "../.."
  
  # Environment-specific variables loaded from terraform.tfvars
}