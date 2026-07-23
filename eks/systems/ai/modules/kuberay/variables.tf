variable "chart_version" {
  description = "Helm chart version for KubeRay operator"
  type        = string
  default     = "1.2.2"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
