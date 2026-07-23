################################################################################
# Cluster Configuration
################################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "aws_region" {
  description = "AWS region for the cluster"
  type        = string
  default     = "us-west-2"
}

variable "vpc_id" {
  description = "ID of the existing VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the cluster. If empty, auto-discovered via tags."
  type        = list(string)
  default     = []
}

################################################################################
# System Node Group
################################################################################

variable "system_instance_types" {
  description = "Instance types for the system/workload node group"
  type        = list(string)
  default     = ["m6i.xlarge"]
}

variable "system_desired_size" {
  description = "Desired number of system nodes"
  type        = number
  default     = 2
}

variable "system_min_size" {
  description = "Minimum number of system nodes"
  type        = number
  default     = 1
}

variable "system_max_size" {
  description = "Maximum number of system nodes"
  type        = number
  default     = 5
}

variable "system_disk_size" {
  description = "Disk size in GB for system nodes"
  type        = number
  default     = 100
}

################################################################################
# GPU Node Group
################################################################################

variable "enable_gpu_nodes" {
  description = "Enable a GPU node group"
  type        = bool
  default     = false
}

variable "gpu_instance_types" {
  description = "Instance types for the GPU node group"
  type        = list(string)
  default     = ["g6.xlarge"]
}

variable "gpu_desired_size" {
  description = "Desired number of GPU nodes"
  type        = number
  default     = 3
}

variable "gpu_min_size" {
  description = "Minimum number of GPU nodes"
  type        = number
  default     = 0
}

variable "gpu_max_size" {
  description = "Maximum number of GPU nodes"
  type        = number
  default     = 6
}

variable "gpu_disk_size" {
  description = "Disk size in GB for GPU nodes"
  type        = number
  default     = 200
}

variable "gpu_ami_type" {
  description = "AMI type for GPU nodes (AL2_x86_64_GPU, AL2023_x86_64_NVIDIA)"
  type        = string
  default     = "AL2023_x86_64_NVIDIA"
}

variable "gpu_capacity_type" {
  description = "Instance capacity type ON_DEMAND or SPOT"
  type        = list(string)
  default     = ["SPOT"]
}


################################################################################
# EFA (Elastic Fabric Adapter)
################################################################################

variable "enable_efa" {
  description = "Enable EFA on the GPU node group for high-bandwidth networking"
  type        = bool
  default     = false
}

################################################################################
# CSI Driver Toggles
################################################################################

variable "enable_ebs_csi" {
  description = "Deploy the EBS CSI driver as an EKS addon"
  type        = bool
  default     = true
}

variable "enable_efs_csi" {
  description = "Deploy the EFS CSI driver as an EKS addon"
  type        = bool
  default     = false
}

variable "enable_fsx_csi" {
  description = "Deploy the FSx for Lustre CSI driver via Helm"
  type        = bool
  default     = false
}

################################################################################
# Networking
################################################################################

variable "enable_cilium" {
  description = "Deploy Cilium as the CNI (replaces VPC CNI)"
  type        = bool
  default     = false
}

################################################################################
# Karpenter (Node Autoscaling)
################################################################################

variable "enable_karpenter" {
  description = "Deploy Karpenter for node autoscaling"
  type        = bool
  default     = false
}

################################################################################
# AWS Load Balancer Controller
################################################################################

variable "enable_aws_lb_controller" {
  description = "Deploy AWS Load Balancer Controller for ALB/NLB ingress"
  type        = bool
  default     = false
}

################################################################################
# Observability Toggles
################################################################################

variable "enable_cloudwatch" {
  description = "Deploy CloudWatch observability (Container Insights)"
  type        = bool
  default     = true
}

variable "enable_prometheus_grafana" {
  description = "Deploy Prometheus and Grafana in-cluster"
  type        = bool
  default     = false
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
