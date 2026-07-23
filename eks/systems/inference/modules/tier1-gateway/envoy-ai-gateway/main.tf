################################################################################
# Envoy AI Gateway - Tier 1 Intelligent Router
#
# Responsibilities:
#   - Model-aware routing (model name → backend)
#   - Bedrock endpoint fan-out (OpenAI format → Bedrock API)
#   - Rate limiting per client/model
#   - Fallback routing (self-hosted overloaded → Bedrock)
################################################################################

variable "chart_version" {
  description = "Helm chart version for Envoy AI Gateway"
  type        = string
  default     = "0.4.0"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "envoy-ai-gateway"
}

variable "enable_rate_limiting" {
  description = "Enable rate-limiting filters"
  type        = bool
  default     = false
}

variable "rate_limit_rps" {
  description = "Default RPS limit per client"
  type        = number
  default     = 100
}

variable "inference_router" {
  description = "Default backend: vllm, sglang, or both"
  type        = string
  default     = "vllm"
}

variable "bedrock_routing" {
  description = "Enable Bedrock as an upstream backend"
  type        = bool
  default     = false
}

variable "bedrock_models" {
  description = "Bedrock model IDs to route to"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

resource "helm_release" "envoy_ai_gateway" {
  name             = "envoy-ai-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "ai-gateway-helm"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set = concat(
    [
      # Core routing config
      {
        name  = "aiGateway.defaultBackend"
        value = var.inference_router
      },
      # Rate limiting
      {
        name  = "rateLimit.enabled"
        value = tostring(var.enable_rate_limiting)
      },
      # Bedrock routing
      {
        name  = "backends.bedrock.enabled"
        value = tostring(var.bedrock_routing)
      },
    ],
    # Conditional: rate limit RPS
    var.enable_rate_limiting ? [
      {
        name  = "rateLimit.defaultRPS"
        value = tostring(var.rate_limit_rps)
      },
    ] : [],
    # Conditional: Bedrock models
    var.bedrock_routing ? [
      {
        name  = "backends.bedrock.models"
        value = join(",", var.bedrock_models)
      },
    ] : [],
  )
}

output "status" {
  description = "Deployment status"
  value       = helm_release.envoy_ai_gateway.status
}

output "endpoint" {
  description = "Internal gateway endpoint"
  value       = "http://envoy-ai-gateway.${var.namespace}.svc.cluster.local:8080"
}
