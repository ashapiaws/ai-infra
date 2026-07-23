################################################################################
# KubeRay Operator
# Manages Ray clusters on Kubernetes for distributed ML workloads
################################################################################

resource "helm_release" "kuberay_operator" {
  name             = "kuberay-operator"
  repository       = "https://ray-project.github.io/kuberay-helm"
  chart            = "kuberay-operator"
  version          = var.chart_version
  namespace        = "kuberay-system"
  create_namespace = true
  timeout          = 300
  wait             = true

  set = [
    {
      name  = "resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "resources.requests.memory"
      value = "128Mi"
    },
    {
      name  = "watchNamespace"
      value = ""
    },
  ]
}
