output "status" {
  description = "Deployment status of SGLang"
  value       = helm_release.sglang.status
}

output "namespace" {
  description = "Namespace where SGLang is deployed"
  value       = helm_release.sglang.namespace
}
