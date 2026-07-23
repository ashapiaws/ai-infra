################################################################################
# SGLang - Fast LLM Serving with RadixAttention
#
# Alternative inference engine to vLLM. Optimized for structured generation
# and prefix caching via RadixAttention.
################################################################################

variable "chart_version" {
  description = "Helm chart version for SGLang"
  type        = string
  default     = "0.4.5"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "sglang"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

resource "helm_release" "sglang" {
  name             = "sglang"
  repository       = "https://sgl-project.github.io/helm-charts"
  chart            = "sglang"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  # GPU scheduling
  set = [
    {
      name  = "resources.limits.nvidia\\.com/gpu"
      value = "1"
    },
    {
      name  = "tolerations[0].key"
      value = "nvidia.com/gpu"
    },
    {
      name  = "tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "tolerations[0].effect"
      value = "NoSchedule"
    },
  ]
}

output "status" {
  description = "Deployment status"
  value       = helm_release.sglang.status
}

output "endpoint" {
  description = "Internal SGLang endpoint"
  value       = "http://sglang.${var.namespace}.svc.cluster.local:8000"
}
