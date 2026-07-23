# ML Infrastructure Platform - Output Values
# Defines outputs that can be used by other Terraform configurations or external systems

# EKS Cluster Outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint URL of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

# Node Group Outputs
output "cpu_node_group_arn" {
  description = "ARN of the CPU node group"
  value       = module.eks.cpu_node_group_arn
}

output "gpu_node_group_arn" {
  description = "ARN of the GPU node group"
  value       = module.eks.gpu_node_group_arn
}

output "cpu_node_group_status" {
  description = "Status of the CPU node group"
  value       = module.eks.cpu_node_group_status
}

output "gpu_node_group_status" {
  description = "Status of the GPU node group"
  value       = module.eks.gpu_node_group_status
}

# S3 Outputs
output "model_registry_bucket_name" {
  description = "Name of the S3 bucket for model registry"
  value       = module.s3.model_registry_bucket_name
}

output "model_registry_bucket_arn" {
  description = "ARN of the S3 bucket for model registry"
  value       = module.s3.model_registry_bucket_arn
}

output "artifacts_bucket_name" {
  description = "Name of the S3 bucket for training artifacts"
  value       = module.s3.artifacts_bucket_name
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket for training artifacts"
  value       = module.s3.artifacts_bucket_arn
}

# IAM Outputs
output "cluster_service_role_arn" {
  description = "ARN of the EKS cluster service role"
  value       = module.iam.cluster_service_role_arn
}

output "node_group_role_arn" {
  description = "ARN of the EKS node group role"
  value       = module.iam.node_group_role_arn
}

output "training_service_role_arn" {
  description = "ARN of the training service IAM role"
  value       = aws_iam_role.training_service_role.arn
}

output "inference_service_role_arn" {
  description = "ARN of the inference service IAM role"
  value       = aws_iam_role.inference_service_role.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  value       = module.iam.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the KMS key for encryption"
  value       = module.iam.kms_key_id
}

# OIDC Provider Output for IRSA
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

# Karpenter-related outputs
output "karpenter_node_instance_profile_name" {
  description = "Name of the Karpenter node instance profile"
  value       = module.eks.karpenter_node_instance_profile_name
}

output "karpenter_node_instance_role_arn" {
  description = "ARN of the Karpenter node instance role"
  value       = module.eks.karpenter_node_instance_role_arn
}

# Kubeconfig Command
output "kubeconfig_command" {
  description = "Command to update kubeconfig for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Environment Information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID where resources are deployed"
  value       = var.vpc_id
}

# Subnet selection outputs
output "selected_subnet_ids" {
  description = "List of subnet IDs selected for EKS cluster deployment"
  value       = local.selected_subnet_ids
}

output "selected_subnet_details" {
  description = "Details of selected subnets including availability zones"
  value = {
    for subnet_id in local.selected_subnet_ids : subnet_id => {
      availability_zone = data.aws_subnet.selected[subnet_id].availability_zone
      cidr_block       = data.aws_subnet.selected[subnet_id].cidr_block
      tags             = data.aws_subnet.selected[subnet_id].tags
    }
  }
}