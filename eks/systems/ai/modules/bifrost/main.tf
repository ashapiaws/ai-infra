################################################################################
# Bifrost AI Gateway
# Unified API gateway for routing to multiple LLM inference backends
# Supports load balancing, failover, and model routing across vLLM/SGLang
################################################################################

resource "helm_release" "bifrost" {
  name             = "bifrost"
  repository       = "https://bifrost-ai.github.io/helm-charts"
  chart            = "bifrost-gateway"
  version          = var.chart_version
  namespace        = "bifrost"
  create_namespace = true
  timeout          = 300
  wait             = true

  set = [
    {
      name  = "config.routing.defaultBackend"
      value = var.inference_router == "sglang" ? "sglang" : "vllm"
    },
    {
      name  = "config.backends.vllm.enabled"
      value = var.inference_router == "vllm" || var.inference_router == "both" ? "true" : "false"
    },
    {
      name  = "config.backends.vllm.endpoint"
      value = "http://vllm.vllm.svc.cluster.local:8000"
    },
    {
      name  = "config.backends.sglang.enabled"
      value = var.inference_router == "sglang" || var.inference_router == "both" ? "true" : "false"
    },
    {
      name  = "config.backends.sglang.endpoint"
      value = "http://sglang.sglang.svc.cluster.local:30000"
    },
  ]
}
