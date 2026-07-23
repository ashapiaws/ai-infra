# EKS Node Groups Module Variables

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for node groups"
  type        = list(string)
}

variable "node_groups" {
  description = "Configuration for EKS managed node groups"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string

    scaling_config = object({
      min_size     = number
      max_size     = number
      desired_size = number
    })

    placement_group = object({
      strategy = string
      enabled  = bool
    })

    labels = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))

    ami_type  = string
    disk_size = number

    # RAID0 configuration for local NVMe storage
    raid0_config = object({
      enabled     = bool
      mount_point = string
      filesystem  = string
    })
  }))
}

variable "enable_remote_access" {
  description = "Enable remote access to worker nodes"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "EC2 Key Pair name for SSH access to worker nodes"
  type        = string
  default     = ""
}

variable "remote_access_security_group_ids" {
  description = "List of security group IDs for remote access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}