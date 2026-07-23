################################################################################
# vLLM - High-Throughput LLM Inference Engine
#
# Deploys vLLM with PagedAttention for efficient GPU memory management.
# Runs on GPU nodes with nvidia.com/gpu taint tolerance.
################################################################################

variable "chart_version" {
  description = "Helm chart version for vLLM"
  type        = string
  default     = "0.7.3"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "vllm"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

resource "helm_release" "vllm" {
  name             = "vllm"
  repository       = "https://vllm-project.github.io/helm-charts"
  chart            = "vllm"
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
  value       = helm_release.vllm.status
}

output "endpoint" {
  description = "Internal vLLM endpoint"
  value       = "http://vllm.${var.namespace}.svc.cluster.local:8000"
}
