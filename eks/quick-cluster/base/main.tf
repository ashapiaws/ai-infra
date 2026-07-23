################################################################################
# Provider Configuration
################################################################################

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

locals {
  subnet_ids = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : data.aws_subnets.private.ids
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  gpu_node_groups = var.enable_gpu_nodes ? {
    gpu = {
      name           = "${var.cluster_name}-gpu"
      instance_types = var.gpu_instance_types
      ami_type       = var.gpu_ami_type

      min_size     = var.gpu_min_size
      max_size     = var.gpu_max_size
      desired_size = var.gpu_desired_size

      disk_size = var.gpu_disk_size

      labels = {
        "node-role"              = "gpu"
        "nvidia.com/gpu.present" = "true"
      }

      taints = {
        gpu_no_schedule = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      # EFA support for multi-node training
      network_interfaces = var.enable_efa ? [
        {
          delete_on_termination = true
          device_index          = 0
          interface_type        = "efa"
        }
      ] : []

      tags = {
        "node-group" = "gpu"
      }
    }
  } : {}
}

################################################################################
# EKS Cluster (terraform-aws-modules/eks/aws v21.x)
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = local.subnet_ids

  # Cluster access
  endpoint_public_access  = true
  endpoint_private_access = true

  # Allow current caller admin access
  enable_cluster_creator_admin_permissions = true

  # No CW log groups = faster destroy
  enabled_log_types = []

  # EKS Managed Addons - critical ones use before_compute for fresh clusters
  addons = merge(
    {
      eks-pod-identity-agent = {
        most_recent                 = true
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "OVERWRITE"
        before_compute              = true
      }
      vpc-cni = {
        most_recent                 = true
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "OVERWRITE"
        before_compute              = true
      }
      kube-proxy = {
        most_recent                 = true
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "OVERWRITE"
        before_compute              = true
      }
      coredns = {
        most_recent                 = true
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "OVERWRITE"
        before_compute              = true
      }
    },
    var.enable_ebs_csi ? {
      aws-ebs-csi-driver = {
        most_recent                 = true
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "OVERWRITE"
        preserve                    = false
      }
    } : {},
    var.enable_efs_csi ? {
      aws-efs-csi-driver = {
        most_recent                 = true
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "OVERWRITE"
        preserve                    = false
      }
    } : {},
    var.enable_cloudwatch ? {
      amazon-cloudwatch-observability = {
        most_recent                 = true
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "OVERWRITE"
        preserve                    = false
      }
    } : {},
  )

  # Node Groups
  eks_managed_node_groups = merge(
    {
      system = {
        name           = "${var.cluster_name}-system"
        instance_types = var.system_instance_types
        ami_type       = "AL2023_x86_64_STANDARD"

        min_size     = var.system_min_size
        max_size     = var.system_max_size
        desired_size = var.system_desired_size

        disk_size = var.system_disk_size

        labels = {
          "node-role" = "system"
        }

        tags = {
          "node-group" = "system"
        }
      }
    },
    local.gpu_node_groups,
  )

  tags = var.tags
}

################################################################################
# Pod Identity: EBS CSI Driver
################################################################################

module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"
  count   = var.enable_ebs_csi ? 1 : 0

  name = "${var.cluster_name}-ebs-csi"

  attach_aws_ebs_csi_policy = true
  aws_ebs_csi_kms_arns      = ["arn:aws:kms:*:${local.account_id}:key/*"]

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }

  tags = var.tags
}

################################################################################
# Pod Identity: EFS CSI Driver
################################################################################

module "efs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"
  count   = var.enable_efs_csi ? 1 : 0

  name = "${var.cluster_name}-efs-csi"

  attach_aws_efs_csi_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "efs-csi-controller-sa"
    }
  }

  tags = var.tags
}

################################################################################
# Pod Identity: VPC CNI
################################################################################

module "vpc_cni_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name = "${var.cluster_name}-vpc-cni"

  attach_aws_vpc_cni_policy = true
  aws_vpc_cni_enable_ipv4   = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-node"
    }
  }

  tags = var.tags
}

################################################################################
# Pod Identity: AWS Load Balancer Controller
################################################################################

module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"
  count   = var.enable_aws_lb_controller ? 1 : 0

  name = "${var.cluster_name}-aws-lb-controller"

  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = var.tags
}

resource "helm_release" "aws_lb_controller" {
  count = var.enable_aws_lb_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.11.0"
  wait       = false
  timeout    = 300

  cleanup_on_fail = true
  replace         = true
  force_update    = true

  set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    },
    {
      name  = "enableServiceMutatorWebhook"
      value = "false"
    },
  ]

  depends_on = [module.eks, module.aws_lb_controller_pod_identity]
}

################################################################################
# Pod Identity: FSx for Lustre CSI Driver
################################################################################

module "fsx_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"
  count   = var.enable_fsx_csi ? 1 : 0

  name = "${var.cluster_name}-fsx-lustre-csi"

  attach_aws_fsx_lustre_csi_policy     = true
  aws_fsx_lustre_csi_service_role_arns = ["arn:aws:iam::*:role/aws-service-role/s3.data-source.lustre.fsx.amazonaws.com/*"]

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "fsx-csi-controller-sa"
    }
  }

  tags = var.tags
}

################################################################################
# Cilium CNI (optional, replaces VPC CNI)
################################################################################

module "cilium" {
  source = "./modules/cilium"
  count  = var.enable_cilium ? 1 : 0

  cluster_name    = module.eks.cluster_name
  cluster_version = var.cluster_version
  tags            = var.tags

  depends_on = [module.eks]
}

################################################################################
# Karpenter (Node Autoscaling) - Pod Identity is default in v21
################################################################################

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"
  count   = var.enable_karpenter ? 1 : 0

  cluster_name = module.eks.cluster_name

  # Pod Identity is now the default in v21 (no enable_pod_identity flag needed)
  # The module creates the pod identity association automatically

  # Create the node IAM role that Karpenter-launched nodes will use
  create_node_iam_role          = true
  node_iam_role_use_name_prefix = false
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}

resource "helm_release" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name             = "karpenter"
  namespace        = "kube-system"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.1.1"
  wait             = false
  timeout          = 600

  cleanup_on_fail = true
  replace         = true
  force_update    = true

  set = [
    {
      name  = "settings.clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "settings.clusterEndpoint"
      value = module.eks.cluster_endpoint
    },
    {
      name  = "settings.interruptionQueue"
      value = module.karpenter[0].queue_name
    },
  ]

  depends_on = [module.eks, module.karpenter]
}

################################################################################
# Observability (Prometheus + Grafana, optional)
################################################################################

module "observability" {
  source = "./modules/observability"
  count  = var.enable_prometheus_grafana ? 1 : 0

  cluster_name      = module.eks.cluster_name
  aws_region        = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_issuer_url

  enable_cloudwatch         = false
  enable_prometheus_grafana = true

  tags = var.tags

  depends_on = [module.eks]
}
