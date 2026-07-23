################################################################################
# vLLM - High-throughput LLM Inference Engine
# Deploys the vLLM operator/server for serving large language models
################################################################################

resource "helm_release" "vllm" {
  name             = "vllm"
  repository       = "https://vllm-project.github.io/production-stack"
  chart            = "vllm-stack"
  version          = var.chart_version
  namespace        = "vllm"
  create_namespace = true
  timeout          = 600
  wait             = true

  set = [
    {
      name  = "servingEngineSpec.runtimeClassName"
      value = "nvidia"
    },
    {
      name  = "servingEngineSpec.resources.limits.nvidia\\.com/gpu"
      value = "1"
    },
  ]
}
