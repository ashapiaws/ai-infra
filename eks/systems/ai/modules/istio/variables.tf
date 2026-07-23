variable "chart_version" {
  description = "Helm chart version for Istio components"
  type        = string
  default     = "1.24.2"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
