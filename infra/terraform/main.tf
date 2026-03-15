module "vpc" {
  source = "./modules/vpc"

  name_prefix           = local.name_prefix
  vpc_cidr              = var.vpc_cidr
  azs                   = local.azs
  private_subnet_cidrs  = local.private_subnet_cidrs
  public_subnet_cidrs   = local.public_subnet_cidrs
  database_subnet_cidrs = local.database_subnet_cidrs
  cluster_name          = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  name_prefix        = local.name_prefix
}

module "aurora" {
  source = "./modules/aurora"

  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  database_subnet_ids    = module.vpc.database_subnet_ids
  eks_node_sg_id         = module.eks.node_security_group_id
  db_name                = var.aurora_db_name
  master_username        = var.aurora_master_username
  deletion_protection    = var.aurora_deletion_protection
  secret_arn             = module.secrets.aurora_secret_arn
}

module "mq" {
  source = "./modules/mq"

  name_prefix         = local.name_prefix
  broker_name         = var.mq_broker_name
  mq_username         = var.mq_username
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  eks_node_sg_id      = module.eks.node_security_group_id
  secret_arn          = module.secrets.mq_secret_arn
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
  cluster_name       = var.cluster_name
  aws_region         = var.aws_region
  account_id         = data.aws_caller_identity.current.account_id
  aurora_secret_arn  = module.secrets.aurora_secret_arn
  mq_secret_arn      = module.secrets.mq_secret_arn
  redis_secret_arn   = module.secrets.redis_secret_arn
  grafana_secret_arn = module.secrets.grafana_secret_arn
  aurora_cluster_arn = module.aurora.cluster_arn
}
