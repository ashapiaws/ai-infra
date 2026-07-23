output "status" {
  description = "Deployment status of KubeRay operator"
  value       = helm_release.kuberay_operator.status
}

output "namespace" {
  description = "Namespace where KubeRay operator is deployed"
  value       = helm_release.kuberay_operator.namespace
}
