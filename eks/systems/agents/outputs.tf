output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = data.aws_eks_cluster.this.endpoint
}

output "redis_status" {
  description = "Redis deployment status"
  value       = var.enable_redis ? module.redis[0].status : "disabled"
}

output "temporal_status" {
  description = "Temporal deployment status"
  value       = var.enable_temporal ? module.temporal[0].status : "disabled"
}

output "mcp_gateway_status" {
  description = "MCP Gateway deployment status"
  value       = var.enable_mcp_gateway ? module.mcp_gateway[0].status : "disabled"
}
