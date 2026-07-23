output "status" {
  description = "Deployment status of Bifrost AI Gateway"
  value       = helm_release.bifrost.status
}

output "namespace" {
  description = "Namespace where Bifrost is deployed"
  value       = helm_release.bifrost.namespace
}
