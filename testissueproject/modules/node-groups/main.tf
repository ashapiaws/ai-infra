# EKS Node Groups Module - Simplified
# Creates managed node groups using AWS EKS resources directly

# Local values for user data generation
locals {
  eks_raid0_userdata = {
    for k, v in var.node_groups : k => v.raid0_config.enabled ? <<-EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -e

# RAID0 Setup for ${k} node group
MOUNT_POINT="${v.raid0_config.mount_point}"
FILESYSTEM="${v.raid0_config.filesystem}"
CLUSTER_NAME="${var.cluster_name}"
RAID_DEVICE="/dev/md0"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/eks-raid0-setup.log
}

detect_nvme_devices() {
    local nvme_devices=()
    for device in /dev/nvme*n1; do
        if [[ -e "$device" ]]; then
            if ! lsblk "$device" | grep -q "/\|/boot"; then
                if nvme id-ctrl "$device" 2>/dev/null | grep -q "Amazon EC2 NVMe Instance Storage" || \
                   lsblk -d -o NAME,MODEL "$device" | grep -q "Instance Storage"; then
                    nvme_devices+=("$device")
                    log "Found local NVMe device: $device"
                fi
            fi
        fi
    done
    echo "$${nvme_devices[@]}"
}

setup_raid0() {
    local devices=("$@")
    local device_count=$${#devices[@]}
    
    if [[ $device_count -eq 0 ]]; then
        log "No local NVMe devices found. Skipping RAID0 setup."
        return 0
    elif [[ $device_count -eq 1 ]]; then
        log "Only one NVMe device found. Setting up single device mount."
        RAID_DEVICE="$${devices[0]}"
    else
        log "Found $device_count NVMe devices. Setting up RAID0."
        if ! command -v mdadm &> /dev/null; then
            yum update -y && yum install -y mdadm
        fi
        mdadm --create --verbose $RAID_DEVICE --level=0 --raid-devices=$device_count "$${devices[@]}"
        mdadm --detail --scan >> /etc/mdadm.conf
    fi
    
    sleep 2
    
    case "$FILESYSTEM" in
        "ext4") mkfs.ext4 -F "$RAID_DEVICE" ;;
        "xfs") mkfs.xfs -f "$RAID_DEVICE" ;;
        *) mkfs.ext4 -F "$RAID_DEVICE" ;;
    esac
    
    mkdir -p "$MOUNT_POINT"
    local uuid=$(blkid -s UUID -o value "$RAID_DEVICE")
    echo "UUID=$uuid $MOUNT_POINT $FILESYSTEM defaults,noatime 0 2" >> /etc/fstab
    mount "$MOUNT_POINT"
    chmod 755 "$MOUNT_POINT"
    
    if mountpoint -q "$MOUNT_POINT"; then
        log "RAID0 setup completed successfully. Mounted at $MOUNT_POINT"
        df -h "$MOUNT_POINT"
    else
        log "ERROR: Failed to mount $MOUNT_POINT"
        return 1
    fi
}

# Main setup function
main_raid0_setup() {
    log "=== RAID0 Setup Started for ${k} node group ==="
    local nvme_devices
    read -ra nvme_devices <<< "$(detect_nvme_devices)"
    
    if [[ $${#nvme_devices[@]} -eq 0 ]]; then
        log "No local NVMe storage detected."
        return 0
    fi
    
    setup_raid0 "$${nvme_devices[@]}"
    
    # Performance optimizations
    for device in /dev/nvme*n1; do
        [[ -e "$device" ]] && echo none > "/sys/block/$(basename "$device")/queue/scheduler" 2>/dev/null || true
    done
    [[ -b "$RAID_DEVICE" ]] && blockdev --setra 4096 "$RAID_DEVICE"
    ln -sf "$MOUNT_POINT" /mnt/fast-storage 2>/dev/null || true
    
    log "=== RAID0 Setup Completed Successfully ==="
}

# Run RAID0 setup in background
main_raid0_setup &

# EKS Bootstrap
/etc/eks/bootstrap.sh $CLUSTER_NAME

--==MYBOUNDARY==--
EOF
    : ""
  }
}

# Data source for cluster info
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# IAM role for EKS node groups
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach required policies to node group role
resource "aws_iam_role_policy_attachment" "node_group_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])

  policy_arn = each.value
  role       = aws_iam_role.node_group.name
}

# Placement groups for node groups (optional)
resource "aws_placement_group" "node_groups" {
  for_each = {
    for k, v in var.node_groups : k => v
    if v.placement_group.enabled
  }

  name     = "${var.cluster_name}-${each.key}-pg"
  strategy = each.value.placement_group.strategy

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-${each.key}-placement-group"
    NodeGroup   = each.key
    ClusterName = var.cluster_name
  })
}

# Launch template for placement group configuration and RAID0 setup
resource "aws_launch_template" "node_groups" {
  for_each = {
    for k, v in var.node_groups : k => v
    if v.placement_group.enabled || v.raid0_config.enabled
  }

  name_prefix = "${var.cluster_name}-${each.key}-"

  # Block device mapping for disk size
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.value.disk_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Placement group configuration (if enabled)
  dynamic "placement" {
    for_each = each.value.placement_group.enabled ? [1] : []
    content {
      group_name = aws_placement_group.node_groups[each.key].name
    }
  }

  # User data for RAID0 setup (if enabled) - MIME multipart format for EKS
  user_data = each.value.raid0_config.enabled ? base64encode(local.eks_raid0_userdata[each.key]) : null

  # Instance metadata service configuration
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # Monitoring
  monitoring {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${each.key}-launch-template"
  })
}

# EKS Managed Node Groups
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name         = var.cluster_name
  node_group_name_prefix = "${var.cluster_name}-${each.key}-"  # Use prefix instead of fixed name
  node_role_arn        = aws_iam_role.node_group.arn
  subnet_ids           = var.subnet_ids

  # Instance configuration
  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types
  ami_type       = each.value.ami_type

  # Disk size only when NOT using launch template
  disk_size = (each.value.placement_group.enabled || each.value.raid0_config.enabled) ? null : each.value.disk_size

  # Launch template for placement groups or RAID0
  dynamic "launch_template" {
    for_each = (each.value.placement_group.enabled || each.value.raid0_config.enabled) ? [1] : []
    content {
      id      = aws_launch_template.node_groups[each.key].id
      version = aws_launch_template.node_groups[each.key].latest_version
    }
  }

  # Scaling configuration
  scaling_config {
    desired_size = each.value.scaling_config.desired_size
    max_size     = each.value.scaling_config.max_size
    min_size     = each.value.scaling_config.min_size
  }

  # Update configuration
  update_config {
    max_unavailable_percentage = 25
  }

  # Remote access configuration (optional)
  dynamic "remote_access" {
    for_each = var.enable_remote_access ? [1] : []
    content {
      ec2_ssh_key               = var.ssh_key_name
      source_security_group_ids = var.remote_access_security_group_ids
    }
  }

  # Labels
  labels = merge(each.value.labels, {
    "node-group" = each.key
    "cluster"    = var.cluster_name
  })

  # Taints
  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-${each.key}-node-group"
    NodeGroup = each.key
  })

  depends_on = [aws_iam_role_policy_attachment.node_group_policies]

  lifecycle {
    create_before_destroy = true
    ignore_changes = [scaling_config[0].desired_size]
  }
}