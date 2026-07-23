################################################################################
# Volcano - Gang Scheduler for Batch/HPC Workloads
################################################################################

variable "chart_version" {
  type    = string
  default = "1.10.0"
}

variable "namespace" {
  type    = string
  default = "volcano-system"
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "helm_release" "volcano" {
  name             = "volcano"
  repository       = "https://volcano-sh.github.io/helm-charts"
  chart            = "volcano"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
}

output "status" {
  value = helm_release.volcano.status
}
