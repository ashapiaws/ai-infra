variable "chart_version" {
  description = "Helm chart version for Volcano"
  type        = string
  default     = "1.10.0"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
