output "cloudwatch_role_arn" {
  description = "IAM role ARN for CloudWatch agent"
  value       = var.enable_cloudwatch ? aws_iam_role.cloudwatch[0].arn : null
}

output "prometheus_status" {
  description = "Deployment status of Prometheus/Grafana stack"
  value       = var.enable_prometheus_grafana ? helm_release.prometheus_stack[0].status : "disabled"
}
