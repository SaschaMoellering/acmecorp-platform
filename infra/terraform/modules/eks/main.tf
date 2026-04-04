variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "name_prefix" { type = string }
variable "admin_principal_arn" { type = string }
variable "public_access_cidrs" { type = list(string) }
variable "manage_secrets_kms_key" {
  type    = bool
  default = true
}
variable "secrets_kms_key_arn" {
  type    = string
  default = null
}

# ── Cluster IAM role ────────────────────────────────────────────────────────
data "aws_iam_policy_document" "eks_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Auto Mode requires this additional policy on the cluster role
resource "aws_iam_role_policy_attachment" "cluster_compute_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_block_storage_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_load_balancing_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_networking_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}

# ── Node IAM role (used by Auto Mode managed nodes) ─────────────────────────
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name_prefix}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

locals {
  resolved_secrets_kms_arn = var.manage_secrets_kms_key ? aws_kms_key.eks_secrets[0].arn : var.secrets_kms_key_arn
}

# ── KMS key for Kubernetes secrets envelope encryption ──────────────────────
resource "aws_kms_key" "eks_secrets" {
  count = var.manage_secrets_kms_key ? 1 : 0

  description             = "KMS key for EKS Kubernetes secrets envelope encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  lifecycle {
    # This key is intentionally long-lived so EKS rebuilds can reuse it
    # instead of forcing a dangerous delete-and-recover cycle.
    prevent_destroy = false
  }

  tags = { Name = "${var.name_prefix}-eks-secrets" }
}

resource "aws_kms_alias" "eks_secrets" {
  count = var.manage_secrets_kms_key ? 1 : 0

  name          = "alias/${var.name_prefix}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets[0].key_id

  lifecycle {
    prevent_destroy = false
  }
}

# ── EKS Cluster ─────────────────────────────────────────────────────────────
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.35"

  bootstrap_self_managed_addons = false

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = length(var.public_access_cidrs) > 0
    public_access_cidrs     = var.public_access_cidrs
  }

  # Enable EKS Auto Mode
  compute_config {
    enabled       = true
    node_role_arn = aws_iam_role.node.arn
    node_pools    = ["general-purpose", "system"]
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  encryption_config {
    provider {
      key_arn = local.resolved_secrets_kms_arn
    }
    resources = ["secrets"]
  }

  access_config {
    authentication_mode = "API"
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_compute_policy,
    aws_iam_role_policy_attachment.cluster_block_storage_policy,
    aws_iam_role_policy_attachment.cluster_load_balancing_policy,
    aws_iam_role_policy_attachment.cluster_networking_policy,
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}

resource "aws_eks_access_entry" "admin" {
  count = var.admin_principal_arn != "" ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_cluster_admin" {
  count = var.admin_principal_arn != "" ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}

resource "aws_eks_access_entry" "auto_mode_node_role" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.node.arn
  type          = "EC2"
}

output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "cluster_certificate_authority_data" {
  value     = aws_eks_cluster.this.certificate_authority[0].data
  sensitive = true
}
output "cluster_security_group_id" { value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id }
output "node_role_arn" { value = aws_iam_role.node.arn }
output "oidc_issuer_url" { value = aws_eks_cluster.this.identity[0].oidc[0].issuer }
output "secrets_kms_key_arn" { value = local.resolved_secrets_kms_arn }
output "admin_access_principal_arn" {
  value = var.admin_principal_arn != "" ? var.admin_principal_arn : null
}
