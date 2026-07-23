output "status" {
  description = "Deployment status of Istio"
  value       = helm_release.istiod.status
}

output "namespace" {
  description = "Namespace where Istio control plane is deployed"
  value       = helm_release.istiod.namespace
}

output "ingress_namespace" {
  description = "Namespace where Istio ingress gateway is deployed"
  value       = helm_release.istio_ingress.namespace
}
