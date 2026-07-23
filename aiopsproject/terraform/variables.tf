# ML Infrastructure Platform - Variable Definitions
# Defines all input variables for the Terraform configuration

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-west-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format: us-west-2, eu-central-1, etc."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "vpc_id" {
  description = "ID of the existing VPC where resources will be deployed"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "VPC ID must be in the format: vpc-xxxxxxxxx."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs within the VPC for EKS cluster deployment (optional if using subnet_tag_filters)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for subnet_id in var.subnet_ids : can(regex("^subnet-[a-z0-9]+$", subnet_id))
    ])
    error_message = "All subnet IDs must be in the format: subnet-xxxxxxxxx."
  }
}

variable "subnet_tag_filters" {
  description = "Tag-based filters to select subnets for EKS cluster deployment (e.g., private subnets)"
  type = list(object({
    name   = string
    values = list(string)
  }))
  default = [
    {
      name   = "Name"
      values = ["*private*", "*priv*"]
    }
  ]

  validation {
    condition     = length(var.subnet_tag_filters) > 0
    error_message = "At least one subnet tag filter must be provided."
  }
}

variable "cluster_config" {
  description = "EKS cluster configuration including node groups and add-ons"
  type = object({
    cluster_name    = string
    cluster_version = string

    node_groups = object({
      cpu_nodes = object({
        instance_types      = list(string)
        min_size            = number
        max_size            = number
        desired_size        = number
        autoscaling_enabled = bool # Should be true for cost optimization
      })
      gpu_nodes = object({
        instance_types      = list(string)
        min_size            = number
        max_size            = number
        desired_size        = number
        autoscaling_enabled = bool # Should be false for cost control
      })
    })

    addons = object({
      nvidia_operator_enabled = bool
      efa_plugin_enabled      = bool
      prometheus_enabled      = bool
      grafana_enabled         = bool
    })
  })

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_config.cluster_name))
    error_message = "Cluster name must start with a letter and contain only alphanumeric characters and hyphens."
  }

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.cluster_config.cluster_version))
    error_message = "Cluster version must be in the format: 1.xx (e.g., 1.27, 1.28)."
  }

  validation {
    condition     = var.cluster_config.node_groups.cpu_nodes.autoscaling_enabled == true
    error_message = "CPU nodes must have autoscaling enabled for cost optimization."
  }

  validation {
    condition     = var.cluster_config.node_groups.gpu_nodes.autoscaling_enabled == false
    error_message = "GPU nodes must have autoscaling disabled for cost control."
  }

  validation {
    condition     = var.cluster_config.node_groups.cpu_nodes.min_size <= var.cluster_config.node_groups.cpu_nodes.desired_size && var.cluster_config.node_groups.cpu_nodes.desired_size <= var.cluster_config.node_groups.cpu_nodes.max_size
    error_message = "CPU node group: min_size <= desired_size <= max_size."
  }

  validation {
    condition     = var.cluster_config.node_groups.gpu_nodes.min_size <= var.cluster_config.node_groups.gpu_nodes.desired_size && var.cluster_config.node_groups.gpu_nodes.desired_size <= var.cluster_config.node_groups.gpu_nodes.max_size
    error_message = "GPU node group: min_size <= desired_size <= max_size."
  }
}

# Optional variables for advanced configuration
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_cluster_logging" {
  description = "Enable EKS cluster control plane logging"
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = "List of EKS cluster log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  validation {
    condition = alltrue([
      for log_type in var.cluster_log_types : contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "Log types must be one of: api, audit, authenticator, controllerManager, scheduler."
  }
}