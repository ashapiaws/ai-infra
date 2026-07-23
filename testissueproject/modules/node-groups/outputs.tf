# EKS Node Groups Module Outputs

output "node_group_arns" {
  description = "ARNs of the EKS node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.arn }
}

output "node_group_status" {
  description = "Status of the EKS node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.status }
}

output "node_group_capacity_types" {
  description = "Capacity types of the EKS node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.capacity_type }
}

output "node_group_instance_types" {
  description = "Instance types of the EKS node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.instance_types }
}

output "node_group_scaling_config" {
  description = "Scaling configuration of the EKS node groups"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      desired_size = v.scaling_config[0].desired_size
      max_size     = v.scaling_config[0].max_size
      min_size     = v.scaling_config[0].min_size
    }
  }
}

output "placement_group_ids" {
  description = "IDs of the placement groups"
  value       = { for k, v in aws_placement_group.node_groups : k => v.id }
}

output "placement_group_arns" {
  description = "ARNs of the placement groups"
  value       = { for k, v in aws_placement_group.node_groups : k => v.arn }
}

output "node_group_iam_role_arn" {
  description = "IAM role ARN of the EKS node groups"
  value       = aws_iam_role.node_group.arn
}

output "node_group_iam_role_name" {
  description = "IAM role name of the EKS node groups"
  value       = aws_iam_role.node_group.name
}

output "launch_template_ids" {
  description = "IDs of the launch templates (only for placement group enabled node groups)"
  value       = { for k, v in aws_launch_template.node_groups : k => v.id }
}

output "launch_template_latest_versions" {
  description = "Latest versions of the launch templates (only for placement group enabled node groups)"
  value       = { for k, v in aws_launch_template.node_groups : k => v.latest_version }
}