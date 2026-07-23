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

################################################################################
# Envoy Configuration
################################################################################

variable "envoy_image" {
  description = "Envoy proxy container image"
  type        = string
  default     = "envoyproxy/envoy:v1.32-latest"
}

variable "envoy_namespace" {
  description = "Kubernetes namespace for Envoy deployment"
  type        = string
  default     = "envoy-gateway"
}

variable "envoy_replicas" {
  description = "Number of Envoy proxy replicas"
  type        = number
  default     = 2
}

variable "envoy_service_type" {
  description = "Kubernetes service type for Envoy (LoadBalancer, ClusterIP, NodePort)"
  type        = string
  default     = "LoadBalancer"
}

variable "enable_admin_interface" {
  description = "Enable Envoy admin interface (disable in production)"
  type        = bool
  default     = true
}

variable "admin_port" {
  description = "Port for the Envoy admin interface"
  type        = number
  default     = 9901
}

variable "listener_port" {
  description = "Primary listener port"
  type        = number
  default     = 8080
}

################################################################################
# Upstream Backends
################################################################################

variable "upstream_clusters" {
  description = "Map of upstream cluster definitions for Envoy to route to"
  type = map(object({
    address = string
    port    = number
  }))
  default = {}
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
