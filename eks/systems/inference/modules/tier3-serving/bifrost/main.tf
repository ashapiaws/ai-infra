################################################################################
# Bifrost - Unified AI Gateway
#
# Provides:
#   - Multi-backend load balancing (vLLM + SGLang)
#   - Unified OpenAI-compatible API
#   - Model routing policies
################################################################################

variable "chart_version" {
  description = "Helm chart version for Bifrost"
  type        = string
  default     = "0.1.0"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "bifrost"
}

variable "inference_router" {
  description = "Default backend: vllm, sglang, or both"
  type        = string
  default     = "vllm"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

resource "helm_release" "bifrost" {
  name             = "bifrost"
  repository       = "https://bifrost-ai.github.io/charts"
  chart            = "bifrost"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set = [
    {
      name  = "config.defaultBackend"
      value = var.inference_router
    },
  ]
}

output "status" {
  description = "Deployment status"
  value       = helm_release.bifrost.status
}
