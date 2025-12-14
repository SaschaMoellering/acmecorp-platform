# Staging Environment Configuration
# Well-Architected: Reliability (production-like setup), Security (isolated network)

terraform {
  # Configure backend for state management
  # backend "s3" {
  #   bucket = "acmecorp-terraform-state-staging"
  #   key    = "staging/terraform.tfstate"
  #   region = "us-west-2"
  # }
}

# Use parent module
module "acmecorp_platform" {
  source = "../.."
  
  # Environment-specific variables loaded from terraform.tfvars
}