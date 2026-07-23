################################################################################
# Cluster Info (from data sources)
################################################################################

output "cluster_endpoint" {
  description = "EKS cluster API endpoint (fetched dynamically)"
  value       = data.aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = data.aws_eks_cluster.this.version
}

################################################################################
# Component Status Outputs
################################################################################

output "nvidia_operator_status" {
  description = "NVIDIA GPU Operator deployment status"
  value       = var.enable_nvidia_operator ? module.nvidia_operator[0].status : "disabled"
}

output "istio_status" {
  description = "Istio deployment status"
  value       = var.enable_istio ? module.istio[0].status : "disabled"
}

output "flyte_status" {
  description = "Flyte deployment status"
  value       = var.enable_flyte ? module.flyte[0].status : "disabled"
}

output "kuberay_status" {
  description = "KubeRay operator deployment status"
  value       = var.enable_kuberay ? module.kuberay[0].status : "disabled"
}

output "volcano_status" {
  description = "Volcano scheduler deployment status"
  value       = var.enable_volcano ? module.volcano[0].status : "disabled"
}

output "kgateway_status" {
  description = "KGateway deployment status"
  value       = var.enable_kgateway ? module.kgateway[0].status : "disabled"
}

output "kserve_status" {
  description = "KServe deployment status"
  value       = var.enable_kserve ? module.kserve[0].status : "disabled"
}

output "vllm_status" {
  description = "vLLM deployment status"
  value       = var.enable_vllm ? module.vllm[0].status : "disabled"
}

output "bifrost_status" {
  description = "Bifrost AI Gateway deployment status"
  value       = var.enable_bifrost ? module.bifrost[0].status : "disabled"
}

output "sglang_status" {
  description = "SGLang deployment status"
  value       = var.enable_sglang ? module.sglang[0].status : "disabled"
}

output "envoy_ai_gateway_status" {
  description = "Envoy AI Gateway deployment status"
  value       = var.enable_envoy_ai_gateway ? module.envoy_ai_gateway[0].status : "disabled"
}
