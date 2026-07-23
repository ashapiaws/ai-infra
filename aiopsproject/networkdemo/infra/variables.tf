# Cluster Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"

  validation {
    condition     = can(regex("^\\d+\\.\\d+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in the format 'X.Y' (e.g., '1.28')."
  }
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
}

# Network Configuration
variable "vpc_id" {
  description = "ID of the existing VPC where the EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS cluster and nodes. Must be in the specified VPC."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for high availability."
  }
}

variable "enable_public_access" {
  description = "Enable public access to cluster API endpoint. Set to false for maximum security."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API endpoint. Only used if enable_public_access is true."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Node Group Configuration
variable "node_instance_types" {
  description = "List of instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 2

  validation {
    condition     = var.node_group_min_size >= 1
    error_message = "Minimum node group size must be at least 1."
  }
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 10

  validation {
    condition     = var.node_group_max_size >= 1
    error_message = "Maximum node group size must be at least 1."
  }
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 3

  validation {
    condition     = var.node_group_desired_size >= 1
    error_message = "Desired node group size must be at least 1."
  }
}

variable "capacity_type" {
  description = "Type of capacity for the node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "Capacity type must be either 'ON_DEMAND' or 'SPOT'."
  }
}

variable "disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 20
}

# Security Configuration
variable "kms_key_arn" {
  description = "ARN of KMS key for cluster encryption. If not provided, AWS managed key will be used."
  type        = string
  default     = null
}

# Add-on Versions
# Setting these to null will use the latest compatible version for the cluster
variable "vpc_cni_version" {
  description = "Version of VPC CNI add-on. Set to null to use latest compatible version."
  type        = string
  default     = null
}

variable "coredns_version" {
  description = "Version of CoreDNS add-on. Set to null to use latest compatible version."
  type        = string
  default     = null
}

variable "kube_proxy_version" {
  description = "Version of kube-proxy add-on. Set to null to use latest compatible version."
  type        = string
  default     = null
}

variable "ebs_csi_version" {
  description = "Version of EBS CSI driver add-on. Set to null to use latest compatible version."
  type        = string
  default     = null
}

variable "lb_controller_version" {
  description = "Version of AWS Load Balancer Controller add-on. Set to null to use latest compatible version."
  type        = string
  default     = null
}

variable "cloudwatch_observability_version" {
  description = "Version of CloudWatch Observability add-on. Set to null to use latest compatible version."
  type        = string
  default     = null
}

variable "adot_version" {
  description = "Version of ADOT (AWS Distro for OpenTelemetry) add-on. Set to null to use latest compatible version."
  type        = string
  default     = null
}

# IAM Configuration
variable "additional_cluster_iam_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to the cluster IAM role"
  type        = list(string)
  default     = []
}

variable "additional_node_iam_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to the node group IAM role"
  type        = list(string)
  default     = []
}

# Tagging
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
