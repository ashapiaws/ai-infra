variable "chart_version" {
  description = "Helm chart version for Envoy AI Gateway"
  type        = string
  default     = "0.4.0"
}

variable "inference_router" {
  description = "Which inference backend to route to: 'vllm', 'sglang', or 'both'"
  type        = string
  default     = "vllm"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
