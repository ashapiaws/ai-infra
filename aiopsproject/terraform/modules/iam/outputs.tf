# IAM Module Outputs

output "cluster_service_role_arn" {
  description = "ARN of the EKS cluster service role"
  value       = aws_iam_role.cluster_service_role.arn
}

output "node_group_role_arn" {
  description = "ARN of the EKS node group role"
  value       = aws_iam_role.node_group_role.arn
}

output "training_service_role_arn" {
  description = "ARN of the training service IAM role (created in main config)"
  value       = ""
}

output "training_service_role_name" {
  description = "Name of the training service IAM role (created in main config)"
  value       = ""
}

output "inference_service_role_arn" {
  description = "ARN of the inference service IAM role (created in main config)"
  value       = ""
}

output "inference_service_role_name" {
  description = "Name of the inference service IAM role (created in main config)"
  value       = ""
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role (created in main config)"
  value       = ""
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the cluster autoscaler IAM role (created in main config)"
  value       = ""
}

output "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "ID of the KMS key for encryption"
  value       = aws_kms_key.main.key_id
}