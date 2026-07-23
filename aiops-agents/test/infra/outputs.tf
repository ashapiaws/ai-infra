output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster auth"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID (created or existing)"
  value       = local.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = local.private_subnets
}

output "cloudwatch_log_group_app" {
  description = "CloudWatch log group for application logs"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "cloudwatch_log_group_cluster" {
  description = "CloudWatch log group for cluster logs"
  value       = aws_cloudwatch_log_group.cluster_logs.name
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  value       = module.ebs_csi_irsa.iam_role_arn
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}"
}
