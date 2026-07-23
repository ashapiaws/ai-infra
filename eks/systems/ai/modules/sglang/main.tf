################################################################################
# SGLang - Fast Serving Framework for LLMs
# High-performance inference with RadixAttention for structured generation
################################################################################

resource "helm_release" "sglang" {
  name             = "sglang"
  repository       = "https://sgl-project.github.io/helm-charts"
  chart            = "sglang"
  version          = var.chart_version
  namespace        = "sglang"
  create_namespace = true
  timeout          = 600
  wait             = true

  set = [
    {
      name  = "resources.limits.nvidia\\.com/gpu"
      value = "1"
    },
    {
      name  = "server.port"
      value = "30000"
    },
  ]
}
