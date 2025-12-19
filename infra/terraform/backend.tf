terraform {
  backend "s3" {
    # Configure via CLI or environment variables:
    # terraform init -backend-config="bucket=acmecorp-terraform-state-${ENV}"
    # terraform init -backend-config="key=${ENV}/terraform.tfstate"
    # terraform init -backend-config="region=us-west-2"
    # terraform init -backend-config="dynamodb_table=acmecorp-terraform-locks"
  }
}