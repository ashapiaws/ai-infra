variable "chart_version" {
  description = "Helm chart version for vLLM"
  type        = string
  default     = "0.7.3"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
