provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name   = var.cluster_name
  region = var.region
  tags   = var.tags
}

################################################################################
# Data Sources
################################################################################

# Get VPC info from existing subnets
data "aws_subnet" "private_subnet" {
  id = var.subnet_ids[0]
}

data "aws_vpc" "existing_vpc" {
  id = data.aws_subnet.private_subnet.vpc_id
}

# Create placement group for GPU instances
resource "aws_placement_group" "cluster_placement_group" {
  name     = var.placement_group_name
  strategy = "cluster"
  tags     = local.tags
}

################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # OIDC Identity provider
  cluster_identity_providers = {
    sts = {
      client_id = "sts.amazonaws.com"
    }
  }

  vpc_id                   = data.aws_vpc.existing_vpc.id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    ng-g-01 = {
      name           = "ng-g-01"
      instance_types = var.node_group_instance_types
      ami_id         = var.node_group_ami_id
      
      min_size     = 2
      max_size     = 3
      desired_size = 2

      # Force nodes to us-east-2a for placement group
      subnet_ids = [var.subnet_ids[0]]

      # EBS optimized and volume configuration
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 200
            volume_type          = "gp3"
            encrypted            = true
            delete_on_termination = true
          }
        }
      }

      # Placement group for GPU instances
      placement = {
        group_name = aws_placement_group.cluster_placement_group.name
      }

      # Enable EFA (Elastic Fabric Adapter) for GPU instances
      enable_efa_support = true

      # Custom user data for RAID0 local storage and EFA
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        # Configure local NVMe storage as RAID0
        if lsblk | grep -q nvme1n1; then
          yum install -y mdadm
          mdadm --create --verbose /dev/md0 --level=0 --raid-devices=2 /dev/nvme1n1 /dev/nvme2n1
          mkfs.ext4 /dev/md0
          mkdir -p /mnt/local-ssd
          mount /dev/md0 /mnt/local-ssd
          echo '/dev/md0 /mnt/local-ssd ext4 defaults,nofail 0 2' >> /etc/fstab
        fi
        
        # Install EFA drivers
        curl -O https://efa-installer.amazonaws.com/aws-efa-installer-latest.tar.gz
        tar -xf aws-efa-installer-latest.tar.gz
        cd aws-efa-installer
        ./efa_installer.sh -y --skip-kmod --skip-limit-conf
      EOT

      labels = {
        role = "compute"
      }

      tags = merge(local.tags, {
        Name = "${var.cluster_name}-ng-g-01"
      })

      # IAM role additional policies for EBS, FSx, EFS
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        AmazonElasticFileSystemClientFullAccess = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
        AmazonFSxFullAccess = "arn:aws:iam::aws:policy/AmazonFSxFullAccess"
      }
    }
  }

  # EKS Add-ons
  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy            = {}
    vpc-cni               = {}
    aws-ebs-csi-driver    = {}
  }

  tags = local.tags
}

