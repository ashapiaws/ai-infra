################################################################################
# Istio Service Mesh
# Deploys Istio base (CRDs), istiod (control plane), and ingress gateway
################################################################################

resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = var.chart_version
  namespace        = "istio-system"
  create_namespace = true
  timeout          = 300
  wait             = true

  set = [
    {
      name  = "defaultRevision"
      value = "default"
    },
  ]
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.chart_version
  namespace  = "istio-system"
  timeout    = 300
  wait       = true

  set = [
    {
      name  = "pilot.resources.requests.cpu"
      value = "200m"
    },
    {
      name  = "pilot.resources.requests.memory"
      value = "256Mi"
    },
  ]

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_ingress" {
  name             = "istio-ingress"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "gateway"
  version          = var.chart_version
  namespace        = "istio-ingress"
  create_namespace = true
  timeout          = 300
  wait             = true

  set = [
    {
      name  = "service.type"
      value = "LoadBalancer"
    },
  ]

  depends_on = [helm_release.istiod]
}
