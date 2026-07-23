# EKS Cluster Module Variables

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_id" {
  description = "ID of the existing VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "endpoint_config" {
  description = "EKS cluster endpoint configuration"
  type = object({
    private_access      = bool
    public_access       = bool
    public_access_cidrs = list(string)
  })
  default = {
    private_access      = true
    public_access       = true
    public_access_cidrs = ["0.0.0.0/0"]
  }
}

variable "logging_config" {
  description = "EKS cluster logging configuration"
  type = object({
    enable_types   = list(string)
    retention_days = number
  })
  default = {
    enable_types   = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    retention_days = 7
  }
}

variable "encryption_config" {
  description = "EKS cluster encryption configuration"
  type = object({
    resources  = list(string)
    kms_key_id = string
  })
  default = {
    resources  = ["secrets"]
    kms_key_id = ""
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}