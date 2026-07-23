# ML Infrastructure Platform - Main Terraform Configuration
# This file orchestrates the deployment of the complete ML infrastructure

# Local values for subnet selection and validation
locals {
  # Use provided subnet IDs if specified, otherwise use filtered subnets
  selected_subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.existing.ids
}

# Validation to ensure we have at least 2 subnets for high availability
resource "null_resource" "subnet_validation" {
  count = length(local.selected_subnet_ids) >= 2 ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'ERROR: At least 2 subnets are required for high availability. Found: ${length(local.selected_subnet_ids)}' && exit 1"
  }
}

# Data source for existing VPC
data "aws_vpc" "existing" {
  id = var.vpc_id
}

# Data source for existing subnets with tag-based filtering
data "aws_subnets" "existing" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  # Filter subnets by provided subnet IDs if specified
  dynamic "filter" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      name   = "subnet-id"
      values = var.subnet_ids
    }
  }

  # Filter subnets by tags (e.g., private subnets)
  dynamic "filter" {
    for_each = var.subnet_tag_filters
    content {
      name   = "tag:${filter.value.name}"
      values = filter.value.values
    }
  }
}

# Data source to get subnet details for validation
data "aws_subnet" "selected" {
  for_each = toset(data.aws_subnets.existing.ids)
  id       = each.value
}

# EKS Cluster Module
module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_config.cluster_name
  cluster_version = var.cluster_config.cluster_version
  vpc_id          = var.vpc_id
  subnet_ids      = local.selected_subnet_ids

  # IAM role ARNs
  cluster_service_role_arn = module.iam.cluster_service_role_arn
  node_group_role_arn      = module.iam.node_group_role_arn

  # Node group configurations
  cpu_node_config = var.cluster_config.node_groups.cpu_nodes
  gpu_node_config = var.cluster_config.node_groups.gpu_nodes

  # Add-on configurations
  nvidia_operator_enabled = var.cluster_config.addons.nvidia_operator_enabled
  efa_plugin_enabled      = var.cluster_config.addons.efa_plugin_enabled

  # Security and access configuration
  kms_key_arn                   = module.iam.kms_key_arn
  cluster_log_types             = var.cluster_log_types
  log_retention_days            = 30
  enable_public_access          = true
  public_access_cidrs           = ["0.0.0.0/0"]
  additional_security_group_ids = []

  environment     = var.environment
  additional_tags = var.additional_tags

  depends_on = [module.iam]
}

# IAM Module for Security and Access Control (created first for KMS key)
module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_config.cluster_name
  environment  = var.environment
}

# S3 Module for Model Registry
module "s3" {
  source = "./modules/s3"

  environment = var.environment

  # KMS key for encryption
  kms_key_arn = module.iam.kms_key_arn
}