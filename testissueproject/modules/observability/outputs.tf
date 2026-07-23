# Observability Module Outputs

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring components"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_endpoint" {
  description = "Prometheus server endpoint"
  value       = "http://kube-prometheus-stack-prometheus.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9090"
}

output "grafana_endpoint" {
  description = "Grafana endpoint"
  value = var.observability_config.grafana.ingress.enabled ? (
    var.observability_config.grafana.ingress.tls_enabled ?
    "https://${var.observability_config.grafana.ingress.host}" :
    "http://${var.observability_config.grafana.ingress.host}"
  ) : "http://kube-prometheus-stack-grafana.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local"
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.observability_config.grafana.admin_password
  sensitive   = true
}

output "alertmanager_endpoint" {
  description = "AlertManager endpoint"
  value       = var.observability_config.alertmanager.enabled ? "http://kube-prometheus-stack-alertmanager.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9093" : null
}

output "prometheus_service_account_arn" {
  description = "ARN of the Prometheus service account IAM role (if IRSA enabled)"
  value       = var.enable_irsa ? aws_iam_role.prometheus[0].arn : null
}

output "helm_release_status" {
  description = "Status of the kube-prometheus-stack Helm release"
  value       = helm_release.kube_prometheus_stack.status
}

output "helm_release_version" {
  description = "Version of the deployed kube-prometheus-stack Helm chart"
  value       = helm_release.kube_prometheus_stack.version
}

output "monitoring_endpoints" {
  description = "All monitoring service endpoints"
  value = {
    prometheus = "http://kube-prometheus-stack-prometheus.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9090"
    grafana = var.observability_config.grafana.ingress.enabled ? (
      var.observability_config.grafana.ingress.tls_enabled ?
      "https://${var.observability_config.grafana.ingress.host}" :
      "http://${var.observability_config.grafana.ingress.host}"
    ) : "http://kube-prometheus-stack-grafana.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local"
    alertmanager = var.observability_config.alertmanager.enabled ? "http://kube-prometheus-stack-alertmanager.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9093" : null
  }
}

output "storage_classes" {
  description = "Created GP3 storage classes"
  value = var.observability_config.storage_classes.create_gp3_classes ? {
    gp3                 = "gp3"
    gp3_high_iops       = "gp3-high-iops"
    gp3_high_throughput = "gp3-high-throughput"
    gp3_xfs             = "gp3-xfs"
    default_class       = var.observability_config.storage_classes.default_class
  } : {}
}