variable "chart_version" {
  description = "Helm chart version for SGLang"
  type        = string
  default     = "0.4.5"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
