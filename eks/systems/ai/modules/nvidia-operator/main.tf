################################################################################
# NVIDIA GPU Operator
# Automates GPU driver, container runtime, device plugin, and monitoring setup
################################################################################

resource "helm_release" "gpu_operator" {
  name             = "gpu-operator"
  repository       = "https://helm.ngc.nvidia.com/nvidia"
  chart            = "gpu-operator"
  version          = var.chart_version
  namespace        = "gpu-operator"
  create_namespace = true
  timeout          = 600
  wait             = true

  set = [
    {
      name  = "driver.enabled"
      value = "true"
    },
    {
      name  = "toolkit.enabled"
      value = "true"
    },
    {
      name  = "devicePlugin.enabled"
      value = "true"
    },
    {
      name  = "dcgmExporter.enabled"
      value = "true"
    },
    {
      name  = "migManager.enabled"
      value = "true"
    },
  ]
}
