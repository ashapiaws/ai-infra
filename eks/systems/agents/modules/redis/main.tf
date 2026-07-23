################################################################################
# Redis - Agent State & Messaging
#
# Used for:
#   - Agent session state / short-term memory
#   - Pub/sub for inter-agent communication
#   - Rate limit counters
################################################################################

variable "chart_version" {
  type    = string
  default = "19.6.4"
}

variable "namespace" {
  type    = string
  default = "agents"
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "helm_release" "redis" {
  name             = "redis"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "redis"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set {
    name  = "architecture"
    value = "standalone"
  }

  set {
    name  = "auth.enabled"
    value = "true"
  }

  set {
    name  = "replica.replicaCount"
    value = "0"
  }
}

output "status" {
  value = helm_release.redis.status
}

output "endpoint" {
  value = "redis://redis-master.${var.namespace}.svc.cluster.local:6379"
}
