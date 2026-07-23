output "fsx_csi_role_arn" {
  description = "IAM role ARN for FSx CSI driver"
  value       = var.enable_fsx ? aws_iam_role.fsx_csi[0].arn : null
}
