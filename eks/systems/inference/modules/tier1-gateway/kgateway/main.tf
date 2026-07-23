################################################################################
# KGateway - Kubernetes Gateway API Implementation
#
# Provides the foundation for Tier 1 routing using the Gateway API spec.
# Envoy AI Gateway builds on top of this.
################################################################################

variable "chart_version" {
  description = "Helm chart version for KGateway"
  type        = string
  default     = "2.0.3"
}

variable "namespace" {
  description = "Kubernetes namespace for KGateway"
  type        = string
  default     = "kgateway-system"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

resource "helm_release" "kgateway" {
  name             = "kgateway"
  repository       = "https://docs.kgateway.dev/charts"
  chart            = "kgateway"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set {
    name  = "gateway.enabled"
    value = "true"
  }
}

output "status" {
  description = "Deployment status"
  value       = helm_release.kgateway.status
}

output "namespace" {
  description = "Namespace where KGateway is deployed"
  value       = var.namespace
}
