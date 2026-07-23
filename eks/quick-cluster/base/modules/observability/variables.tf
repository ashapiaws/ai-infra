variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL (issuer)"
  type        = string
}

variable "enable_cloudwatch" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "enable_prometheus_grafana" {
  description = "Enable in-cluster Prometheus and Grafana"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
