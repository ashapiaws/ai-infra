# --- CloudWatch Container Insights + Fluent Bit ---

# IRSA role for CloudWatch agent
module "cloudwatch_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.37"

  role_name = "${var.cluster_name}-cloudwatch-agent"

  role_policy_arns = {
    CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:cloudwatch-agent"]
    }
  }

  tags = var.tags
}

# IRSA role for Fluent Bit (log forwarding)
module "fluentbit_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.37"

  role_name = "${var.cluster_name}-fluent-bit"

  role_policy_arns = {
    CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:fluent-bit"]
    }
  }

  tags = var.tags
}

# CloudWatch Observability add-on (Container Insights + Fluent Bit)
resource "helm_release" "cloudwatch_observability" {
  count = var.enable_container_insights ? 1 : 0

  name       = "amazon-cloudwatch-observability"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-cloudwatch-observability"
  namespace  = "amazon-cloudwatch"
  version    = "1.7.0"

  create_namespace = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "containerInsights.enabled"
    value = "true"
  }

  set {
    name  = "containerLogs.enabled"
    value = "true"
  }

  depends_on = [module.eks, module.cloudwatch_irsa, module.fluentbit_irsa]
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/eks/${var.cluster_name}/app"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = var.tags
}

# CloudWatch Log Group for cluster logs
resource "aws_cloudwatch_log_group" "cluster_logs" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = var.tags
}
