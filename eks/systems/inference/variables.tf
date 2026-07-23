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

################################################################################
# Tier 1: Ingress Gateway (auth, routing, rate-limiting)
################################################################################

variable "enable_kgateway" {
  description = "Deploy KGateway (Kubernetes Gateway API implementation)"
  type        = bool
  default     = true
}

variable "enable_envoy_ai_gateway" {
  description = "Deploy Envoy AI Gateway as the Tier 1 intelligent router"
  type        = bool
  default     = true
}

variable "enable_rate_limiting" {
  description = "Enable rate-limiting at the Tier 1 gateway"
  type        = bool
  default     = false
}

variable "rate_limit_rps" {
  description = "Default requests-per-second limit per client at Tier 1"
  type        = number
  default     = 100
}

################################################################################
# Tier 2: Inference Backends (self-hosted engines + managed endpoints)
################################################################################

variable "enable_nvidia_operator" {
  description = "Deploy the NVIDIA GPU Operator (required for self-hosted engines)"
  type        = bool
  default     = true
}

variable "enable_vllm" {
  description = "Deploy vLLM inference engine"
  type        = bool
  default     = true
}

variable "enable_sglang" {
  description = "Deploy SGLang inference engine"
  type        = bool
  default     = false
}

variable "enable_bedrock_routing" {
  description = "Enable Bedrock endpoint routing via Tier 1 gateway"
  type        = bool
  default     = false
}

variable "bedrock_models" {
  description = "List of Bedrock model IDs to expose through the gateway"
  type        = list(string)
  default     = []
}

################################################################################
# Tier 3: Model Serving / Orchestration
################################################################################

variable "enable_kserve" {
  description = "Deploy KServe for serverless model serving"
  type        = bool
  default     = false
}

variable "enable_bifrost" {
  description = "Deploy Bifrost as a unified AI gateway"
  type        = bool
  default     = false
}

################################################################################
# Routing Configuration
################################################################################

variable "inference_router" {
  description = "Default self-hosted backend to route to: 'vllm', 'sglang', or 'both'"
  type        = string
  default     = "vllm"

  validation {
    condition     = contains(["vllm", "sglang", "both"], var.inference_router)
    error_message = "inference_router must be one of: vllm, sglang, both"
  }
}

################################################################################
# Component Versions
################################################################################

variable "kgateway_version" {
  description = "Helm chart version for KGateway"
  type        = string
  default     = "2.0.3"
}

variable "envoy_ai_gateway_version" {
  description = "Helm chart version for Envoy AI Gateway"
  type        = string
  default     = "0.4.0"
}

variable "nvidia_operator_version" {
  description = "Helm chart version for the NVIDIA GPU Operator"
  type        = string
  default     = "v24.9.2"
}

variable "vllm_version" {
  description = "Helm chart version for vllm-stack (leave empty for latest)"
  type        = string
  default     = ""
}

variable "vllm_model_name" {
  description = "Name identifier for the vLLM model deployment"
  type        = string
  default     = "vllm"
}

variable "vllm_model_url" {
  description = "HuggingFace model ID for vLLM (e.g. meta-llama/Llama-3.1-8B-Instruct)"
  type        = string
  default     = ""
}

variable "vllm_gpu_count" {
  description = "Number of GPUs per vLLM replica"
  type        = number
  default     = 1
}

variable "hf_token" {
  description = "HuggingFace API token for gated model access"
  type        = string
  default     = ""
  sensitive   = true
}

variable "sglang_version" {
  description = "Helm chart version for SGLang"
  type        = string
  default     = "0.4.5"
}

variable "kserve_version" {
  description = "Helm chart version for KServe"
  type        = string
  default     = "0.14.1"
}

variable "bifrost_version" {
  description = "Helm chart version for Bifrost"
  type        = string
  default     = "0.1.0"
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
