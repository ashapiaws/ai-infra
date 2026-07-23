# EKS Cluster Module - Simplified
# Creates EKS cluster using AWS managed resources

# Data source for existing VPC
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# KMS key for EKS cluster encryption (optional)
resource "aws_kms_key" "eks" {
  count = var.encryption_config.kms_key_id == "" && length(var.encryption_config.resources) > 0 ? 1 : 0

  description             = "EKS cluster encryption key for ${var.cluster_name}"
  deletion_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-eks-encryption-key"
  })
}

resource "aws_kms_alias" "eks" {
  count = var.encryption_config.kms_key_id == "" && length(var.encryption_config.resources) > 0 ? 1 : 0

  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks[0].key_id
}

# IAM role for EKS cluster
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

# Attach EKS cluster policy
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# CloudWatch log group for EKS cluster logs
resource "aws_cloudwatch_log_group" "cluster" {
  count = length(var.logging_config.enable_types) > 0 ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.logging_config.retention_days

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-logs"
  })
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_config.private_access
    endpoint_public_access  = var.endpoint_config.public_access
    public_access_cidrs     = var.endpoint_config.public_access_cidrs
  }

  # Enable cluster logging
  enabled_cluster_log_types = var.logging_config.enable_types

  # Encryption configuration
  dynamic "encryption_config" {
    for_each = length(var.encryption_config.resources) > 0 ? [1] : []
    content {
      provider {
        key_arn = var.encryption_config.kms_key_id != "" ? var.encryption_config.kms_key_id : aws_kms_key.eks[0].arn
      }
      resources = var.encryption_config.resources
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.cluster
  ]
}

# OIDC Identity Provider
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-oidc-provider"
  })
}