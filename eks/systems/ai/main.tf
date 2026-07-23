################################################################################
# Data Sources - Dynamically fetch cluster details
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
# Layer 1: GPU Infrastructure
################################################################################

module "nvidia_operator" {
  source = "./modules/nvidia-operator"
  count  = var.enable_nvidia_operator ? 1 : 0

  chart_version = var.nvidia_operator_version
  tags          = var.tags
}

################################################################################
# Layer 2: Scheduling & Orchestration
################################################################################

module "volcano" {
  source = "./modules/volcano"
  count  = var.enable_volcano ? 1 : 0

  chart_version = var.volcano_version
  tags          = var.tags
}

module "kuberay" {
  source = "./modules/kuberay"
  count  = var.enable_kuberay ? 1 : 0

  chart_version = var.kuberay_version
  tags          = var.tags

  depends_on = [module.nvidia_operator]
}

module "flyte" {
  source = "./modules/flyte"
  count  = var.enable_flyte ? 1 : 0

  chart_version = var.flyte_version
  cluster_name  = var.cluster_name
  tags          = var.tags
}

################################################################################
# Layer 3: Networking & Service Mesh
################################################################################

module "istio" {
  source = "./modules/istio"
  count  = var.enable_istio ? 1 : 0

  chart_version = var.istio_version
  tags          = var.tags
}

module "kgateway" {
  source = "./modules/kgateway"
  count  = var.enable_kgateway ? 1 : 0

  chart_version = var.kgateway_version
  tags          = var.tags
}

################################################################################
# Layer 4: Inference Engines (require GPU operator)
################################################################################

module "vllm" {
  source = "./modules/vllm"
  count  = var.enable_vllm ? 1 : 0

  chart_version = var.vllm_version
  tags          = var.tags

  depends_on = [module.nvidia_operator, module.kuberay]
}

module "sglang" {
  source = "./modules/sglang"
  count  = var.enable_sglang ? 1 : 0

  chart_version = var.sglang_version
  tags          = var.tags

  depends_on = [module.nvidia_operator]
}

################################################################################
# Layer 5: AI Gateways & Model Serving (route to vLLM or SGLang backends)
################################################################################

module "kserve" {
  source = "./modules/kserve"
  count  = var.enable_kserve ? 1 : 0

  chart_version    = var.kserve_version
  inference_router = var.inference_router
  tags             = var.tags

  depends_on = [module.istio, module.kgateway, module.vllm, module.sglang]
}

module "bifrost" {
  source = "./modules/bifrost"
  count  = var.enable_bifrost ? 1 : 0

  chart_version    = var.bifrost_version
  inference_router = var.inference_router
  tags             = var.tags

  depends_on = [module.kgateway, module.vllm, module.sglang]
}

module "envoy_ai_gateway" {
  source = "./modules/envoy-ai-gateway"
  count  = var.enable_envoy_ai_gateway ? 1 : 0

  chart_version    = var.envoy_ai_gateway_version
  inference_router = var.inference_router
  tags             = var.tags

  depends_on = [module.kgateway, module.vllm, module.sglang]
}
