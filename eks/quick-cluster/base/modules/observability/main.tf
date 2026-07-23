################################################################################
# Observability Module
# CloudWatch Container Insights (default) + optional Prometheus/Grafana
################################################################################

locals {
  oidc_issuer = replace(var.oidc_provider_url, "https://", "")
}

################################################################################
# CloudWatch Container Insights (via ADOT Collector)
################################################################################

resource "aws_iam_role" "cloudwatch" {
  count = var.enable_cloudwatch ? 1 : 0
  name  = "${var.cluster_name}-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  count      = var.enable_cloudwatch ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch[0].name
}

resource "aws_eks_addon" "cloudwatch_observability" {
  count                    = var.enable_cloudwatch ? 1 : 0
  cluster_name             = var.cluster_name
  addon_name               = "amazon-cloudwatch-observability"
  service_account_role_arn = aws_iam_role.cloudwatch[0].arn
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}

################################################################################
# Prometheus (kube-prometheus-stack includes Grafana)
################################################################################

resource "helm_release" "prometheus_stack" {
  count = var.enable_prometheus_grafana ? 1 : 0

  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 600
  wait             = true

  set = [
    {
      name  = "grafana.enabled"
      value = "true"
    },
    {
      name  = "grafana.service.type"
      value = "ClusterIP"
    },
    {
      name  = "prometheus.prometheusSpec.retention"
      value = "7d"
    },
    {
      name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
      value = "50Gi"
    },
    {
      name  = "alertmanager.enabled"
      value = "true"
    },
  ]
}
