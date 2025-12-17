# Data sources for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use provided AZs or default to first 3 available
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)
  
  cluster_name = "${var.cluster_name}-${var.environment}"
  
  common_tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = "acmecorp-platform"
  }
}

# VPC Module - Well-Architected: Security, Reliability
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr           = var.vpc_cidr
  availability_zones = local.azs
  environment        = var.environment
  
  tags = local.common_tags
}

# EKS Auto Mode Module - Well-Architected: Performance, Cost Optimization
module "eks" {
  source = "./modules/eks-auto"
  
  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  environment        = var.environment
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# Aurora PostgreSQL Module - Well-Architected: Security, Reliability
module "aurora" {
  source = "./modules/aurora-postgres"
  
  cluster_name = "${local.cluster_name}-aurora"
  database_name = var.db_name
  username      = var.db_username
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.private_subnet_ids
  vpc_cidr      = var.vpc_cidr
  environment   = var.environment
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# IAM Roles Module - Well-Architected: Security
module "iam" {
  source = "./modules/iam"
  
  cluster_name          = local.cluster_name
  cluster_oidc_issuer   = module.eks.cluster_oidc_issuer_url
  aurora_resource_id    = module.aurora.resource_id
  db_username           = var.db_username
  environment           = var.environment
  
  tags = local.common_tags
  
  depends_on = [module.eks, module.aurora]
}

# Pod Identity Module - Well-Architected: Security
module "pod_identity" {
  source = "./modules/pod-identity"
  
  cluster_name           = local.cluster_name
  orders_service_role_arn = module.iam.orders_service_role_arn
  catalog_service_role_arn = module.iam.catalog_service_role_arn
  gateway_service_role_arn = module.iam.gateway_service_role_arn
  
  depends_on = [module.eks, module.iam]
}

# S3 Frontend Module - Well-Architected: Security, Performance
module "s3_frontend" {
  source = "./modules/s3-frontend"
  
  bucket_name = "${local.cluster_name}-frontend"
  environment = var.environment
  
  tags = local.common_tags
}

# ElastiCache Redis Module - Well-Architected: Performance, Reliability
module "elasticache" {
  source = "./modules/elasticache"
  
  cluster_name = local.cluster_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  vpc_cidr     = var.vpc_cidr
  environment  = var.environment
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# CloudFront Module - Well-Architected: Performance, Security
module "cloudfront" {
  source = "./modules/cloudfront"
  
  bucket_name     = module.s3_frontend.bucket_name
  bucket_domain   = module.s3_frontend.bucket_domain_name
  domain_name     = var.frontend_domain
  environment     = var.environment
  
  tags = local.common_tags
  
  depends_on = [module.s3_frontend]
}

# Cost Monitoring Module - Well-Architected: Cost Optimization
module "cost_monitoring" {
  source = "./modules/cost-monitoring"
  
  environment          = var.environment
  monthly_budget_limit = var.monthly_budget_limit
  eks_budget_limit     = var.eks_budget_limit
  alert_emails         = var.budget_alert_emails
  
  tags = local.common_tags
}

# Update S3 bucket policy after CloudFront is created
resource "aws_s3_bucket_policy" "frontend_cloudfront" {
  bucket = module.s3_frontend.bucket_name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.s3_frontend.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront.distribution_arn
          }
        }
      }
    ]
  })
  
  depends_on = [module.s3_frontend, module.cloudfront]
}