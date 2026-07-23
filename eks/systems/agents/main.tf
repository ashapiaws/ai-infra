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
# Agent Runtime
#
# Tools and infrastructure for running autonomous AI agents:
#   - Message queues for async agent communication
#   - State stores for agent memory/context
#   - Tool registries (MCP servers, function calling endpoints)
################################################################################

module "redis" {
  source = "./modules/redis"
  count  = var.enable_redis ? 1 : 0

  chart_version = var.redis_version
  tags          = var.tags
}

module "temporal" {
  source = "./modules/temporal"
  count  = var.enable_temporal ? 1 : 0

  chart_version = var.temporal_version
  tags          = var.tags
}

module "mcp_gateway" {
  source = "./modules/mcp-gateway"
  count  = var.enable_mcp_gateway ? 1 : 0

  chart_version = var.mcp_gateway_version
  tags          = var.tags
}
