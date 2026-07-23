output "status" {
  description = "Deployment status of KGateway"
  value       = helm_release.kgateway.status
}

output "namespace" {
  description = "Namespace where KGateway is deployed"
  value       = helm_release.kgateway.namespace
}
