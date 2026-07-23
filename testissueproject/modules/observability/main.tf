# Observability Module - Simplified
# Deploys kube-prometheus-stack using Helm

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.observability_config.namespace

    labels = {
      name = var.observability_config.namespace
    }
  }
}

# GP3 Storage Classes for high-performance workloads
resource "kubernetes_storage_class" "gp3" {
  count = var.observability_config.storage_classes.create_gp3_classes ? 1 : 0

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = var.observability_config.storage_classes.default_class == "gp3" ? "true" : "false"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
    # GP3 performance parameters (can be overridden per PVC)
    iops       = "3000" # Base IOPS (3000-16000)
    throughput = "125"  # Base throughput in MiB/s (125-1000)
  }
}

# GP3 Storage Class optimized for high IOPS workloads
resource "kubernetes_storage_class" "gp3_high_iops" {
  count = var.observability_config.storage_classes.create_gp3_classes ? 1 : 0

  metadata {
    name = "gp3-high-iops"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = var.observability_config.storage_classes.default_class == "gp3-high-iops" ? "true" : "false"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
    # High IOPS configuration
    iops       = "10000" # High IOPS for databases
    throughput = "500"   # High throughput
  }
}

# GP3 Storage Class optimized for high throughput workloads
resource "kubernetes_storage_class" "gp3_high_throughput" {
  count = var.observability_config.storage_classes.create_gp3_classes ? 1 : 0

  metadata {
    name = "gp3-high-throughput"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = var.observability_config.storage_classes.default_class == "gp3-high-throughput" ? "true" : "false"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
    # High throughput configuration
    iops       = "6000" # Balanced IOPS
    throughput = "1000" # Maximum throughput
  }
}

# GP3 Storage Class with XFS filesystem for large files
resource "kubernetes_storage_class" "gp3_xfs" {
  count = var.observability_config.storage_classes.create_gp3_classes ? 1 : 0

  metadata {
    name = "gp3-xfs"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = var.observability_config.storage_classes.default_class == "gp3-xfs" ? "true" : "false"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type       = "gp3"
    fsType     = "xfs" # XFS for large files and high performance
    encrypted  = "true"
    iops       = "4000"
    throughput = "250"
  }
}

# Service account for Prometheus with IRSA (optional)
resource "kubernetes_service_account" "prometheus" {
  count = var.enable_irsa ? 1 : 0

  metadata {
    name      = "prometheus-server"
    namespace = kubernetes_namespace.monitoring.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.prometheus[0].arn
    }
  }

  automount_service_account_token = true
}

# IAM role for Prometheus (IRSA) - optional
resource "aws_iam_role" "prometheus" {
  count = var.enable_irsa ? 1 : 0

  name = "${var.cluster_name}-prometheus-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.oidc_issuer_url, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.observability_config.namespace}:prometheus-server"
            "${replace(var.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for Prometheus to access CloudWatch (optional)
resource "aws_iam_role_policy" "prometheus" {
  count = var.enable_irsa ? 1 : 0

  name = "${var.cluster_name}-prometheus-policy"
  role = aws_iam_role.prometheus[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# kube-prometheus-stack Helm Chart
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.observability_config.prometheus.chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  # Core Prometheus configuration
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "${var.observability_config.prometheus.retention_days}d"
  }

  set {
    name  = "prometheus.prometheusSpec.scrapeInterval"
    value = var.observability_config.prometheus.scrape_interval
  }

  set {
    name  = "prometheus.prometheusSpec.evaluationInterval"
    value = var.observability_config.prometheus.evaluation_interval
  }

  # Prometheus storage
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = var.observability_config.prometheus.storage_class
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.observability_config.prometheus.storage_size
  }

  # Prometheus resources
  set {
    name  = "prometheus.prometheusSpec.resources.limits.cpu"
    value = var.observability_config.prometheus.resource_limits.cpu
  }

  set {
    name  = "prometheus.prometheusSpec.resources.limits.memory"
    value = var.observability_config.prometheus.resource_limits.memory
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = var.observability_config.prometheus.resource_requests.cpu
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = var.observability_config.prometheus.resource_requests.memory
  }

  # Grafana configuration
  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "grafana.adminPassword"
    value = var.observability_config.grafana.admin_password
  }

  # Grafana persistence
  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }

  set {
    name  = "grafana.persistence.storageClassName"
    value = var.observability_config.grafana.storage_class
  }

  set {
    name  = "grafana.persistence.size"
    value = var.observability_config.grafana.storage_size
  }

  # Grafana resources
  set {
    name  = "grafana.resources.limits.cpu"
    value = var.observability_config.grafana.resource_limits.cpu
  }

  set {
    name  = "grafana.resources.limits.memory"
    value = var.observability_config.grafana.resource_limits.memory
  }

  set {
    name  = "grafana.resources.requests.cpu"
    value = var.observability_config.grafana.resource_requests.cpu
  }

  set {
    name  = "grafana.resources.requests.memory"
    value = var.observability_config.grafana.resource_requests.memory
  }

  # Grafana ingress (optional)
  set {
    name  = "grafana.ingress.enabled"
    value = var.observability_config.grafana.ingress.enabled
  }

  dynamic "set" {
    for_each = var.observability_config.grafana.ingress.enabled ? [1] : []
    content {
      name  = "grafana.ingress.hosts[0]"
      value = var.observability_config.grafana.ingress.host
    }
  }

  # AlertManager configuration
  set {
    name  = "alertmanager.enabled"
    value = var.observability_config.alertmanager.enabled
  }

  dynamic "set" {
    for_each = var.observability_config.alertmanager.enabled ? [1] : []
    content {
      name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName"
      value = var.observability_config.alertmanager.storage_class
    }
  }

  dynamic "set" {
    for_each = var.observability_config.alertmanager.enabled ? [1] : []
    content {
      name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
      value = var.observability_config.alertmanager.storage_size
    }
  }

  # Node Exporter
  set {
    name  = "nodeExporter.enabled"
    value = "true"
  }

  # kube-state-metrics
  set {
    name  = "kubeStateMetrics.enabled"
    value = "true"
  }

  # Prometheus Operator
  set {
    name  = "prometheusOperator.enabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.monitoring]
}