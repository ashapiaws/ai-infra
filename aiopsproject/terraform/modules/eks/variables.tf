# EKS Module Variables

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "cluster_service_role_arn" {
  description = "ARN of the IAM role for the EKS cluster service"
  type        = string
}

variable "node_group_role_arn" {
  description = "ARN of the IAM role for EKS node groups"
  type        = string
}

variable "cpu_node_config" {
  description = "Configuration for CPU node group"
  type = object({
    instance_types      = list(string)
    min_size            = number
    max_size            = number
    desired_size        = number
    autoscaling_enabled = bool
  })
}

variable "gpu_node_config" {
  description = "Configuration for GPU node group"
  type = object({
    instance_types      = list(string)
    min_size            = number
    max_size            = number
    desired_size        = number
    autoscaling_enabled = bool
  })
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "nvidia_operator_enabled" {
  description = "Whether to enable NVIDIA Operator"
  type        = bool
  default     = true
}

variable "efa_plugin_enabled" {
  description = "Whether to enable EFA Plugin"
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = "List of EKS cluster log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "ssh_key_name" {
  description = "Name of the EC2 Key Pair for node group access"
  type        = string
  default     = null
}

# Enhanced VPC integration variables
variable "enable_public_access" {
  description = "Whether to enable public API server endpoint access"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs to allow access to the cluster"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}