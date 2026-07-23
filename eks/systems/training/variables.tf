################################################################################
# Cluster & Network
################################################################################

variable "aws_region" {
  description = "AWS region where the EKS cluster resides"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  type        = string
}

################################################################################
# Component Toggles
################################################################################

variable "enable_nvidia_operator" {
  description = "Deploy the NVIDIA GPU Operator (required for GPU training)"
  type        = bool
  default     = true
}

variable "enable_volcano" {
  description = "Deploy Volcano batch scheduler for gang scheduling"
  type        = bool
  default     = true
}

variable "enable_kuberay" {
  description = "Deploy KubeRay operator for distributed Ray clusters"
  type        = bool
  default     = true
}

variable "enable_flyte" {
  description = "Deploy Flyte for ML workflow orchestration"
  type        = bool
  default     = true
}

################################################################################
# Component Versions
################################################################################

variable "nvidia_operator_version" {
  description = "Helm chart version for the NVIDIA GPU Operator"
  type        = string
  default     = "v24.9.2"
}

variable "volcano_version" {
  description = "Helm chart version for Volcano"
  type        = string
  default     = "1.10.0"
}

variable "kuberay_version" {
  description = "Helm chart version for KubeRay"
  type        = string
  default     = "1.2.2"
}

variable "flyte_version" {
  description = "Helm chart version for Flyte"
  type        = string
  default     = "v1.13.2"
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
