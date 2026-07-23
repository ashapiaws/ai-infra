# EKS Observability Stack - Outputs
# Expose key information for external consumption

# EKS Cluster Outputs
output "cluster_id" {
  description = "ID of the EKS cluster"
  value       = module.eks_cluster.cluster_id
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks_cluster.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks_cluster.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks_cluster.cluster_security_group_id
}

output "oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks_cluster.oidc_issuer_url
}

# Node Group Outputs
output "node_group_arns" {
  description = "ARNs of the EKS node groups"
  value       = module.node_groups.node_group_arns
}

output "node_group_status" {
  description = "Status of the EKS node groups"
  value       = module.node_groups.node_group_status
}

output "placement_group_ids" {
  description = "IDs of the placement groups"
  value       = module.node_groups.placement_group_ids
}

# Observability Outputs
output "prometheus_endpoint" {
  description = "Prometheus server endpoint"
  value       = module.observability.prometheus_endpoint
}

output "grafana_endpoint" {
  description = "Grafana endpoint"
  value       = module.observability.grafana_endpoint
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = module.observability.grafana_admin_password
  sensitive   = true
}

output "alertmanager_endpoint" {
  description = "AlertManager endpoint"
  value       = module.observability.alertmanager_endpoint
}

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring components"
  value       = module.observability.monitoring_namespace
}

# Connection Information
output "kubectl_config_command" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_id}"
}

output "cluster_info" {
  description = "Comprehensive cluster information"
  value = {
    cluster_name       = module.eks_cluster.cluster_id
    cluster_region     = var.aws_region
    cluster_version    = module.eks_cluster.cluster_version
    vpc_id             = var.vpc_id
    subnet_ids         = local.selected_subnet_ids
    subnet_type        = var.subnet_type
    node_groups        = keys(var.node_groups)
    monitoring_enabled = true
  }
}

# Subnet Discovery Information
output "subnet_discovery_info" {
  description = "Detailed information about subnet discovery and classification"
  value = {
    vpc_id                = var.vpc_id
    subnet_type           = var.subnet_type
    total_subnets_found   = length(data.aws_subnets.all.ids)
    private_subnets_found = length(local.private_subnet_ids)
    public_subnets_found  = length(local.public_subnet_ids)
    selected_subnets      = local.selected_subnet_ids
    subnet_count          = local.subnet_count
    explicit_subnets_used = length(var.subnet_ids) > 0

    # Detailed subnet information
    selected_subnet_details = local.subnet_details

    # All subnets summary for debugging
    all_subnets_summary = local.all_subnets_summary
  }
}

# Storage Classes Information
output "storage_classes" {
  description = "Available GP3 storage classes for high-performance workloads"
  value       = module.observability.storage_classes
}

# Addons Outputs
output "aws_addons" {
  description = "Information about installed AWS EKS addons"
  value       = module.addons.aws_addons
}

output "helm_addons" {
  description = "Information about installed Helm addons"
  value       = module.addons.helm_addons
}

output "addon_service_account_roles" {
  description = "IAM roles created for addon service accounts"
  value = {
    aws_addons  = module.addons.aws_addon_service_account_roles
    helm_addons = module.addons.helm_addon_service_account_roles
  }
}