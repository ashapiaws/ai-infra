# EKS Observability Stack - Variables
# Comprehensive variable definitions with validation

variable "aws_region" {
  description = "AWS region for the EKS cluster"
  type        = string
  default     = "us-west-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format 'us-west-2'."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name)) && length(var.cluster_name) <= 100
    error_message = "Cluster name must start with a letter, contain only alphanumeric characters and hyphens, and be less than 100 characters."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"

  validation {
    condition     = can(regex("^1\\.(2[4-9]|[3-9][0-9])$", var.kubernetes_version))
    error_message = "Kubernetes version must be 1.24 or higher."
  }
}

variable "vpc_id" {
  description = "ID of the existing VPC where the EKS cluster will be deployed"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]{8,17}$", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC identifier."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster and node groups. If empty, subnets will be automatically discovered based on subnet_type"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for s in var.subnet_ids : can(regex("^subnet-[a-z0-9]{8,17}$", s))])
    error_message = "All subnet IDs must be valid AWS subnet identifiers."
  }
}

variable "subnet_type" {
  description = "Type of subnets to use when subnet_ids is empty. 'private' for private subnets, 'public' for public subnets"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["private", "public"], var.subnet_type)
    error_message = "Subnet type must be either 'private' or 'public'."
  }
}

variable "min_subnet_count" {
  description = "Minimum number of subnets required for the EKS cluster"
  type        = number
  default     = 2

  validation {
    condition     = var.min_subnet_count >= 2
    error_message = "At least 2 subnets are required for EKS cluster high availability."
  }
}

variable "subnet_name_patterns" {
  description = "Regex patterns to identify private and public subnets by name"
  type = object({
    private = string
    public  = string
  })
  default = {
    private = "(?i)(priv|private)"
    public  = "(?i)(pub|public)"
  }

  validation {
    condition     = can(regex(var.subnet_name_patterns.private, "private")) && can(regex(var.subnet_name_patterns.public, "public"))
    error_message = "Subnet name patterns must be valid regex expressions that match 'private' and 'public' respectively."
  }
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

  validation {
    condition     = var.endpoint_config.private_access || var.endpoint_config.public_access
    error_message = "Either private_access or public_access must be enabled."
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

  validation {
    condition = alltrue([
      for log_type in var.logging_config.enable_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "Log types must be one of: api, audit, authenticator, controllerManager, scheduler."
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

  default = {
    primary = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      scaling_config = {
        min_size     = 1
        max_size     = 5
        desired_size = 2
      }

      placement_group = {
        strategy = "cluster"
        enabled  = true
      }

      labels = {
        role = "primary"
      }
      taints = []

      ami_type  = "AL2_x86_64"
      disk_size = 20

      raid0_config = {
        enabled     = false
        mount_point = "/mnt/raid0"
        filesystem  = "ext4"
      }
    }

    secondary = {
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"

      scaling_config = {
        min_size     = 0
        max_size     = 10
        desired_size = 1
      }

      placement_group = {
        strategy = "cluster"
        enabled  = true
      }

      labels = {
        role = "secondary"
      }
      taints = []

      ami_type  = "AL2_x86_64"
      disk_size = 20

      raid0_config = {
        enabled     = false
        mount_point = "/mnt/raid0"
        filesystem  = "ext4"
      }
    }
  }

  validation {
    condition     = length(var.node_groups) == 2
    error_message = "Exactly 2 node groups must be configured."
  }

  validation {
    condition = alltrue([
      for ng in values(var.node_groups) :
      ng.scaling_config.min_size <= ng.scaling_config.desired_size &&
      ng.scaling_config.desired_size <= ng.scaling_config.max_size
    ])
    error_message = "Node group scaling configuration must satisfy: min_size <= desired_size <= max_size."
  }
}

variable "observability_config" {
  description = "Configuration for the observability stack (Prometheus and Grafana)"
  type = object({
    namespace = string

    # Storage class configuration
    storage_classes = object({
      create_gp3_classes = bool
      default_class      = string
    })

    prometheus = object({
      chart_version       = string
      retention_days      = number
      storage_class       = string
      storage_size        = string
      scrape_interval     = string
      evaluation_interval = string

      resource_limits = object({
        cpu    = string
        memory = string
      })
      resource_requests = object({
        cpu    = string
        memory = string
      })
    })

    grafana = object({
      chart_version  = string
      admin_password = string
      storage_class  = string
      storage_size   = string

      ingress = object({
        enabled     = bool
        host        = string
        tls_enabled = bool
        annotations = map(string)
      })

      resource_limits = object({
        cpu    = string
        memory = string
      })
      resource_requests = object({
        cpu    = string
        memory = string
      })
    })

    alertmanager = object({
      enabled       = bool
      storage_class = string
      storage_size  = string

      resource_limits = object({
        cpu    = string
        memory = string
      })
      resource_requests = object({
        cpu    = string
        memory = string
      })
    })
  })

  default = {
    namespace = "monitoring"

    # Storage class configuration
    storage_classes = {
      create_gp3_classes = true
      default_class      = "gp3"
    }

    prometheus = {
      chart_version       = "25.8.0"
      retention_days      = 15
      storage_class       = "gp3"
      storage_size        = "50Gi"
      scrape_interval     = "30s"
      evaluation_interval = "30s"

      resource_limits = {
        cpu    = "2000m"
        memory = "4Gi"
      }
      resource_requests = {
        cpu    = "500m"
        memory = "2Gi"
      }
    }

    grafana = {
      chart_version  = "7.0.8"
      admin_password = "admin123!"
      storage_class  = "gp3"
      storage_size   = "10Gi"

      ingress = {
        enabled     = false
        host        = ""
        tls_enabled = false
        annotations = {}
      }

      resource_limits = {
        cpu    = "500m"
        memory = "1Gi"
      }
      resource_requests = {
        cpu    = "250m"
        memory = "512Mi"
      }
    }

    alertmanager = {
      enabled       = true
      storage_class = "gp3"
      storage_size  = "10Gi"

      resource_limits = {
        cpu    = "200m"
        memory = "256Mi"
      }
      resource_requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.observability_config.namespace))
    error_message = "Namespace must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "eks-observability-stack"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# Remote Access Configuration (Optional)
variable "enable_remote_access" {
  description = "Enable SSH access to worker nodes"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "EC2 Key Pair name for SSH access to worker nodes"
  type        = string
  default     = ""
}

variable "remote_access_security_group_ids" {
  description = "List of security group IDs for remote access to worker nodes"
  type        = list(string)
  default     = []
}

# IRSA Configuration (Optional)
variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA) for Prometheus"
  type        = bool
  default     = false
}

variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver addon"
  type        = string
  default     = "v1.36.0-eksbuild.1"
}

variable "aws_addons" {
  description = "Configuration for AWS EKS addons"
  type = map(object({
    enabled                     = bool
    addon_version               = optional(string)
    service_account_role_arn    = optional(string)
    create_service_account_role = optional(bool, false)
    iam_policy_arns             = optional(list(string))
    custom_iam_policy           = optional(string)
    service_account_conditions  = optional(map(string))
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    configuration_values        = optional(string)
    preserve                    = optional(bool, false)
    tags                        = optional(map(string), {})
  }))
  default = {}
}

variable "helm_addons" {
  description = "Configuration for third-party Helm addons"
  type = map(object({
    enabled          = bool
    chart            = string
    chart_version    = optional(string)
    repository       = optional(string)
    namespace        = optional(string, "kube-system")
    create_namespace = optional(bool, true)
    values           = optional(list(string), [])
    set = optional(list(object({
      name  = string
      value = string
      type  = optional(string)
    })), [])
    set_sensitive = optional(list(object({
      name  = string
      value = string
      type  = optional(string)
    })), [])

    # Service Account configuration
    create_service_account          = optional(bool, false)
    service_account_name            = optional(string)
    create_service_account_role     = optional(bool, false)
    service_account_role_arn        = optional(string)
    iam_policy_arns                 = optional(list(string))
    custom_iam_policy               = optional(string)
    service_account_conditions      = optional(map(string))
    service_account_annotations     = optional(map(string))
    service_account_labels          = optional(map(string))
    automount_service_account_token = optional(bool)

    # Namespace configuration
    namespace_labels      = optional(map(string))
    namespace_annotations = optional(map(string))

    # Helm configuration
    wait                 = optional(bool, true)
    timeout              = optional(number, 300)
    force_update         = optional(bool, false)
    recreate_pods        = optional(bool, false)
    max_history          = optional(number, 0)
    verify               = optional(bool, false)
    keyring              = optional(string, "")
    repository_key_file  = optional(string, "")
    repository_cert_file = optional(string, "")
    repository_ca_file   = optional(string, "")
    repository_username  = optional(string, "")
    repository_password  = optional(string, "")
    devel                = optional(bool, false)
    dependency_update    = optional(bool, false)
    replace              = optional(bool, false)
    description          = optional(string, "")
    postrender = optional(list(object({
      binary_path = string
      args        = optional(list(string))
    })), [])
    pass_credentials           = optional(bool, false)
    lint                       = optional(bool, false)
    cleanup_on_fail            = optional(bool, false)
    atomic                     = optional(bool, false)
    skip_crds                  = optional(bool, false)
    render_subchart_notes      = optional(bool, true)
    disable_openapi_validation = optional(bool, false)
    wait_for_jobs              = optional(bool, false)
    disable_webhooks           = optional(bool, false)
    reuse_values               = optional(bool, false)
    reset_values               = optional(bool, false)

    tags = optional(map(string), {})
  }))
  default = {}
}