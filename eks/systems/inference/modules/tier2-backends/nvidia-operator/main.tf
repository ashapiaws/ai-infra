################################################################################
# NVIDIA GPU Operator
#
# Automates GPU driver installation, container runtime, device plugin,
# and monitoring on GPU nodes.
################################################################################

variable "chart_version" {
  description = "Helm chart version for NVIDIA GPU Operator"
  type        = string
  default     = "v24.9.2"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "gpu-operator"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

resource "helm_release" "nvidia_operator" {
  name             = "gpu-operator"
  repository       = "https://helm.ngc.nvidia.com/nvidia"
  chart            = "gpu-operator"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set {
    name  = "driver.enabled"
    value = "true"
  }

  set {
    name  = "toolkit.enabled"
    value = "true"
  }

  set {
    name  = "devicePlugin.enabled"
    value = "true"
  }
}

output "status" {
  description = "Deployment status"
  value       = helm_release.nvidia_operator.status
}
