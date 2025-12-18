# Pod Identity Module - Well-Architected: Security (no IRSA, direct Pod Identity)
# Creates EKS Pod Identity associations for service accounts

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Pod Identity Association for Orders Service
resource "aws_eks_pod_identity_association" "orders_service" {
  cluster_name    = var.cluster_name
  namespace       = "acmecorp"
  service_account = "orders-service"
  role_arn        = var.orders_service_role_arn
  
  tags = {
    Name    = "${var.cluster_name}-orders-service-pod-identity"
    Service = "orders-service"
  }
}

# Pod Identity Association for Catalog Service
resource "aws_eks_pod_identity_association" "catalog_service" {
  cluster_name    = var.cluster_name
  namespace       = "acmecorp"
  service_account = "catalog-service"
  role_arn        = var.catalog_service_role_arn
  
  tags = {
    Name    = "${var.cluster_name}-catalog-service-pod-identity"
    Service = "catalog-service"
  }
}

# Pod Identity Association for Gateway Service
resource "aws_eks_pod_identity_association" "gateway_service" {
  cluster_name    = var.cluster_name
  namespace       = "acmecorp"
  service_account = "gateway-service"
  role_arn        = var.gateway_service_role_arn
  
  tags = {
    Name    = "${var.cluster_name}-gateway-service-pod-identity"
    Service = "gateway-service"
  }
}