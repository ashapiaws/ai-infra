output "status" {
  description = "Deployment status of Envoy AI Gateway"
  value       = helm_release.envoy_ai_gateway.status
}

output "namespace" {
  description = "Namespace where Envoy AI Gateway is deployed"
  value       = helm_release.envoy_ai_gateway.namespace
}
