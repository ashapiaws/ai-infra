variable "chart_version" {
  description = "Helm chart version for Flyte"
  type        = string
  default     = "v1.13.2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster (used for Flyte config)"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
