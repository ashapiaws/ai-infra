# --- Optional: Prometheus + Grafana via Helm ---

# IRSA for Prometheus (to write to AMP if needed)
module "prometheus_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.37"

  count = var.enable_prometheus ? 1 : 0

  role_name = "${var.cluster_name}-prometheus"

  role_policy_arns = {
    AmazonPrometheusRemoteWriteAccess = "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["monitoring:prometheus-server"]
    }
  }

  tags = var.tags
}

# Prometheus
resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = "monitoring"
  version    = "25.11.0"

  create_namespace = true

  set {
    name  = "server.persistentVolume.storageClass"
    value = "gp3"
  }

  set {
    name  = "server.retention"
    value = "7d"
  }

  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  depends_on = [module.eks, kubectl_manifest.gp3_storage_class]
}

# Grafana
resource "helm_release" "grafana" {
  count = var.enable_grafana ? 1 : 0

  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "monitoring"
  version    = "7.3.0"

  create_namespace = true

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.storageClassName"
    value = "gp3"
  }

  set {
    name  = "adminPassword"
    value = "admin" # Override in production
  }

  # Add Prometheus as data source
  values = [<<-YAML
    datasources:
      datasources.yaml:
        apiVersion: 1
        datasources:
          - name: Prometheus
            type: prometheus
            url: http://prometheus-server.monitoring.svc.cluster.local
            isDefault: true
          - name: CloudWatch
            type: cloudwatch
            jsonData:
              defaultRegion: ${var.region}
  YAML
  ]

  depends_on = [module.eks, helm_release.prometheus]
}
