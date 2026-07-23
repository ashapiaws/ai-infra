################################################################################
# NVIDIA GPU Operator (shared with inference)
################################################################################

variable "chart_version" {
  type    = string
  default = "v24.9.2"
}

variable "namespace" {
  type    = string
  default = "gpu-operator"
}

variable "tags" {
  type    = map(string)
  default = {}
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
}

output "status" {
  value = helm_release.nvidia_operator.status
}
