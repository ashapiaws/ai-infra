################################################################################
# KGateway (Kubernetes Gateway API)
# Envoy-based Gateway API implementation for advanced traffic routing
################################################################################

resource "helm_release" "kgateway" {
  name             = "kgateway"
  repository       = "oci://cr.kgateway.dev/kgateway-helm"
  chart            = "kgateway"
  version          = var.chart_version
  namespace        = "kgateway-system"
  create_namespace = true
  timeout          = 300
  wait             = true
}
