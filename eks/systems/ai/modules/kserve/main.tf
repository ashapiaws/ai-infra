################################################################################
# KServe - Model Serving Platform
# Provides serverless inference on Kubernetes with autoscaling
# Routes to vLLM or SGLang as the inference backend
################################################################################

resource "helm_release" "kserve" {
  name             = "kserve"
  repository       = "oci://ghcr.io/kserve/charts"
  chart            = "kserve-crd"
  version          = var.chart_version
  namespace        = "kserve"
  create_namespace = true
  timeout          = 300
  wait             = true
}

resource "helm_release" "kserve_controller" {
  name      = "kserve-controller"
  repository = "oci://ghcr.io/kserve/charts"
  chart     = "kserve"
  version   = var.chart_version
  namespace = "kserve"
  timeout   = 600
  wait      = true

  set = [
    {
      name  = "kserve.controller.deploymentMode"
      value = "Serverless"
    },
    {
      name  = "kserve.controller.gateway.ingressGateway"
      value = "kgateway-system/kgateway"
    },
  ]

  depends_on = [helm_release.kserve]
}
