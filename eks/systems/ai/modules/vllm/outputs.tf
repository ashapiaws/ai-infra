output "status" {
  description = "Deployment status of vLLM"
  value       = helm_release.vllm.status
}

output "namespace" {
  description = "Namespace where vLLM is deployed"
  value       = helm_release.vllm.namespace
}
