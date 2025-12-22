# EKS Auto Mode Module - Well-Architected: Performance (mixed arch), Cost Optimization (Spot)
# Creates EKS cluster with Auto Mode for serverless node management

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

# EKS Cluster Service Role
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# EKS Cluster with Auto Mode
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn
  
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.environment == "prod" ? false : true
    public_access_cidrs     = var.environment == "prod" ? [] : ["0.0.0.0/0"]
  }
  
  # Auto Mode will be enabled via separate configuration
  
  # Enable Pod Identity for IAM integration
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }
  
  # Encryption at rest for etcd
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }
  
  # Enable logging for observability
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  tags = merge(var.tags, {
    Name = var.cluster_name
  })
  
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.cluster
  ]
}

# KMS key for EKS encryption
resource "aws_kms_key" "eks" {
  description             = "EKS cluster encryption key"
  deletion_window_in_days = 7
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-encryption-key"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-encryption"
  target_key_id = aws_kms_key.eks.key_id
}

# CloudWatch Log Group for EKS logs
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7
  
  tags = var.tags
}

# Note: EKS Auto Mode configuration requires AWS CLI or console setup
# Auto Mode provides serverless node management with mixed architecture support
# This cluster is configured to support Auto Mode when enabled

resource "null_resource" "enable_auto_mode" {
  triggers = {
    cluster_name = aws_eks_cluster.main.name
    region       = var.region
  }

  provisioner "local-exec" {
    command = "aws eks put-cluster-config --name ${aws_eks_cluster.main.name} --region ${var.region} --compute-config enabled=true"
  }

  depends_on = [aws_eks_cluster.main]
}

# OIDC Identity Provider for Pod Identity
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-oidc"
  })
}

# EKS Pod Identity Agent addon
resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "eks-pod-identity-agent"
  
  tags = var.tags

  depends_on = [null_resource.enable_auto_mode]
}

# CoreDNS addon
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  
  tags = var.tags

  depends_on = [null_resource.enable_auto_mode]
}

# kube-proxy addon
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
  
  tags = var.tags

  depends_on = [null_resource.enable_auto_mode]
}

# VPC CNI addon
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  
  tags = var.tags

  depends_on = [null_resource.enable_auto_mode]
}

# EBS CSI Driver addon
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"
  
  tags = var.tags

  depends_on = [null_resource.enable_auto_mode]
}
