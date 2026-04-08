locals {
  caller_arn_parts                 = split(":", data.aws_caller_identity.current.arn)
  caller_resource                  = length(local.caller_arn_parts) > 5 ? local.caller_arn_parts[5] : ""
  caller_resource_parts            = split("/", local.caller_resource)
  caller_assumed_role_name_parts   = length(local.caller_resource_parts) > 2 && local.caller_resource_parts[0] == "assumed-role" ? slice(local.caller_resource_parts, 1, length(local.caller_resource_parts) - 1) : []
  default_admin_principal_arn      = local.caller_resource_parts[0] == "assumed-role" ? format("arn:aws:iam::%s:role/%s", data.aws_caller_identity.current.account_id, join("/", local.caller_assumed_role_name_parts)) : data.aws_caller_identity.current.arn
  resolved_admin_principal_arn     = var.admin_principal_arn != "" ? var.admin_principal_arn : local.default_admin_principal_arn
  public_hosted_zone_name          = coalesce(var.public_hosted_zone_name, var.route53_zone_name, "acmecorp.example.com")
  eks_auto_mode_security_group_ids = [module.eks.cluster_security_group_id]

  aurora_ingress_source_security_group_ids = var.eks_database_client_sg_id_override != null ? [
    var.eks_database_client_sg_id_override,
  ] : local.eks_auto_mode_security_group_ids

  mq_ingress_source_security_group_ids = var.mq_client_sg_id_override != null ? [
    var.mq_client_sg_id_override,
  ] : local.eks_auto_mode_security_group_ids
}

check "eks_auto_mode_security_group_found" {
  assert {
    condition     = !var.enable_aurora || var.eks_database_client_sg_id_override != null || length(local.eks_auto_mode_security_group_ids) > 0
    error_message = "Aurora ingress could not resolve the EKS cluster security group for cluster ${var.cluster_name}. Ensure the cluster security group exists, or set eks_database_client_sg_id_override only as a break-glass override."
  }
}

check "aurora_ingress_source_security_groups_found" {
  assert {
    condition     = !var.enable_aurora || length(local.aurora_ingress_source_security_group_ids) > 0
    error_message = "Aurora ingress could not resolve any EKS Auto Mode cluster security groups for cluster ${var.cluster_name}. Ensure the cluster security group exists, or set eks_database_client_sg_id_override only as a break-glass override."
  }
}

check "aurora_ingress_source_security_groups_are_distinct" {
  assert {
    condition     = !var.enable_aurora || length(local.aurora_ingress_source_security_group_ids) == length(distinct(local.aurora_ingress_source_security_group_ids))
    error_message = "Aurora ingress resolved duplicate EKS Auto Mode cluster security groups. The final list must be distinct before creating ingress rules."
  }
}

check "mq_runtime_security_groups_found" {
  assert {
    condition     = !var.enable_mq || length(local.mq_ingress_source_security_group_ids) > 0
    error_message = "Amazon MQ ingress could not resolve any EKS Auto Mode cluster security groups for cluster ${var.cluster_name}. Ensure the cluster security group exists, or set mq_client_sg_id_override only as a break-glass override."
  }
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix           = local.name_prefix
  vpc_cidr              = var.vpc_cidr
  nat_gateway_mode      = var.nat_gateway_mode
  azs                   = local.azs
  private_subnet_cidrs  = local.private_subnet_cidrs
  public_subnet_cidrs   = local.public_subnet_cidrs
  database_subnet_cidrs = local.database_subnet_cidrs
  cluster_name          = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  cluster_name           = var.cluster_name
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  name_prefix            = local.name_prefix
  admin_principal_arn    = local.resolved_admin_principal_arn
  public_access_cidrs    = var.eks_public_access_cidrs
  manage_secrets_kms_key = var.manage_eks_secrets_kms_key
  secrets_kms_key_arn    = var.eks_secrets_kms_key_arn
}

module "aurora" {
  count  = var.enable_aurora ? 1 : 0
  source = "./modules/aurora"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  database_subnet_ids        = module.vpc.database_subnet_ids
  eks_database_client_sg_ids = local.aurora_ingress_source_security_group_ids
  db_name                    = var.aurora_db_name
  master_username            = var.aurora_master_username
  master_password            = module.secrets.aurora_password
  deletion_protection        = var.aurora_deletion_protection
  secret_arn                 = module.secrets.aurora_secret_arn
}

module "mq" {
  count  = var.enable_mq ? 1 : 0
  source = "./modules/mq"

  name_prefix                  = local.name_prefix
  broker_name                  = var.mq_broker_name
  deployment_mode              = var.mq_deployment_mode
  broker_instance_type         = var.mq_broker_instance_type
  mq_username                  = var.mq_username
  mq_password                  = module.secrets.mq_password
  vpc_id                       = module.vpc.vpc_id
  private_subnet_ids           = module.vpc.private_subnet_ids
  mq_client_security_group_ids = local.mq_ingress_source_security_group_ids
  secret_arn                   = module.secrets.mq_secret_arn
}

module "secrets" {
  source = "./modules/secrets"

  name_prefix            = local.name_prefix
  aurora_master_username = var.aurora_master_username
  mq_username            = var.mq_username
}

module "iam" {
  source = "./modules/iam"

  name_prefix        = local.name_prefix
  cluster_name       = module.eks.cluster_name
  aws_region         = var.aws_region
  account_id         = data.aws_caller_identity.current.account_id
  aurora_secret_arn  = module.secrets.aurora_secret_arn
  mq_secret_arn      = module.secrets.mq_secret_arn
  redis_secret_arn   = module.secrets.redis_secret_arn
  grafana_secret_arn = module.secrets.grafana_secret_arn
  aurora_cluster_arn = try(module.aurora[0].cluster_arn, null)

  depends_on = [module.eks]
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix      = local.name_prefix
  repository_names = local.ecr_repository_names
}

module "acm" {
  source = "./modules/acm"

  name_prefix             = local.name_prefix
  public_hosted_zone_name = local.public_hosted_zone_name
  gateway_ingress_host    = var.gateway_ingress_host
  grafana_ingress_host    = var.grafana_ingress_host
}

module "dns" {
  source = "./modules/dns"

  public_hosted_zone_name = local.public_hosted_zone_name
  gateway_ingress_host    = var.gateway_ingress_host
  grafana_ingress_host    = var.grafana_ingress_host
  gateway_alb_dns_name    = var.gateway_alb_dns_name
  gateway_alb_zone_id     = var.gateway_alb_zone_id
  enable_grafana_dns      = var.enable_grafana_dns
  grafana_alb_dns_name    = var.grafana_alb_dns_name
  grafana_alb_zone_id     = var.grafana_alb_zone_id
}

module "ui" {
  source = "./modules/ui"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix             = local.name_prefix
  aws_region              = var.aws_region
  public_hosted_zone_name = local.public_hosted_zone_name
  ui_subdomain            = var.ui_subdomain
  bucket_name_override    = var.ui_bucket_name_override
  force_destroy_bucket    = var.force_destroy_ui_bucket
}
