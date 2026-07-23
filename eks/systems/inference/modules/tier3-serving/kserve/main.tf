################################################################################
# KServe - Serverless Model Serving Platform
#
# Provides:
#   - Scale-to-zero for inference endpoints
#   - Canary rollouts between model versions
#   - InferenceService CRD for declarative model deployment
################################################################################

variable "chart_version" {
  description = "Helm chart version for KServe"
  type        = string
  default     = "0.14.1"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "kserve"
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

resource "helm_release" "kserve" {
  name             = "kserve"
  repository       = "https://kserve.github.io/charts"
  chart            = "kserve-crd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
}

resource "helm_release" "kserve_controller" {
  name       = "kserve-controller"
  repository = "https://kserve.github.io/charts"
  chart      = "kserve"
  version    = var.chart_version
  namespace  = var.namespace

  depends_on = [helm_release.kserve]
}

output "status" {
  description = "Deployment status"
  value       = helm_release.kserve_controller.status
}
