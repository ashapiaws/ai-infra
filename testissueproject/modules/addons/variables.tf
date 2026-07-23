# EKS Addons Module Variables

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "oidc_issuer_url" {
  description = "URL of the OIDC issuer for the EKS cluster"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "aws_addons" {
  description = "Configuration for AWS EKS addons"
  type = map(object({
    enabled                     = bool
    addon_version               = optional(string)
    service_account_role_arn    = optional(string)
    create_service_account_role = optional(bool, false)
    iam_policy_arns             = optional(list(string))
    custom_iam_policy           = optional(string)
    service_account_conditions  = optional(map(string))
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    configuration_values        = optional(string)
    preserve                    = optional(bool, false)
    tags                        = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for addon_name, config in var.aws_addons :
      contains([
        "vpc-cni",
        "coredns",
        "kube-proxy",
        "aws-ebs-csi-driver",
        "aws-efs-csi-driver",
        "aws-fsx-csi-driver",
        "aws-load-balancer-controller",
        "adot",
        "eks-pod-identity-agent",
        "snapshot-controller",
        "aws-guardduty-agent",
        "aws-mountpoint-s3-csi-driver",
        "metrics-server"
      ], addon_name)
    ])
    error_message = "Invalid AWS addon name. Must be one of the supported EKS addons."
  }
}

variable "helm_addons" {
  description = "Configuration for third-party Helm addons"
  type = map(object({
    enabled          = bool
    chart            = string
    chart_version    = optional(string)
    repository       = optional(string)
    namespace        = optional(string, "kube-system")
    create_namespace = optional(bool, true)
    values           = optional(list(string), [])
    set = optional(list(object({
      name  = string
      value = string
      type  = optional(string)
    })), [])
    set_sensitive = optional(list(object({
      name  = string
      value = string
      type  = optional(string)
    })), [])

    # Service Account configuration
    create_service_account          = optional(bool, false)
    service_account_name            = optional(string)
    create_service_account_role     = optional(bool, false)
    service_account_role_arn        = optional(string)
    iam_policy_arns                 = optional(list(string))
    custom_iam_policy               = optional(string)
    service_account_conditions      = optional(map(string))
    service_account_annotations     = optional(map(string))
    service_account_labels          = optional(map(string))
    automount_service_account_token = optional(bool)

    # Namespace configuration
    namespace_labels      = optional(map(string))
    namespace_annotations = optional(map(string))

    # Helm configuration
    wait                 = optional(bool, true)
    timeout              = optional(number, 300)
    force_update         = optional(bool, false)
    recreate_pods        = optional(bool, false)
    max_history          = optional(number, 0)
    verify               = optional(bool, false)
    keyring              = optional(string, "")
    repository_key_file  = optional(string, "")
    repository_cert_file = optional(string, "")
    repository_ca_file   = optional(string, "")
    repository_username  = optional(string, "")
    repository_password  = optional(string, "")
    devel                = optional(bool, false)
    dependency_update    = optional(bool, false)
    replace              = optional(bool, false)
    description          = optional(string, "")
    postrender = optional(list(object({
      binary_path = string
      args        = optional(list(string))
    })), [])
    pass_credentials           = optional(bool, false)
    lint                       = optional(bool, false)
    cleanup_on_fail            = optional(bool, false)
    atomic                     = optional(bool, false)
    skip_crds                  = optional(bool, false)
    render_subchart_notes      = optional(bool, true)
    disable_openapi_validation = optional(bool, false)
    wait_for_jobs              = optional(bool, false)
    disable_webhooks           = optional(bool, false)
    reuse_values               = optional(bool, false)
    reset_values               = optional(bool, false)

    tags = optional(map(string), {})
  }))
  default = {}
}