# Cluster Outputs
# These outputs will be populated once the EKS module is configured in Task 2

# output "cluster_id" {
#   description = "The name/id of the EKS cluster"
#   value       = module.eks.cluster_name
# }

# output "cluster_name" {
#   description = "The name of the EKS cluster"
#   value       = module.eks.cluster_name
# }

# output "cluster_endpoint" {
#   description = "Endpoint for EKS control plane"
#   value       = module.eks.cluster_endpoint
# }

# output "cluster_version" {
#   description = "The Kubernetes version for the cluster"
#   value       = module.eks.cluster_version
# }

# output "cluster_security_group_id" {
#   description = "Security group ID attached to the EKS cluster"
#   value       = module.eks.cluster_security_group_id
# }

# output "cluster_certificate_authority_data" {
#   description = "Base64 encoded certificate data required to communicate with the cluster"
#   value       = module.eks.cluster_certificate_authority_data
#   sensitive   = true
# }

# output "cluster_oidc_provider_arn" {
#   description = "ARN of the OIDC Provider for EKS"
#   value       = module.eks.oidc_provider_arn
# }

# output "cluster_oidc_issuer_url" {
#   description = "The URL on the EKS cluster OIDC Issuer"
#   value       = module.eks.cluster_oidc_issuer_url
# }

# # Node Group Outputs
# output "node_security_group_id" {
#   description = "Security group ID attached to the EKS nodes"
#   value       = module.eks.node_security_group_id
# }

# output "node_group_id" {
#   description = "EKS node group ID"
#   value       = try(module.eks.eks_managed_node_groups["main"].node_group_id, "")
# }

# output "node_group_arn" {
#   description = "ARN of the EKS node group"
#   value       = try(module.eks.eks_managed_node_groups["main"].node_group_arn, "")
# }

# Note: node_group_role_arn output is defined in the IAM Role Outputs section below

# output "node_group_status" {
#   description = "Status of the EKS node group"
#   value       = try(module.eks.eks_managed_node_groups["main"].node_group_status, "")
# }

# # IAM Role Outputs
output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "node_group_role_arn" {
  description = "IAM role ARN for the node group"
  value       = try(module.eks.eks_managed_node_groups["main"].iam_role_arn, "")
}

# output "ebs_csi_driver_role_arn" {
#   description = "IAM role ARN for the EBS CSI driver"
#   value       = module.ebs_csi_irsa.iam_role_arn
# }

# output "lb_controller_role_arn" {
#   description = "IAM role ARN for the AWS Load Balancer Controller"
#   value       = module.lb_controller_irsa.iam_role_arn
# }

# # Add-on Outputs
# output "vpc_cni_addon_version" {
#   description = "Version of the VPC CNI add-on"
#   value       = aws_eks_addon.vpc_cni.addon_version
# }

# output "coredns_addon_version" {
#   description = "Version of the CoreDNS add-on"
#   value       = aws_eks_addon.coredns.addon_version
# }

# output "kube_proxy_addon_version" {
#   description = "Version of the kube-proxy add-on"
#   value       = aws_eks_addon.kube_proxy.addon_version
# }

# output "ebs_csi_addon_version" {
#   description = "Version of the EBS CSI driver add-on"
#   value       = aws_eks_addon.ebs_csi.addon_version
# }

# output "lb_controller_addon_version" {
#   description = "Version of the AWS Load Balancer Controller add-on"
#   value       = aws_eks_addon.lb_controller.addon_version
# }

# output "cloudwatch_observability_addon_version" {
#   description = "Version of the CloudWatch Observability add-on"
#   value       = aws_eks_addon.cloudwatch_observability.addon_version
# }

# output "adot_addon_version" {
#   description = "Version of the ADOT add-on"
#   value       = aws_eks_addon.adot.addon_version
# }

# Configuration Outputs
output "aws_region" {
  description = "AWS region where the cluster is deployed"
  value       = var.region
}

output "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  value       = var.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by the cluster"
  value       = var.private_subnet_ids
}
