terraform {
  backend "s3" {
    bucket         = "acme-corp-s3-tf"
    key            = "acmecorp-platform/prod/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "acme-corp-terraform-locks"
  }
}