# Development Environment Configuration
# Well-Architected: Cost Optimization (smaller instances, single AZ for non-critical resources)

terraform {
  # Configure backend for state management
  # backend "s3" {
  #   bucket = "acmecorp-terraform-state-dev"
  #   key    = "dev/terraform.tfstate"
  #   region = "us-west-2"
  # }
}

# Use parent module
module "acmecorp_platform" {
  source = "../.."
  
  # Environment-specific variables loaded from terraform.tfvars
}