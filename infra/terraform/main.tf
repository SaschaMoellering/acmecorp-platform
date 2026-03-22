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

  cluster_name        = var.cluster_name
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  name_prefix         = local.name_prefix
  admin_principal_arn = var.admin_principal_arn
  public_access_cidrs = var.eks_public_access_cidrs
}

module "aurora" {
  source = "./modules/aurora"

  name_prefix               = local.name_prefix
  vpc_id                    = module.vpc.vpc_id
  database_subnet_ids       = module.vpc.database_subnet_ids
  eks_database_client_sg_id = coalesce(var.eks_database_client_sg_id_override, module.eks.node_security_group_id)
  db_name                   = var.aurora_db_name
  master_username           = var.aurora_master_username
  master_password           = module.secrets.aurora_password
  deletion_protection       = var.aurora_deletion_protection
  secret_arn                = module.secrets.aurora_secret_arn
}

module "mq" {
  source = "./modules/mq"

  name_prefix          = local.name_prefix
  broker_name          = var.mq_broker_name
  deployment_mode      = var.mq_deployment_mode
  broker_instance_type = var.mq_broker_instance_type
  mq_username          = var.mq_username
  mq_password          = module.secrets.mq_password
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  eks_node_sg_id       = module.eks.node_security_group_id
  secret_arn           = module.secrets.mq_secret_arn
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
  aurora_cluster_arn = module.aurora.cluster_arn

  depends_on = [module.eks]
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix      = local.name_prefix
  repository_names = local.ecr_repository_names
}

module "acm" {
  source = "./modules/acm"

  name_prefix          = local.name_prefix
  route53_zone_name    = var.route53_zone_name
  gateway_ingress_host = var.gateway_ingress_host
  grafana_ingress_host = var.grafana_ingress_host
}

module "dns" {
  source = "./modules/dns"

  route53_zone_name    = var.route53_zone_name
  gateway_ingress_host = var.gateway_ingress_host
  grafana_ingress_host = var.grafana_ingress_host
  gateway_alb_dns_name = var.gateway_alb_dns_name
  gateway_alb_zone_id  = var.gateway_alb_zone_id
  grafana_alb_dns_name = var.grafana_alb_dns_name
  grafana_alb_zone_id  = var.grafana_alb_zone_id
}

module "ui" {
  source = "./modules/ui"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix          = local.name_prefix
  aws_region           = var.aws_region
  route53_zone_name    = var.route53_zone_name
  ui_subdomain         = var.ui_subdomain
  bucket_name_override = var.ui_bucket_name_override
}
