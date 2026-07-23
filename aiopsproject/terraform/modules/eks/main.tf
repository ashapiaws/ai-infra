# EKS Module - Main Configuration
# Creates EKS cluster with dual node group architecture for CPU and GPU workloads

# Data source for existing VPC to validate integration
data "aws_vpc" "existing" {
  id = var.vpc_id
}

# Data source for existing subnets to validate configuration
data "aws_subnets" "existing" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "subnet-id"
    values = var.subnet_ids
  }
}

# Data source to get individual subnet details for validation
data "aws_subnet" "selected" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}

# EKS Cluster with enhanced VPC integration
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_service_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  # Enable comprehensive logging for security and compliance
  enabled_cluster_log_types = var.cluster_log_types

  # Encryption configuration for security
  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling
  depends_on = [
    aws_cloudwatch_log_group.cluster
  ]

  tags = merge(
    {
      Name        = var.cluster_name
      Environment = var.environment
      VPC         = var.vpc_id
    },
    var.additional_tags
  )
}

# CloudWatch Log Group for EKS cluster logs with enhanced retention
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(
    {
      Name        = "${var.cluster_name}-logs"
      Environment = var.environment
    },
    var.additional_tags
  )
}

# EKS Cluster Security Group with enhanced VPC integration
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS cluster control plane"

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound HTTPS traffic from node groups
  ingress {
    description     = "HTTPS from node groups"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.node_group.id]
  }

  # Allow inbound traffic from existing VPC CIDR for management
  ingress {
    description = "Management access from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.existing.cidr_block]
  }

  # Allow additional security groups if specified
  dynamic "ingress" {
    for_each = var.additional_security_group_ids
    content {
      description     = "Access from additional security group"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  tags = merge(
    {
      Name        = "${var.cluster_name}-cluster-sg"
      Environment = var.environment
      Purpose     = "EKS-Cluster-Control-Plane"
    },
    var.additional_tags
  )
}

# Node Group Security Group with enhanced network security
resource "aws_security_group" "node_group" {
  name_prefix = "${var.cluster_name}-node-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS node groups"

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound traffic from cluster control plane
  ingress {
    description     = "Kubelet API from cluster"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  # Allow nodes to communicate with each other on all ports
  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # Allow nodes to communicate with each other on UDP (for DNS)
  ingress {
    description = "Node to node UDP communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    self        = true
  }

  # Allow HTTPS traffic from cluster
  ingress {
    description     = "HTTPS from cluster"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  # Allow SSH access if SSH key is configured
  dynamic "ingress" {
    for_each = var.ssh_key_name != null ? [1] : []
    content {
      description = "SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.existing.cidr_block]
    }
  }

  # Allow EFA traffic for GPU nodes (high-performance networking)
  ingress {
    description = "EFA traffic for GPU nodes"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  tags = merge(
    {
      Name        = "${var.cluster_name}-node-sg"
      Environment = var.environment
      Purpose     = "EKS-Node-Groups"
    },
    var.additional_tags
  )
}

# CPU Node Group with Karpenter Autoscaling Support
resource "aws_eks_node_group" "cpu_nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-cpu-nodes"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.subnet_ids

  # Instance configuration optimized for general workloads
  instance_types = var.cpu_node_config.instance_types
  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  disk_size      = 50

  # Scaling configuration - autoscaling enabled for cost optimization
  scaling_config {
    desired_size = var.cpu_node_config.desired_size
    max_size     = var.cpu_node_config.max_size
    min_size     = var.cpu_node_config.min_size
  }

  # Update configuration for rolling updates
  update_config {
    max_unavailable_percentage = 25
  }

  # Remote access configuration (optional)
  dynamic "remote_access" {
    for_each = var.ssh_key_name != null ? [1] : []
    content {
      ec2_ssh_key               = var.ssh_key_name
      source_security_group_ids = [aws_security_group.node_group.id]
    }
  }

  # Kubernetes labels for workload scheduling
  labels = {
    "node-type"                     = "cpu"
    "workload"                      = "general"
    "autoscaling"                   = "enabled"
    "karpenter.sh/provisioner-name" = "cpu-provisioner"
    "kubernetes.io/arch"            = "amd64"
    "kubernetes.io/os"              = "linux"
  }

  # No taints for CPU nodes to allow general workloads

  tags = merge(
    {
      Name                                        = "${var.cluster_name}-cpu-nodes"
      Environment                                 = var.environment
      NodeType                                    = "cpu"
      "karpenter.sh/discovery"                    = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    },
    var.additional_tags
  )

  # Ensure proper dependency order
  depends_on = [
    aws_eks_cluster.main,
    aws_security_group.node_group
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# GPU Node Group with Fixed Sizing for Cost Control
resource "aws_eks_node_group" "gpu_nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-gpu-nodes"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.subnet_ids

  # Instance configuration - GPU optimized instances
  instance_types = var.gpu_node_config.instance_types
  ami_type       = "AL2_x86_64_GPU"
  capacity_type  = "ON_DEMAND"
  disk_size      = 100 # Larger disk for GPU workloads and model storage

  # Scaling configuration - fixed sizing for cost control (autoscaling disabled)
  scaling_config {
    desired_size = var.gpu_node_config.desired_size
    max_size     = var.gpu_node_config.max_size
    min_size     = var.gpu_node_config.min_size
  }

  # Update configuration for rolling updates
  update_config {
    max_unavailable_percentage = 25
  }

  # Remote access configuration (optional)
  dynamic "remote_access" {
    for_each = var.ssh_key_name != null ? [1] : []
    content {
      ec2_ssh_key               = var.ssh_key_name
      source_security_group_ids = [aws_security_group.node_group.id]
    }
  }

  # Kubernetes labels for GPU workload scheduling
  labels = {
    "node-type"              = "gpu"
    "workload"               = "ml"
    "autoscaling"            = "disabled"
    "nvidia.com/gpu.present" = "true"
    "kubernetes.io/arch"     = "amd64"
    "kubernetes.io/os"       = "linux"
    "instance-type"          = join(",", var.gpu_node_config.instance_types)
  }

  # Kubernetes taints to ensure only GPU workloads run on these expensive nodes
  taint {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  taint {
    key    = "node-type"
    value  = "gpu"
    effect = "NO_SCHEDULE"
  }

  tags = merge(
    {
      Name                                        = "${var.cluster_name}-gpu-nodes"
      Environment                                 = var.environment
      NodeType                                    = "gpu"
      CostOptimization                            = "fixed-sizing"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    },
    var.additional_tags
  )

  # Ensure proper dependency order
  depends_on = [
    aws_eks_cluster.main,
    aws_security_group.node_group
  ]

  # Prevent Terraform from changing the desired size after initial creation
  # This enforces manual scaling for cost control
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# OIDC Identity Provider for IRSA
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name        = "${var.cluster_name}-oidc"
    Environment = var.environment
  }
}

# EKS Add-ons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  tags = {
    Name        = "${var.cluster_name}-vpc-cni"
    Environment = var.environment
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  depends_on = [
    aws_eks_node_group.cpu_nodes
  ]

  tags = {
    Name        = "${var.cluster_name}-coredns"
    Environment = var.environment
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  tags = {
    Name        = "${var.cluster_name}-kube-proxy"
    Environment = var.environment
  }
}

# AWS Load Balancer Controller Add-on
resource "aws_eks_addon" "aws_load_balancer_controller" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-load-balancer-controller"

  depends_on = [
    aws_eks_node_group.cpu_nodes
  ]

  tags = {
    Name        = "${var.cluster_name}-alb-controller"
    Environment = var.environment
  }
}

# Karpenter Provisioner for CPU Node Autoscaling (deployed via Helm in later tasks)
# This creates the necessary IAM role and instance profile for Karpenter nodes
resource "aws_iam_role" "karpenter_node_instance_role" {
  name = "${var.cluster_name}-karpenter-node-instance-role"

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

  tags = merge(
    {
      Name        = "${var.cluster_name}-karpenter-node-instance-role"
      Environment = var.environment
      Purpose     = "Karpenter-Node-Instance-Role"
    },
    var.additional_tags
  )
}

# Attach required policies to Karpenter node instance role
resource "aws_iam_role_policy_attachment" "karpenter_node_instance_role_policy" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])

  policy_arn = each.value
  role       = aws_iam_role.karpenter_node_instance_role.name
}

# Instance profile for Karpenter nodes
resource "aws_iam_instance_profile" "karpenter_node_instance_profile" {
  name = "${var.cluster_name}-karpenter-node-instance-profile"
  role = aws_iam_role.karpenter_node_instance_role.name

  tags = merge(
    {
      Name        = "${var.cluster_name}-karpenter-node-instance-profile"
      Environment = var.environment
    },
    var.additional_tags
  )
}