# EKS Addons Module - Extensible Addon Management
# Supports both AWS EKS addons and third-party Helm addons

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local variables for addon configuration
locals {
  # Merge common AWS addon configurations with user-provided configurations
  # User configurations take precedence over defaults
  merged_aws_addons = {
    for addon_name in distinct(concat(keys(var.aws_addons), keys(local.common_aws_addons))) :
    addon_name => merge(
      lookup(local.common_aws_addons, addon_name, {}),
      lookup(var.aws_addons, addon_name, {})
    )
  }

  # Merge common Helm addon configurations with user-provided configurations
  # User configurations take precedence over defaults
  merged_helm_addons = {
    for addon_name in distinct(concat(keys(var.helm_addons), keys(local.common_helm_addons))) :
    addon_name => merge(
      lookup(local.common_helm_addons, addon_name, {}),
      lookup(var.helm_addons, addon_name, {})
    )
  }

  # AWS EKS Addons configuration (only enabled addons)
  aws_addons = {
    for addon_name, config in local.merged_aws_addons : addon_name => merge({
      addon_version               = null
      service_account_role_arn    = null
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      configuration_values        = null
      preserve                    = false
      tags                        = {}
    }, config)
    if config.enabled
  }

  # Third-party Helm addons configuration (only enabled addons)
  helm_addons = {
    for addon_name, config in local.merged_helm_addons : addon_name => merge({
      chart_version              = null
      repository                 = null
      namespace                  = "kube-system"
      create_namespace           = true
      values                     = []
      set                        = []
      set_sensitive              = []
      wait                       = true
      timeout                    = 300
      force_update               = false
      recreate_pods              = false
      max_history                = 0
      verify                     = false
      keyring                    = ""
      repository_key_file        = ""
      repository_cert_file       = ""
      repository_ca_file         = ""
      repository_username        = ""
      repository_password        = ""
      devel                      = false
      dependency_update          = false
      replace                    = false
      description                = ""
      postrender                 = []
      pass_credentials           = false
      lint                       = false
      cleanup_on_fail            = false
      atomic                     = false
      skip_crds                  = false
      render_subchart_notes      = true
      disable_openapi_validation = false
      wait_for_jobs              = false
      disable_webhooks           = false
      reuse_values               = false
      reset_values               = false
    }, config)
    if config.enabled
  }

  # Generate OIDC condition for service accounts
  oidc_url_without_protocol = replace(var.oidc_issuer_url, "https://", "")
}

# IAM Roles for AWS EKS Addons that require service accounts
resource "aws_iam_role" "addon_service_account" {
  for_each = {
    for addon_name, config in local.aws_addons : addon_name => config
    if config.create_service_account_role
  }

  name = "${var.cluster_name}-${each.key}-addon-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = merge(
            {
              "${local.oidc_url_without_protocol}:aud" = "sts.amazonaws.com"
            },
            each.value.service_account_conditions != null ? each.value.service_account_conditions : {}
          )
        }
      }
    ]
  })

  tags = merge(var.tags, each.value.tags, {
    Name = "${var.cluster_name}-${each.key}-addon-role"
  })
}

# IAM Role Policy Attachments for AWS EKS Addons
resource "aws_iam_role_policy_attachment" "addon_service_account" {
  for_each = {
    for pair in flatten([
      for addon_name, config in local.aws_addons : [
        for policy_arn in config.iam_policy_arns : {
          addon_name = addon_name
          policy_arn = policy_arn
        }
      ]
      if config.create_service_account_role && config.iam_policy_arns != null
    ]) : "${pair.addon_name}-${replace(pair.policy_arn, "/[^a-zA-Z0-9]/", "-")}" => pair
  }

  policy_arn = each.value.policy_arn
  role       = aws_iam_role.addon_service_account[each.value.addon_name].name
}

# Custom IAM Policies for addons (if needed)
resource "aws_iam_role_policy" "addon_custom_policy" {
  for_each = {
    for addon_name, config in local.aws_addons : addon_name => config
    if config.create_service_account_role && config.custom_iam_policy != null
  }

  name = "${var.cluster_name}-${each.key}-custom-policy"
  role = aws_iam_role.addon_service_account[each.key].id

  policy = each.value.custom_iam_policy
}

# AWS EKS Addons
resource "aws_eks_addon" "this" {
  for_each = local.aws_addons

  cluster_name             = var.cluster_name
  addon_name               = each.key
  addon_version            = each.value.addon_version
  service_account_role_arn = each.value.create_service_account_role ? aws_iam_role.addon_service_account[each.key].arn : each.value.service_account_role_arn

  resolve_conflicts_on_create = each.value.resolve_conflicts_on_create
  resolve_conflicts_on_update = each.value.resolve_conflicts_on_update

  configuration_values = each.value.configuration_values
  preserve             = each.value.preserve

  tags = merge(var.tags, each.value.tags)

  depends_on = [
    aws_iam_role_policy_attachment.addon_service_account,
    aws_iam_role_policy.addon_custom_policy
  ]
}

# Kubernetes Namespaces for Helm addons (if needed)
resource "kubernetes_namespace" "helm_addon" {
  for_each = {
    for addon_name, config in local.helm_addons : addon_name => config
    if config.create_namespace && config.namespace != "kube-system"
  }

  metadata {
    name = each.value.namespace

    labels = merge(
      {
        name                           = each.value.namespace
        "app.kubernetes.io/managed-by" = "terraform"
      },
      each.value.namespace_labels != null ? each.value.namespace_labels : {}
    )

    annotations = each.value.namespace_annotations != null ? each.value.namespace_annotations : {}
  }
}

# Service Accounts for Helm addons (if needed)
resource "kubernetes_service_account" "helm_addon" {
  for_each = {
    for addon_name, config in local.helm_addons : addon_name => config
    if config.create_service_account
  }

  metadata {
    name      = each.value.service_account_name
    namespace = each.value.namespace

    annotations = merge(
      each.value.service_account_role_arn != null ? {
        "eks.amazonaws.com/role-arn" = each.value.service_account_role_arn
      } : {},
      each.value.service_account_annotations != null ? each.value.service_account_annotations : {}
    )

    labels = each.value.service_account_labels != null ? each.value.service_account_labels : {}
  }

  automount_service_account_token = each.value.automount_service_account_token != null ? each.value.automount_service_account_token : true

  depends_on = [kubernetes_namespace.helm_addon]
}

# IAM Roles for Helm addons that require service accounts
resource "aws_iam_role" "helm_addon_service_account" {
  for_each = {
    for addon_name, config in local.helm_addons : addon_name => config
    if config.create_service_account && config.create_service_account_role
  }

  name = "${var.cluster_name}-${each.key}-helm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = merge(
            {
              "${local.oidc_url_without_protocol}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.service_account_name}"
              "${local.oidc_url_without_protocol}:aud" = "sts.amazonaws.com"
            },
            each.value.service_account_conditions != null ? each.value.service_account_conditions : {}
          )
        }
      }
    ]
  })

  tags = merge(var.tags, each.value.tags != null ? each.value.tags : {}, {
    Name = "${var.cluster_name}-${each.key}-helm-role"
  })
}

# IAM Role Policy Attachments for Helm addons
resource "aws_iam_role_policy_attachment" "helm_addon_service_account" {
  for_each = {
    for pair in flatten([
      for addon_name, config in local.helm_addons : [
        for policy_arn in config.iam_policy_arns : {
          addon_name = addon_name
          policy_arn = policy_arn
        }
      ]
      if config.create_service_account && config.create_service_account_role && config.iam_policy_arns != null
    ]) : "${pair.addon_name}-${replace(pair.policy_arn, "/[^a-zA-Z0-9]/", "-")}" => pair
  }

  policy_arn = each.value.policy_arn
  role       = aws_iam_role.helm_addon_service_account[each.value.addon_name].name
}

# Custom IAM Policies for Helm addons (if needed)
resource "aws_iam_role_policy" "helm_addon_custom_policy" {
  for_each = {
    for addon_name, config in local.helm_addons : addon_name => config
    if config.create_service_account && config.create_service_account_role && config.custom_iam_policy != null
  }

  name = "${var.cluster_name}-${each.key}-helm-custom-policy"
  role = aws_iam_role.helm_addon_service_account[each.key].id

  policy = each.value.custom_iam_policy
}

# Helm Releases for third-party addons
resource "helm_release" "this" {
  for_each = local.helm_addons

  name       = each.key
  chart      = each.value.chart
  repository = each.value.repository
  version    = each.value.chart_version
  namespace  = each.value.namespace

  create_namespace = each.value.create_namespace && each.value.namespace != "kube-system"

  values = each.value.values

  dynamic "set" {
    for_each = each.value.set
    content {
      name  = set.value.name
      value = set.value.value
      type  = lookup(set.value, "type", null)
    }
  }

  dynamic "set_sensitive" {
    for_each = each.value.set_sensitive
    content {
      name  = set_sensitive.value.name
      value = set_sensitive.value.value
      type  = lookup(set_sensitive.value, "type", null)
    }
  }

  dynamic "postrender" {
    for_each = each.value.postrender
    content {
      binary_path = postrender.value.binary_path
      args        = lookup(postrender.value, "args", null)
    }
  }

  wait                       = each.value.wait
  timeout                    = each.value.timeout
  force_update               = each.value.force_update
  recreate_pods              = each.value.recreate_pods
  max_history                = each.value.max_history
  verify                     = each.value.verify
  keyring                    = each.value.keyring
  repository_key_file        = each.value.repository_key_file
  repository_cert_file       = each.value.repository_cert_file
  repository_ca_file         = each.value.repository_ca_file
  repository_username        = each.value.repository_username
  repository_password        = each.value.repository_password
  devel                      = each.value.devel
  dependency_update          = each.value.dependency_update
  replace                    = each.value.replace
  description                = each.value.description
  pass_credentials           = each.value.pass_credentials
  lint                       = each.value.lint
  cleanup_on_fail            = each.value.cleanup_on_fail
  atomic                     = each.value.atomic
  skip_crds                  = each.value.skip_crds
  render_subchart_notes      = each.value.render_subchart_notes
  disable_openapi_validation = each.value.disable_openapi_validation
  wait_for_jobs              = each.value.wait_for_jobs
  disable_webhooks           = each.value.disable_webhooks
  reuse_values               = each.value.reuse_values
  reset_values               = each.value.reset_values

  depends_on = [
    kubernetes_namespace.helm_addon,
    kubernetes_service_account.helm_addon,
    aws_iam_role_policy_attachment.helm_addon_service_account,
    aws_iam_role_policy.helm_addon_custom_policy
  ]
}