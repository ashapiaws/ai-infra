variable "chart_version" {
  description = "Helm chart version for Bifrost AI Gateway"
  type        = string
  default     = "0.1.0"
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
