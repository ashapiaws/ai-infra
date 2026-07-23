output "status" {
  description = "Deployment status of Volcano"
  value       = helm_release.volcano.status
}

output "namespace" {
  description = "Namespace where Volcano is deployed"
  value       = helm_release.volcano.namespace
}
