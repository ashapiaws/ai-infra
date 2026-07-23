# Observability Module Variables

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  type        = string
}

variable "oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  type        = string
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA) for Prometheus"
  type        = bool
  default     = false
}

variable "observability_config" {
  description = "Configuration for the observability stack"
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
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}