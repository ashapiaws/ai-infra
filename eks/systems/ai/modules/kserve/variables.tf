variable "chart_version" {
  description = "Helm chart version for KServe"
  type        = string
  default     = "0.14.1"
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
