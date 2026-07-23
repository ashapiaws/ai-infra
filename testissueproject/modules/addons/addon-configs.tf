# Pre-configured addon configurations for common use cases
# These provide default configurations that are merged with user-provided values

locals {
  # Common AWS EKS Addon Configurations (defaults)
  common_aws_addons = {
    # EBS CSI Driver - for persistent volumes
    "aws-ebs-csi-driver" = {
      enabled                     = true
      addon_version               = "v1.36.0-eksbuild.1"
      create_service_account_role = true
      iam_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      ]
      service_account_conditions = {
        "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
      }
    }

    # EFS CSI Driver - for shared file systems
    "aws-efs-csi-driver" = {
      enabled                     = false # Disabled by default
      addon_version               = "v2.1.1-eksbuild.1"
      create_service_account_role = true
      iam_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
      ]
      service_account_conditions = {
        "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
      }
    }

    # FSx CSI Driver - for high-performance file systems
    "aws-fsx-csi-driver" = {
      enabled                     = false # Disabled by default
      addon_version               = "v1.2.0-eksbuild.1"
      create_service_account_role = true
      iam_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonFSxFullAccess"
      ]
      service_account_conditions = {
        "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:fsx-csi-controller-sa"
      }
    }

    # AWS Load Balancer Controller - for ALB/NLB integration (EKS addon version)
    "aws-load-balancer-controller" = {
      enabled                     = false # Disabled by default
      addon_version               = "v1.8.0-eksbuild.1"
      create_service_account_role = true
      custom_iam_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "iam:CreateServiceLinkedRole"
            ]
            Resource = "*"
            Condition = {
              StringEquals = {
                "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
              }
            }
          },
          {
            Effect = "Allow"
            Action = [
              "ec2:DescribeAccountAttributes",
              "ec2:DescribeAddresses",
              "ec2:DescribeAvailabilityZones",
              "ec2:DescribeInternetGateways",
              "ec2:DescribeVpcs",
              "ec2:DescribeVpcPeeringConnections",
              "ec2:DescribeSubnets",
              "ec2:DescribeSecurityGroups",
              "ec2:DescribeInstances",
              "ec2:DescribeNetworkInterfaces",
              "ec2:DescribeTags",
              "ec2:GetCoipPoolUsage",
              "ec2:GetIpamPoolCidrs",
              "ec2:DescribeCoipPools",
              "elasticloadbalancing:DescribeLoadBalancers",
              "elasticloadbalancing:DescribeLoadBalancerAttributes",
              "elasticloadbalancing:DescribeListeners",
              "elasticloadbalancing:DescribeListenerCertificates",
              "elasticloadbalancing:DescribeSSLPolicies",
              "elasticloadbalancing:DescribeRules",
              "elasticloadbalancing:DescribeTargetGroups",
              "elasticloadbalancing:DescribeTargetGroupAttributes",
              "elasticloadbalancing:DescribeTargetHealth",
              "elasticloadbalancing:DescribeTags"
            ]
            Resource = "*"
          },
          {
            Effect = "Allow"
            Action = [
              "cognito-idp:DescribeUserPoolClient",
              "acm:ListCertificates",
              "acm:DescribeCertificate",
              "iam:ListServerCertificates",
              "iam:GetServerCertificate",
              "waf-regional:GetWebACL",
              "waf-regional:GetWebACLForResource",
              "waf-regional:AssociateWebACL",
              "waf-regional:DisassociateWebACL",
              "wafv2:GetWebACL",
              "wafv2:GetWebACLForResource",
              "wafv2:AssociateWebACL",
              "wafv2:DisassociateWebACL",
              "shield:DescribeProtection",
              "shield:GetSubscriptionState",
              "shield:DescribeSubscription",
              "shield:CreateProtection",
              "shield:DeleteProtection"
            ]
            Resource = "*"
          },
          {
            Effect = "Allow"
            Action = [
              "ec2:AuthorizeSecurityGroupIngress",
              "ec2:RevokeSecurityGroupIngress"
            ]
            Resource = "*"
          },
          {
            Effect = "Allow"
            Action = [
              "ec2:CreateSecurityGroup"
            ]
            Resource = "*"
          },
          {
            Effect = "Allow"
            Action = [
              "ec2:CreateTags"
            ]
            Resource = "arn:aws:ec2:*:*:security-group/*"
            Condition = {
              StringEquals = {
                "ec2:CreateAction" = "CreateSecurityGroup"
              }
              Null = {
                "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
              }
            }
          },
          {
            Effect = "Allow"
            Action = [
              "ec2:CreateTags",
              "ec2:DeleteTags"
            ]
            Resource = "arn:aws:ec2:*:*:security-group/*"
            Condition = {
              Null = {
                "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
                "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
              }
            }
          },
          {
            Effect = "Allow"
            Action = [
              "ec2:AuthorizeSecurityGroupIngress",
              "ec2:RevokeSecurityGroupIngress",
              "ec2:DeleteSecurityGroup"
            ]
            Resource = "*"
            Condition = {
              Null = {
                "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
              }
            }
          },
          {
            Effect = "Allow"
            Action = [
              "elasticloadbalancing:CreateLoadBalancer",
              "elasticloadbalancing:CreateTargetGroup"
            ]
            Resource = "*"
            Condition = {
              Null = {
                "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
              }
            }
          },
          {
            Effect = "Allow"
            Action = [
              "elasticloadbalancing:CreateListener",
              "elasticloadbalancing:DeleteListener",
              "elasticloadbalancing:CreateRule",
              "elasticloadbalancing:DeleteRule"
            ]
            Resource = "*"
          },
          {
            Effect = "Allow"
            Action = [
              "elasticloadbalancing:AddTags",
              "elasticloadbalancing:RemoveTags"
            ]
            Resource = [
              "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
              "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
              "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ]
            Condition = {
              Null = {
                "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
                "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
              }
            }
          },
          {
            Effect = "Allow"
            Action = [
              "elasticloadbalancing:AddTags",
              "elasticloadbalancing:RemoveTags"
            ]
            Resource = [
              "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
              "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
              "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
              "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
            ]
          },
          {
            Effect = "Allow"
            Action = [
              "elasticloadbalancing:ModifyLoadBalancerAttributes",
              "elasticloadbalancing:SetIpAddressType",
              "elasticloadbalancing:SetSecurityGroups",
              "elasticloadbalancing:SetSubnets",
              "elasticloadbalancing:DeleteLoadBalancer",
              "elasticloadbalancing:ModifyTargetGroup",
              "elasticloadbalancing:ModifyTargetGroupAttributes",
              "elasticloadbalancing:DeleteTargetGroup"
            ]
            Resource = "*"
            Condition = {
              Null = {
                "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
              }
            }
          },
          {
            Effect = "Allow"
            Action = [
              "elasticloadbalancing:AddTags"
            ]
            Resource = [
              "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
              "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
              "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ]
            Condition = {
              StringEquals = {
                "elasticloadbalancing:CreateAction" = [
                  "CreateTargetGroup",
                  "CreateLoadBalancer"
                ]
              }
              Null = {
                "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
              }
            }
          },
          {
            Effect = "Allow"
            Action = [
              "elasticloadbalancing:RegisterTargets",
              "elasticloadbalancing:DeregisterTargets"
            ]
            Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
          }
        ]
      })
      service_account_conditions = {
        "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
      }
    }
  }

  # Common Helm Addon Configurations
  common_helm_addons = {
    # NVIDIA GPU Operator
    "nvidia-gpu-operator" = {
      enabled          = false # Disabled by default
      chart            = "gpu-operator"
      chart_version    = "v24.9.0"
      repository       = "https://helm.ngc.nvidia.com/nvidia"
      namespace        = "gpu-operator"
      create_namespace = true
      wait             = true
      timeout          = 600 # GPU operator takes longer to install

      # Use values file instead of set blocks
      values = [
        file("${path.module}/helm-values/nvidia-gpu-operator.yaml")
      ]

      namespace_labels = {
        "pod-security.kubernetes.io/enforce" = "privileged"
        "pod-security.kubernetes.io/audit"   = "privileged"
        "pod-security.kubernetes.io/warn"    = "privileged"
      }
    }

    # Cluster Autoscaler
    "cluster-autoscaler" = {
      enabled                     = false # Disabled by default
      chart                       = "cluster-autoscaler"
      chart_version               = "9.37.0"
      repository                  = "https://kubernetes.github.io/autoscaler"
      namespace                   = "kube-system"
      create_namespace            = false
      create_service_account      = true
      service_account_name        = "cluster-autoscaler"
      create_service_account_role = true
      iam_policy_arns = [
        "arn:aws:iam::aws:policy/AutoScalingFullAccess"
      ]
      custom_iam_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "autoscaling:DescribeAutoScalingGroups",
              "autoscaling:DescribeAutoScalingInstances",
              "autoscaling:DescribeLaunchConfigurations",
              "autoscaling:DescribeScalingActivities",
              "autoscaling:DescribeTags",
              "ec2:DescribeImages",
              "ec2:DescribeInstanceTypes",
              "ec2:DescribeLaunchTemplateVersions",
              "ec2:GetInstanceTypesFromInstanceRequirements",
              "eks:DescribeNodegroup"
            ]
            Resource = "*"
          },
          {
            Effect = "Allow"
            Action = [
              "autoscaling:SetDesiredCapacity",
              "autoscaling:TerminateInstanceInAutoScalingGroup"
            ]
            Resource = "*"
          }
        ]
      })

      # Use values file with template substitution
      values = [
        templatefile("${path.module}/helm-values/cluster-autoscaler.yaml", {
          cluster_name = var.cluster_name
          aws_region   = data.aws_region.current.name
        })
      ]
    }

    # Metrics Server (if not using EKS managed version)
    "metrics-server" = {
      enabled          = false # Disabled by default, EKS usually has this
      chart            = "metrics-server"
      chart_version    = "3.12.1"
      repository       = "https://kubernetes-sigs.github.io/metrics-server/"
      namespace        = "kube-system"
      create_namespace = false

      # Use values file
      values = [
        file("${path.module}/helm-values/metrics-server.yaml")
      ]
    }

    # Prometheus Node Exporter (standalone deployment)
    "prometheus-node-exporter" = {
      enabled          = false # Disabled by default, usually part of kube-prometheus-stack
      chart            = "prometheus-node-exporter"
      chart_version    = "4.39.0"
      repository       = "https://prometheus-community.github.io/helm-charts"
      namespace        = "monitoring"
      create_namespace = false

      # Use values file
      values = [
        file("${path.module}/helm-values/prometheus-node-exporter.yaml")
      ]
    }
  }
}