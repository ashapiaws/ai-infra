################################################################################
# Data Sources
################################################################################

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

################################################################################
# Provider Configuration
################################################################################

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

################################################################################
# GPU Infrastructure (shared dependency with inference)
################################################################################

module "nvidia_operator" {
  source = "./modules/nvidia-operator"
  count  = var.enable_nvidia_operator ? 1 : 0

  chart_version = var.nvidia_operator_version
  tags          = var.tags
}

################################################################################
# Batch Scheduling
################################################################################

module "volcano" {
  source = "./modules/volcano"
  count  = var.enable_volcano ? 1 : 0

  chart_version = var.volcano_version
  tags          = var.tags
}

################################################################################
# Distributed Compute
################################################################################

module "kuberay" {
  source = "./modules/kuberay"
  count  = var.enable_kuberay ? 1 : 0

  chart_version = var.kuberay_version
  tags          = var.tags

  depends_on = [module.nvidia_operator]
}

################################################################################
# Workflow Orchestration
################################################################################

module "flyte" {
  source = "./modules/flyte"
  count  = var.enable_flyte ? 1 : 0

  chart_version = var.flyte_version
  cluster_name  = var.cluster_name
  tags          = var.tags
}
