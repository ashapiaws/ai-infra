output "gateway_endpoint" {
  description = "Internal Envoy gateway service endpoint"
  value       = "http://envoy-gateway.${var.envoy_namespace}.svc.cluster.local:80"
}

output "admin_endpoint" {
  description = "Envoy admin interface (dev only)"
  value       = var.enable_admin_interface ? "http://envoy-gateway.${var.envoy_namespace}.svc.cluster.local:${var.admin_port}" : null
}

output "namespace" {
  description = "Namespace where Envoy is deployed"
  value       = var.envoy_namespace
}
