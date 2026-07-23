terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
}

locals {
  name = "test-gitops"
  tags = {
    Example = local.name
    env     = "dev"
    role    = "gitops"
    team    = "dev-team"
  }
  vpc_id     = ""
  subnet_ids = []
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${local.name}-cluster-01"
  kubernetes_version = "1.34"

  # EKS Addons
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_POD_ENI                    = "true"
          ENABLE_PREFIX_DELEGATION          = "true"
          ENABLE_NETWORK_POLICY_CONTROLLER = "true"
          AWS_VPC_CNI_NODE_PORT_SUPPORT    = "true"
          ENABLE_BANDWIDTH_PLUGIN           = "true"
        }
      })
    }
    aws-load-balancer-controller = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = aws_iam_role.ebs_csi.arn
    }
    vpc-cni-observability-agent = {
      service_account_role_arn = aws_iam_role.vpc_cni_observability.arn
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    ng-01 = {
      
      instance_types = ["m6i.large"]
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size = 3
      max_size = 5
      desired_size = 2

    #cloud-init config, setup NVMe for RAID0
      cloudinit_pre_nodeadm = [
      {
        content_type = "application/node.eks.aws"
        content      = <<-EOT
          ---
          apiVersion: node.eks.aws/v1alpha1
          kind: NodeConfig
          spec:
            kubelet:
              config:
                shutdownGracePeriod: 30s
                maxPods: 110
            storage:
              blockDeviceMapping:
                - deviceName: /dev/nvme1n1
                  raid:
                    level: 0
                    devices:
                      - /dev/nvme1n1
                      - /dev/nvme2n1
                    mountPoint: /mnt/nvme-raid0
                    filesystem: ext4
                    mountOptions: "defaults,noatime"
        EOT
      }
    ]

    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size = 50
          volume_type = "gp3"
          encrypted   = true
        }
      }
    }
  }
  }

  tags = local.tags

}
# Add after your EKS module
data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role_policy.json
  name               = "${local.name}-aws-load-balancer-controller"
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# EBS CSI Driver IAM Role
data "aws_iam_policy_document" "ebs_csi_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role_policy.json
  name               = "${local.name}-ebs-csi-driver"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_attach" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/Amazon_EBS_CSI_DriverPolicy"
}

# VPC CNI Observability Agent IAM Role
data "aws_iam_policy_document" "vpc_cni_observability_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:aws-observability:vpc-cni-observability-agent"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "vpc_cni_observability" {
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_observability_assume_role_policy.json
  name               = "${local.name}-vpc-cni-observability"
}

resource "aws_iam_role_policy_attachment" "vpc_cni_observability_attach" {
  role       = aws_iam_role.vpc_cni_observability.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Prometheus Helm Release
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "61.3.2"

  create_namespace = true

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "20Gi"
                  }
                }
              }
            }
          }
        }
      }
      grafana = {
        persistence = {
          enabled          = true
          storageClassName = "gp2"
          size             = "5Gi"
        }
        adminPassword = "admin123"
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [{
              name    = "aws-vpc-cni"
              type    = "file"
              options = {
                path = "/var/lib/grafana/dashboards/aws-vpc-cni"
              }
            }]
          }
        }
        dashboards = {
          "aws-vpc-cni" = {
            "vpc-cni-metrics" = {
              url = "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/cni-metrics-helper/grafana-dashboard.json"
            }
          }
        }
      }
    })
  ]

  depends_on = [module.eks]
}