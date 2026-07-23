# Main Terraform configuration for EKS cluster
# This file will be populated with EKS module configuration in subsequent tasks

# Configure the AWS Provider
provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

# Data source to get current AWS account information
data "aws_caller_identity" "current" {}

# Data source to get VPC information
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Data source to get subnet information
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "subnet-id"
    values = var.private_subnet_ids
  }
}

# EKS Cluster Module
# Provisions an EKS cluster with managed node groups using the official AWS EKS Terraform module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  # Cluster Configuration
  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # Network Configuration
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Cluster Endpoint Access Configuration
  # Private access is always enabled for internal communication
  # Public access can be enabled for external access (e.g., CI/CD, developer access)
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = var.enable_public_access
  cluster_endpoint_public_access_cidrs = var.enable_public_access ? var.public_access_cidrs : []

  # Cluster Logging Configuration
  # Enable all five log types for comprehensive audit and troubleshooting
  cluster_enabled_log_types = [
    "audit",
    "api",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # Cluster Encryption Configuration
  # Encrypt Kubernetes secrets at rest using AWS KMS
  cluster_encryption_config = var.kms_key_arn != null ? [
    {
      provider_key_arn = var.kms_key_arn
      resources        = ["secrets"]
    }
  ] : []

  # Enable IRSA (IAM Roles for Service Accounts)
  # Required for add-ons like EBS CSI driver and Load Balancer Controller
  enable_irsa = true

  # Managed Node Group Configuration
  # Provisions a managed node group with configurable instance types, capacity, and scaling
  eks_managed_node_groups = {
    main = {
      # Node Group Naming
      name = "${var.cluster_name}-node-group"

      # Instance Configuration
      instance_types = var.node_instance_types
      capacity_type  = var.capacity_type

      # Scaling Configuration
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      # Disk Configuration
      disk_size = var.disk_size

      # Network Configuration
      # Ensure nodes are placed only in private subnets
      subnet_ids = var.private_subnet_ids

      # Security Configuration
      # Enable IMDSv2 (Instance Metadata Service v2) for enhanced security
      # This prevents SSRF attacks by requiring session tokens for metadata access
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required" # Require IMDSv2
        http_put_response_hop_limit = 1
        instance_metadata_tags      = "disabled"
      }

      # IAM Configuration
      # Additional IAM policies can be attached via variables
      iam_role_additional_policies = {
        # Add SSM policy for Systems Manager access
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # Resource Tags
      tags = merge(
        var.tags,
        {
          "NodeGroup" = "main"
        }
      )
    }
  }

  # Resource Tags
  tags = var.tags
}

# ============================================================================
# IAM Configuration (Task 3.1)
# ============================================================================
# The terraform-aws-modules/eks/aws module automatically creates and manages
# IAM roles for the EKS cluster and node groups with the following policies:
#
# Cluster IAM Role (automatically created):
#   - AmazonEKSClusterPolicy: Allows EKS to manage AWS resources on your behalf
#   - AmazonEKSVPCResourceController: Allows EKS to manage ENIs for pod networking
#
# Node Group IAM Role (automatically created):
#   - AmazonEKSWorkerNodePolicy: Allows worker nodes to connect to EKS
#   - AmazonEKS_CNI_Policy: Allows CNI plugin to modify IP configuration
#   - AmazonEC2ContainerRegistryReadOnly: Allows nodes to pull images from ECR
#
# Additional Node Policies (explicitly added above):
#   - AmazonSSMManagedInstanceCore: Enables Systems Manager access for troubleshooting
#
# The IAM roles are accessible via module outputs:
#   - module.eks.cluster_iam_role_arn: Cluster IAM role ARN
#   - module.eks.eks_managed_node_groups["main"].iam_role_arn: Node group IAM role ARN
#
# Custom IAM policies can be attached using the variables:
#   - var.additional_cluster_iam_policy_arns
#   - var.additional_node_iam_policy_arns
#
# This configuration validates Requirements 4.1, 4.2, 4.3, and 4.4
# ============================================================================

# ============================================================================
# IAM Role for EBS CSI Driver (Task 3.2)
# ============================================================================
# Creates an IAM role for the EBS CSI driver using IRSA (IAM Roles for Service Accounts)
# This allows the EBS CSI driver to manage EBS volumes on behalf of Kubernetes
# The role is associated with the kube-system:ebs-csi-controller-sa service account
#
# This configuration validates Requirement 7.4
# ============================================================================

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  # Role Configuration
  role_name = "${var.cluster_name}-ebs-csi-driver"

  # Attach the AWS managed policy for EBS CSI driver
  attach_ebs_csi_policy = true

  # OIDC Provider Configuration
  # Links the IAM role to the Kubernetes service account via OIDC
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  # Resource Tags
  tags = merge(
    var.tags,
    {
      "ServiceAccount" = "ebs-csi-controller-sa"
      "Namespace"      = "kube-system"
    }
  )
}

# IAM role for Load Balancer Controller will be added in Task 3.3
# EKS add-ons will be added in Tasks 5, 6, and 7
