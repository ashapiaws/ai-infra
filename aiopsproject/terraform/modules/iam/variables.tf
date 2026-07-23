# IAM Module Variables

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "model_registry_bucket" {
  description = "Name of the S3 bucket for model registry"
  type        = string
  default     = ""
}

variable "artifacts_bucket" {
  description = "Name of the S3 bucket for training artifacts"
  type        = string
  default     = ""
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
  default     = ""
}

variable "oidc_issuer_url" {
  description = "URL of the OIDC issuer"
  type        = string
  default     = ""
}