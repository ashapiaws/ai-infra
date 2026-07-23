variable "cluster_name" {
  description = "EKS cluster name"
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

variable "enable_ebs" {
  description = "Enable EBS CSI driver"
  type        = bool
  default     = true
}

variable "enable_efs" {
  description = "Enable EFS CSI driver"
  type        = bool
  default     = false
}

variable "enable_fsx" {
  description = "Enable FSx for Lustre CSI driver"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
