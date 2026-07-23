output "status" {
  description = "Deployment status of Cilium"
  value       = helm_release.cilium.status
}
