################################################################################
# Cluster Info
################################################################################

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = data.aws_eks_cluster.this.endpoint
}

################################################################################
# Tier 1: Gateway Status
################################################################################

output "kgateway_status" {
  description = "KGateway deployment status"
  value       = var.enable_kgateway ? module.kgateway[0].status : "disabled"
}

output "envoy_ai_gateway_status" {
  description = "Envoy AI Gateway deployment status"
  value       = var.enable_envoy_ai_gateway ? module.envoy_ai_gateway[0].status : "disabled"
}

################################################################################
# Tier 2: Backend Status
################################################################################

output "nvidia_operator_status" {
  description = "NVIDIA GPU Operator deployment status"
  value       = var.enable_nvidia_operator ? module.nvidia_operator[0].status : "disabled"
}

output "vllm_status" {
  description = "vLLM deployment status"
  value       = var.enable_vllm ? module.vllm[0].status : "disabled"
}

output "sglang_status" {
  description = "SGLang deployment status"
  value       = var.enable_sglang ? module.sglang[0].status : "disabled"
}

output "bedrock_routing_enabled" {
  description = "Whether Bedrock endpoint routing is active"
  value       = var.enable_bedrock_routing
}

################################################################################
# Tier 3: Serving Status
################################################################################

output "kserve_status" {
  description = "KServe deployment status"
  value       = var.enable_kserve ? module.kserve[0].status : "disabled"
}

output "bifrost_status" {
  description = "Bifrost deployment status"
  value       = var.enable_bifrost ? module.bifrost[0].status : "disabled"
}

################################################################################
# Gateway Endpoint (for app layer consumption)
################################################################################

output "gateway_url" {
  description = "Internal gateway URL for apps to send inference requests"
  value       = var.enable_envoy_ai_gateway ? "http://envoy-ai-gateway.envoy-ai-gateway.svc.cluster.local:8080" : (var.enable_kgateway ? "http://kgateway.kgateway-system.svc.cluster.local:8080" : "none")
}
