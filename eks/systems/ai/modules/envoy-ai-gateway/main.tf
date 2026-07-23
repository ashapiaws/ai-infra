################################################################################
# Envoy AI Gateway
# Envoy-based gateway purpose-built for AI inference traffic
# Provides token-aware rate limiting, model routing, and observability
################################################################################

resource "helm_release" "envoy_ai_gateway" {
  name             = "envoy-ai-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "ai-gateway-helm"
  version          = var.chart_version
  namespace        = "envoy-ai-gateway"
  create_namespace = true
  timeout          = 300
  wait             = true

  set = [
    {
      name  = "gateway.replicas"
      value = "2"
    },
    {
      name  = "backends.vllm.enabled"
      value = var.inference_router == "vllm" || var.inference_router == "both" ? "true" : "false"
    },
    {
      name  = "backends.vllm.endpoint"
      value = "http://vllm.vllm.svc.cluster.local:8000"
    },
    {
      name  = "backends.sglang.enabled"
      value = var.inference_router == "sglang" || var.inference_router == "both" ? "true" : "false"
    },
    {
      name  = "backends.sglang.endpoint"
      value = "http://sglang.sglang.svc.cluster.local:30000"
    },
  ]
}
