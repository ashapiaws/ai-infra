################################################################################
# KubeRay - Ray Cluster Operator for Distributed Compute
################################################################################

variable "chart_version" {
  type    = string
  default = "1.2.2"
}

variable "namespace" {
  type    = string
  default = "kuberay-system"
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "helm_release" "kuberay" {
  name             = "kuberay-operator"
  repository       = "https://ray-project.github.io/kuberay-helm"
  chart            = "kuberay-operator"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
}

output "status" {
  value = helm_release.kuberay.status
}
