# EKS Addons Module Outputs

output "aws_addons" {
  description = "Information about installed AWS EKS addons"
  value = {
    for addon_name, addon in aws_eks_addon.this : addon_name => {
      arn           = addon.arn
      addon_version = addon.addon_version
      created_at    = addon.created_at
      modified_at   = addon.modified_at
    }
  }
}

output "helm_addons" {
  description = "Information about installed Helm addons"
  value = {
    for addon_name, addon in helm_release.this : addon_name => {
      name      = addon.name
      chart     = addon.chart
      version   = addon.version
      namespace = addon.namespace
      status    = addon.status
      # revision  = addon.revision
    }
  }
}

output "aws_addon_service_account_roles" {
  description = "IAM roles created for AWS addon service accounts"
  value = {
    for addon_name, role in aws_iam_role.addon_service_account : addon_name => {
      arn  = role.arn
      name = role.name
    }
  }
}

output "helm_addon_service_account_roles" {
  description = "IAM roles created for Helm addon service accounts"
  value = {
    for addon_name, role in aws_iam_role.helm_addon_service_account : addon_name => {
      arn  = role.arn
      name = role.name
    }
  }
}

output "helm_addon_namespaces" {
  description = "Namespaces created for Helm addons"
  value = {
    for addon_name, namespace in kubernetes_namespace.helm_addon : addon_name => {
      name = namespace.metadata[0].name
    }
  }
}

output "helm_addon_service_accounts" {
  description = "Service accounts created for Helm addons"
  value = {
    for addon_name, sa in kubernetes_service_account.helm_addon : addon_name => {
      name      = sa.metadata[0].name
      namespace = sa.metadata[0].namespace
    }
  }
}