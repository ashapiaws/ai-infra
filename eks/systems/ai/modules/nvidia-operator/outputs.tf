output "status" {
  description = "Deployment status of the NVIDIA GPU Operator"
  value       = helm_release.gpu_operator.status
}

output "namespace" {
  description = "Namespace where the GPU Operator is deployed"
  value       = helm_release.gpu_operator.namespace
}
