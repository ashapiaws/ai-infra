output "status" {
  description = "Deployment status of Flyte"
  value       = helm_release.flyte.status
}

output "namespace" {
  description = "Namespace where Flyte is deployed"
  value       = helm_release.flyte.namespace
}
