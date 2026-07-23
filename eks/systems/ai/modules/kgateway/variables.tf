variable "chart_version" {
  description = "Helm chart version for KGateway"
  type        = string
  default     = "2.0.3"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
