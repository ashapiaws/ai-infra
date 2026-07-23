variable "chart_version" {
  description = "Helm chart version for the NVIDIA GPU Operator"
  type        = string
  default     = "v24.9.2"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
