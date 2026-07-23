# EKS Observability Stack - Root Module
# This is the main entry point for the EKS cluster with observability

# Configure AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.default_tags
  }
}

# Data sources for VPC and subnet discovery
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Get all subnets in the VPC
data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

# Get subnet details for filtering
data "aws_subnet" "all" {
  for_each = toset(data.aws_subnets.all.ids)
  id       = each.value
}

# Filter subnets based on subnet_type preference with enhanced validation
locals {
  # Simple subnet classification without complex nested logic
  subnet_classification = {
    for subnet in data.aws_subnet.all : subnet.id => {
      name               = try(subnet.tags["Name"], "")
      is_private_by_flag = !subnet.map_public_ip_on_launch
      availability_zone  = subnet.availability_zone
      cidr_block         = subnet.cidr_block
    }
  }

  # Separate step for name-based classification
  subnet_name_classification = {
    for subnet_id, info in local.subnet_classification : subnet_id => {
      name               = info.name
      is_private_by_name = can(regex(var.subnet_name_patterns.private, info.name))
      is_public_by_name  = can(regex(var.subnet_name_patterns.public, info.name))
      is_private_by_flag = info.is_private_by_flag

      # Final classification: name takes precedence over flag
      is_private = info.name != "" && can(regex(var.subnet_name_patterns.private, info.name)) ? true : (
        info.name != "" && can(regex(var.subnet_name_patterns.public, info.name)) ? false : info.is_private_by_flag
      )

      availability_zone = info.availability_zone
      cidr_block        = info.cidr_block
    }
  }

  # Filter subnets based on classification
  private_subnet_ids = [
    for subnet_id, classification in local.subnet_name_classification : subnet_id
    if var.subnet_type == "private" && classification.is_private
  ]

  public_subnet_ids = [
    for subnet_id, classification in local.subnet_name_classification : subnet_id
    if var.subnet_type == "public" && !classification.is_private
  ]

  # Use explicit subnet_ids if provided, otherwise use filtered subnets
  selected_subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : (
    var.subnet_type == "private" ? local.private_subnet_ids : local.public_subnet_ids
  )

  # Validate we have enough subnets
  subnet_count = length(local.selected_subnet_ids)

  # Create detailed subnet information for debugging
  subnet_details = {
    for subnet_id in local.selected_subnet_ids : subnet_id => merge(
      local.subnet_name_classification[subnet_id],
      {
        subnet_id     = subnet_id
        map_public_ip = data.aws_subnet.all[subnet_id].map_public_ip_on_launch
      }
    )
  }

  # Summary of all discovered subnets for debugging
  all_subnets_summary = {
    for subnet_id, classification in local.subnet_name_classification : subnet_id => {
      name = classification.name
      type = classification.is_private ? "private" : "public"
      az   = classification.availability_zone
      cidr = classification.cidr_block
    }
  }
}

# Validation for subnet availability
resource "null_resource" "subnet_validation" {
  count = local.subnet_count >= var.min_subnet_count ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'ERROR: Not enough subnets found. Check your VPC configuration.' && exit 1"
  }
}

# Data source for EKS cluster authentication
data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_id
}

# Configure Kubernetes Provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Configure Helm Provider
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# EKS Cluster Module
module "eks_cluster" {
  source = "./modules/eks-cluster"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = var.vpc_id
  subnet_ids         = local.selected_subnet_ids

  endpoint_config   = var.endpoint_config
  logging_config    = var.logging_config
  encryption_config = var.encryption_config

  tags = var.default_tags

  depends_on = [null_resource.subnet_validation]
}

# Node Groups Module
module "node_groups" {
  source = "./modules/node-groups"

  cluster_name = module.eks_cluster.cluster_id
  subnet_ids   = local.selected_subnet_ids

  node_groups = var.node_groups

  # Optional remote access configuration
  enable_remote_access             = var.enable_remote_access
  ssh_key_name                     = var.ssh_key_name
  remote_access_security_group_ids = var.remote_access_security_group_ids

  tags = var.default_tags

  depends_on = [module.eks_cluster]
}

# EKS Addons Module
module "addons" {
  source = "./modules/addons"

  cluster_name      = module.eks_cluster.cluster_id
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  oidc_issuer_url   = module.eks_cluster.oidc_issuer_url

  aws_addons  = var.aws_addons
  helm_addons = var.helm_addons

  tags = var.default_tags

  depends_on = [module.node_groups]
}

# Observability Module
module "observability" {
  source = "./modules/observability"

  cluster_name           = module.eks_cluster.cluster_id
  cluster_endpoint       = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = module.eks_cluster.cluster_ca_certificate
  oidc_issuer_url        = module.eks_cluster.oidc_issuer_url

  enable_irsa          = var.enable_irsa
  observability_config = var.observability_config

  tags = var.default_tags

  depends_on = [module.addons]
}