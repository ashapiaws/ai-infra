################################################################################
# Temporal - Durable Workflow Execution for Agents
#
# Provides:
#   - Long-running agent task orchestration
#   - Automatic retries and timeouts
#   - Saga patterns for multi-step agent workflows
################################################################################

variable "chart_version" {
  type    = string
  default = "0.45.0"
}

variable "namespace" {
  type    = string
  default = "temporal"
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "helm_release" "temporal" {
  name             = "temporal"
  repository       = "https://go.temporal.io/helm-charts"
  chart            = "temporal"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  # Dev mode: use built-in Cassandra
  set {
    name  = "cassandra.enabled"
    value = "true"
  }

  set {
    name  = "elasticsearch.enabled"
    value = "false"
  }
}

output "status" {
  value = helm_release.temporal.status
}

output "endpoint" {
  value = "temporal-frontend.${var.namespace}.svc.cluster.local:7233"
}
