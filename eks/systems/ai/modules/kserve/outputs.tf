output "status" {
  description = "Deployment status of KServe"
  value       = helm_release.kserve_controller.status
}

output "namespace" {
  description = "Namespace where KServe is deployed"
  value       = helm_release.kserve_controller.namespace
}
