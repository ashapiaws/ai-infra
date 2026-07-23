################################################################################
# Flyte - ML Workflow Orchestration
################################################################################

variable "chart_version" {
  type    = string
  default = "v1.13.2"
}

variable "namespace" {
  type    = string
  default = "flyte"
}

variable "cluster_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "helm_release" "flyte" {
  name             = "flyte"
  repository       = "https://flyteorg.github.io/flyte"
  chart            = "flyte-binary"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
}

output "status" {
  value = helm_release.flyte.status
}
