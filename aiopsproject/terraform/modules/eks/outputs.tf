# EKS Module Outputs

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint URL of the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data for the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "node_group_security_group_id" {
  description = "Security group ID of the node groups"
  value       = aws_security_group.node_group.id
}

output "cpu_node_group_arn" {
  description = "ARN of the CPU node group"
  value       = aws_eks_node_group.cpu_nodes.arn
}

output "gpu_node_group_arn" {
  description = "ARN of the GPU node group"
  value       = aws_eks_node_group.gpu_nodes.arn
}

output "cpu_node_group_status" {
  description = "Status of the CPU node group"
  value       = aws_eks_node_group.cpu_nodes.status
}

output "gpu_node_group_status" {
  description = "Status of the GPU node group"
  value       = aws_eks_node_group.gpu_nodes.status
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_issuer_url" {
  description = "URL of the OIDC issuer"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Karpenter-related outputs
output "karpenter_node_instance_profile_name" {
  description = "Name of the Karpenter node instance profile"
  value       = aws_iam_instance_profile.karpenter_node_instance_profile.name
}

output "karpenter_node_instance_role_arn" {
  description = "ARN of the Karpenter node instance role"
  value       = aws_iam_role.karpenter_node_instance_role.arn
}