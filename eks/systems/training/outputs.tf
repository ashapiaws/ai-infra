output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = data.aws_eks_cluster.this.endpoint
}

output "nvidia_operator_status" {
  description = "NVIDIA GPU Operator deployment status"
  value       = var.enable_nvidia_operator ? module.nvidia_operator[0].status : "disabled"
}

output "volcano_status" {
  description = "Volcano scheduler deployment status"
  value       = var.enable_volcano ? module.volcano[0].status : "disabled"
}

output "kuberay_status" {
  description = "KubeRay operator deployment status"
  value       = var.enable_kuberay ? module.kuberay[0].status : "disabled"
}

output "flyte_status" {
  description = "Flyte deployment status"
  value       = var.enable_flyte ? module.flyte[0].status : "disabled"
}
