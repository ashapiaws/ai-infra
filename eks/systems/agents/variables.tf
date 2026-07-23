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

variable "enable_redis" {
  description = "Deploy Redis for agent state/message queues"
  type        = bool
  default     = true
}

variable "enable_temporal" {
  description = "Deploy Temporal for durable agent workflow execution"
  type        = bool
  default     = false
}

variable "enable_mcp_gateway" {
  description = "Deploy MCP Gateway for tool registry and routing"
  type        = bool
  default     = false
}

################################################################################
# Component Versions
################################################################################

variable "redis_version" {
  description = "Helm chart version for Redis"
  type        = string
  default     = "19.6.4"
}

variable "temporal_version" {
  description = "Helm chart version for Temporal"
  type        = string
  default     = "0.45.0"
}

variable "mcp_gateway_version" {
  description = "Helm chart version for MCP Gateway"
  type        = string
  default     = "0.1.0"
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
