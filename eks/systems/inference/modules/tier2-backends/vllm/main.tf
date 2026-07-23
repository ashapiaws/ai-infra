################################################################################
# vLLM Production Stack
#
# Deploys vLLM using the official production-stack Helm chart from
# https://vllm-project.github.io/production-stack
#
# This chart includes:
#   - vLLM serving engine (vllm/vllm-openai image)
#   - Request router for load balancing across replicas
#   - PVC for model weight caching
#   - Health/readiness probes
#
# Dependencies:
#   - NVIDIA GPU Operator (provides k8s-device-plugin for nvidia.com/gpu scheduling)
#     Must be installed before this module to register GPU resources with kubelet.
################################################################################

variable "chart_version" {
  description = "Helm chart version for vllm-stack"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "vllm"
}

variable "model_name" {
  description = "Name identifier for the model deployment"
  type        = string
  default     = "vllm"
}

variable "model_url" {
  description = "HuggingFace model ID (e.g. meta-llama/Llama-3.1-8B-Instruct)"
  type        = string
  default     = ""
}

variable "hf_token" {
  description = "HuggingFace API token for gated model access"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gpu_count" {
  description = "Number of GPUs per vLLM replica"
  type        = number
  default     = 1
}

variable "replica_count" {
  description = "Number of serving engine replicas"
  type        = number
  default     = 1
}

variable "pvc_storage" {
  description = "PVC storage size for model weights"
  type        = string
  default     = "50Gi"
}

variable "max_model_len" {
  description = "Maximum sequence length the model can handle"
  type        = number
  default     = 4096
}

variable "extra_args" {
  description = "Extra vLLM engine arguments"
  type        = list(string)
  default     = ["--gpu-memory-utilization", "0.9"]
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

################################################################################
# Helm Release - vLLM Production Stack
################################################################################

resource "helm_release" "vllm" {
  name             = "vllm"
  repository       = "https://vllm-project.github.io/production-stack"
  chart            = "vllm-stack"
  version          = var.chart_version != "" ? var.chart_version : null
  namespace        = var.namespace
  create_namespace = true

  # Model serving engine configuration via values
  values = [yamlencode({
    servingEngineSpec = {
      modelSpec = [
        {
          name         = var.model_name
          repository   = "vllm/vllm-openai"
          tag          = "latest"
          modelURL     = var.model_url
          replicaCount = var.replica_count

          requestCPU    = 6
          requestMemory = "16Gi"
          requestGPU    = var.gpu_count

          pvcStorage = var.pvc_storage

          vllmConfig = {
            enableChunkedPrefill = false
            enablePrefixCaching  = false
            maxModelLen          = var.max_model_len
            dtype                = "bfloat16"
            extraArgs            = var.extra_args
          }

          hf_token = var.hf_token
        }
      ]
    }
  })]
}

output "status" {
  description = "Deployment status"
  value       = helm_release.vllm.status
}

output "endpoint" {
  description = "Internal vLLM router service endpoint"
  value       = "http://vllm-router-service.${var.namespace}.svc.cluster.local:80"
}
