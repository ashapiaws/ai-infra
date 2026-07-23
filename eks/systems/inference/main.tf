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
# Tier 1: Ingress Gateway
#
# Responsibilities:
#   - API authentication & key validation
#   - Model name → backend resolution
#   - Rate limiting (per-tenant, per-model token budgets)
#   - Request routing to Tier 2 backends
################################################################################

module "kgateway" {
  source = "./modules/tier1-gateway/kgateway"
  count  = var.enable_kgateway ? 1 : 0

  chart_version = var.kgateway_version
  tags          = var.tags
}

module "envoy_ai_gateway" {
  source = "./modules/tier1-gateway/envoy-ai-gateway"
  count  = var.enable_envoy_ai_gateway ? 1 : 0

  chart_version      = var.envoy_ai_gateway_version
  enable_rate_limiting = var.enable_rate_limiting
  rate_limit_rps     = var.rate_limit_rps
  inference_router   = var.inference_router
  bedrock_routing    = var.enable_bedrock_routing
  bedrock_models     = var.bedrock_models
  tags               = var.tags

  depends_on = [module.kgateway]
}

################################################################################
# Tier 2: Inference Backends
#
# Self-hosted engines (vLLM, SGLang) running on GPU nodes.
# Bedrock routing is handled at Tier 1 config level — no infra needed here.
################################################################################

module "nvidia_operator" {
  source = "./modules/tier2-backends/nvidia-operator"
  count  = var.enable_nvidia_operator ? 1 : 0

  chart_version = var.nvidia_operator_version
  tags          = var.tags
}

module "vllm" {
  source = "./modules/tier2-backends/vllm"
  count  = var.enable_vllm ? 1 : 0

  chart_version = var.vllm_version
  model_name    = var.vllm_model_name
  model_url     = var.vllm_model_url
  hf_token      = var.hf_token
  gpu_count     = var.vllm_gpu_count
  tags          = var.tags

  depends_on = [module.nvidia_operator]
}

module "sglang" {
  source = "./modules/tier2-backends/sglang"
  count  = var.enable_sglang ? 1 : 0

  chart_version = var.sglang_version
  tags          = var.tags

  depends_on = [module.nvidia_operator]
}

################################################################################
# Tier 3: Model Serving Orchestration (optional)
#
# Higher-level abstractions for model lifecycle, autoscaling, canary rollouts.
# These sit on top of Tier 1 + Tier 2.
################################################################################

module "kserve" {
  source = "./modules/tier3-serving/kserve"
  count  = var.enable_kserve ? 1 : 0

  chart_version    = var.kserve_version
  inference_router = var.inference_router
  tags             = var.tags

  depends_on = [module.envoy_ai_gateway, module.vllm, module.sglang]
}

module "bifrost" {
  source = "./modules/tier3-serving/bifrost"
  count  = var.enable_bifrost ? 1 : 0

  chart_version    = var.bifrost_version
  inference_router = var.inference_router
  tags             = var.tags

  depends_on = [module.envoy_ai_gateway, module.vllm, module.sglang]
}
