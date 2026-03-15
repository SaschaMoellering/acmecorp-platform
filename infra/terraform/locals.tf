locals {
  name_prefix = "${var.cluster_name}-${var.environment}"

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnet_cidrs  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnet_cidrs   = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 4)]
  database_subnet_cidrs = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
