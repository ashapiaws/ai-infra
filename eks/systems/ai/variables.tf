################################################################################
# Cluster & Network
################################################################################

variable "aws_region" {
  description = "AWS region where the EKS cluster resides"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs used by the cluster"
  type        = list(string)
  default     = []
}

################################################################################
# Component Toggles
################################################################################

variable "enable_nvidia_operator" {
  description = "Deploy the NVIDIA GPU Operator via Helm"
  type        = bool
  default     = true
}

variable "enable_istio" {
  description = "Deploy Istio service mesh via Helm"
  type        = bool
  default     = true
}

variable "enable_flyte" {
  description = "Deploy Flyte workflow orchestrator via Helm"
  type        = bool
  default     = true
}

variable "enable_kuberay" {
  description = "Deploy KubeRay operator via Helm"
  type        = bool
  default     = true
}

variable "enable_volcano" {
  description = "Deploy Volcano batch scheduler via Helm"
  type        = bool
  default     = true
}

variable "enable_kgateway" {
  description = "Deploy KGateway (Kubernetes Gateway API implementation) via Helm"
  type        = bool
  default     = false
}

variable "enable_kserve" {
  description = "Deploy KServe model serving platform via Helm"
  type        = bool
  default     = false
}

variable "enable_vllm" {
  description = "Deploy vLLM inference engine via Helm"
  type        = bool
  default     = false
}

variable "enable_bifrost" {
  description = "Deploy Bifrost AI Gateway via Helm"
  type        = bool
  default     = false
}

variable "enable_envoy_ai_gateway" {
  description = "Deploy Envoy AI Gateway via Helm"
  type        = bool
  default     = false
}

variable "enable_sglang" {
  description = "Deploy SGLang inference engine via Helm"
  type        = bool
  default     = false
}

################################################################################
# Inference Routing Configuration
################################################################################

variable "inference_router" {
  description = "Which inference backend to route to: 'vllm', 'sglang', or 'both'"
  type        = string
  default     = "vllm"

  validation {
    condition     = contains(["vllm", "sglang", "both"], var.inference_router)
    error_message = "inference_router must be one of: vllm, sglang, both"
  }
}

################################################################################
# Component Versions (override per environment)
################################################################################

variable "nvidia_operator_version" {
  description = "Helm chart version for the NVIDIA GPU Operator"
  type        = string
  default     = "v24.9.2"
}

variable "istio_version" {
  description = "Helm chart version for Istio"
  type        = string
  default     = "1.24.2"
}

variable "flyte_version" {
  description = "Helm chart version for Flyte"
  type        = string
  default     = "v1.13.2"
}

variable "kuberay_version" {
  description = "Helm chart version for KubeRay operator"
  type        = string
  default     = "1.2.2"
}

variable "volcano_version" {
  description = "Helm chart version for Volcano"
  type        = string
  default     = "1.10.0"
}

variable "kgateway_version" {
  description = "Helm chart version for KGateway"
  type        = string
  default     = "2.0.3"
}

variable "kserve_version" {
  description = "Helm chart version for KServe"
  type        = string
  default     = "0.14.1"
}

variable "vllm_version" {
  description = "Helm chart version for vLLM"
  type        = string
  default     = "0.7.3"
}

variable "bifrost_version" {
  description = "Helm chart version for Bifrost AI Gateway"
  type        = string
  default     = "0.1.0"
}

variable "envoy_ai_gateway_version" {
  description = "Helm chart version for Envoy AI Gateway"
  type        = string
  default     = "0.4.0"
}

variable "sglang_version" {
  description = "Helm chart version for SGLang"
  type        = string
  default     = "0.4.5"
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
