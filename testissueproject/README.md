# EKS Observability Stack

A comprehensive Terraform module for deploying Amazon EKS clusters with integrated observability using Prometheus and Grafana. This solution provides a production-ready Kubernetes platform with monitoring, metrics collection, and visualization capabilities.

## Features

- **EKS Cluster**: Production-ready EKS cluster with security best practices
- **Managed Node Groups**: Two node groups with placement group optimization and auto-scaling
- **RAID0 NVMe Storage**: Automatic RAID0 setup for instances with local NVMe storage (high-performance workloads)
- **Extensible Addon System**: Unified management for AWS EKS addons and third-party Helm addons
- **AWS EKS Addons**: EBS CSI Driver, EFS CSI Driver, FSx CSI Driver support
- **Third-party Addons**: AWS Load Balancer Controller, NVIDIA GPU Operator, Cluster Autoscaler
- **Observability Stack**: Prometheus for metrics collection and Grafana for visualization
- **Security**: IAM roles with least-privilege access, security groups, and encryption
- **Monitoring**: Pre-configured dashboards and alerting rules
- **Multi-Environment**: Support for dev/staging/prod with environment-specific configurations
- **Customizable**: Extensive variable configuration for different environments

## Architecture

The stack deploys:

1. **EKS Cluster** with control plane logging and OIDC provider
2. **Two Managed Node Groups** with placement groups for optimal performance
3. **Extensible Addon System** supporting both AWS EKS addons and third-party Helm addons
4. **AWS EKS Addons** including:
   - EBS CSI Driver for persistent volumes
   - EFS CSI Driver for shared file systems (optional)
   - FSx CSI Driver for high-performance file systems (optional)
   - Metrics Server for resource metrics collection
5. **Third-party Addons** including:
   - NVIDIA GPU Operator for ML workloads
   - Cluster Autoscaler for automatic scaling
6. **Prometheus Stack** (kube-prometheus-stack) including:
   - Prometheus server with persistent storage
   - Grafana with pre-configured dashboards
   - AlertManager for alert routing
   - Node Exporter for system metrics
   - kube-state-metrics for Kubernetes metrics

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl (for cluster access)
- Helm >= 3.0 (managed by Terraform)
- Existing VPC (subnets will be auto-discovered)

## Quick Start

### Option 1: Environment-Specific Deployment (Recommended)

1. **Clone and Setup**
   ```bash
   git clone <repository-url>
   cd eks-observability-stack
   ```

2. **Choose Environment**
   ```bash
   # Switch to development environment
   ./scripts/switch-env.sh dev
   
   # Or use direct file reference
   cp environments/dev.tfvars terraform.tfvars
   ```

3. **Customize Configuration**
   Edit the environment file with your VPC ID:
   ```bash
   # Edit the active environment
   vim terraform.tfvars
   
   # Update VPC ID
   vpc_id = "vpc-12345678"  # Your actual VPC ID
   ```

4. **Deploy**
   ```bash
   # Using Makefile (recommended)
   make dev        # Deploy development
   make staging    # Deploy staging  
   make prod       # Deploy production
   
   # Or using Terraform directly
   terraform init
   terraform plan
   terraform apply
   ```

### Option 2: Custom Configuration

1. **Clone and Configure**
   ```bash
   git clone <repository-url>
   cd eks-observability-stack
   cp examples/basic/terraform.tfvars.example terraform.tfvars
   ```

2. **Edit Configuration**
   Update `terraform.tfvars` with your VPC ID. Subnets will be automatically discovered:
   ```hcl
   vpc_id = "vpc-12345678"
   subnet_type = "private"  # or "public"
   cluster_name = "my-eks-cluster"
   ```

3. **Deploy**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Configure kubectl**
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster
   ```

5. **Access Grafana**
   ```bash
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
   # Access at http://localhost:3000 (admin/SecurePassword123!)
   ```

## Configuration

### Required Variables

| Variable | Description | Type |
|----------|-------------|------|
| `cluster_name` | Name of the EKS cluster | `string` |
| `vpc_id` | ID of existing VPC | `string` |

### Key Configuration Options

#### Subnet Discovery
The module automatically discovers subnets in your VPC using multiple validation methods:

```hcl
# Automatic subnet discovery (recommended)
vpc_id = "vpc-12345678"
subnet_type = "private"  # or "public"

# Custom naming patterns (optional)
subnet_name_patterns = {
  private = "(?i)(priv|private|internal)"
  public  = "(?i)(pub|public|external|dmz)"
}

# Manual subnet specification (optional)
subnet_ids = ["subnet-12345678", "subnet-87654321"]
```

**Subnet Classification Logic:**
1. **Name-based detection** (highest priority): Checks subnet names for patterns like "priv", "private", "pub", "public"
2. **Flag-based detection** (fallback): Uses `map_public_ip_on_launch` attribute
3. **Manual override**: Explicit `subnet_ids` bypasses auto-discovery

**Subnet Types:**
- `private`: Subnets without public IP assignment (recommended for EKS)
- `public`: Subnets with public IP assignment

**Debug Subnet Discovery:**
```bash
terraform output subnet_discovery_info
```

#### Node Groups
Configure two node groups with different characteristics:
```hcl
node_groups = {
  primary = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    scaling_config = {
      min_size     = 1
      max_size     = 5
      desired_size = 2
    }
    placement_group = {
      strategy = "cluster"
      enabled  = true
    }
    raid0_config = {
      enabled     = false
      mount_point = "/mnt/raid0"
      filesystem  = "ext4"
    }
  }
  secondary = {
    instance_types = ["g6e.12xlarge"]  # Instance with local NVMe
    capacity_type  = "SPOT"
    raid0_config = {
      enabled     = true
      mount_point = "/mnt/nvme-raid0"
      filesystem  = "xfs"
    }
    # ... additional configuration
  }
}
```

#### RAID0 NVMe Storage
For high-performance workloads, enable automatic RAID0 setup on instances with local NVMe storage:

```hcl
raid0_config = {
  enabled     = true
  mount_point = "/mnt/nvme-raid0"
  filesystem  = "xfs"  # or "ext4"
}
```

**Supported Instance Types:**
- GPU: g6e.*, g5.*, p4d.*, p3.*
- Compute: c5d.*, c5ad.*, c6id.*
- Memory: r5d.*, r5ad.*, r6id.*
- Storage: i3.*, i3en.*, i4i.*

**Features:**
- Automatic NVMe device detection
- RAID0 array creation for multiple devices
- Performance optimizations (I/O scheduler, read-ahead)
- Persistent mounting with `/etc/fstab`
- Detailed logging and status information

See [RAID0 Setup Guide](docs/RAID0-Setup.md) for detailed configuration and usage.

#### Observability Stack
Customize monitoring components:
```hcl
observability_config = {
  # Storage class configuration
  storage_classes = {
    create_gp3_classes = true
    default_class      = "gp3"  # or "gp3-high-iops" for production
  }
  
  prometheus = {
    retention_days = 30
    storage_class  = "gp3"      # Use GP3 storage class
    storage_size   = "100Gi"
    # ... resource limits
  }
  grafana = {
    admin_password = "SecurePassword123!"
    storage_class  = "gp3"      # Use GP3 storage class
    ingress = {
      enabled = true
      host    = "grafana.example.com"
    }
  }
}
```

#### EKS Addons Configuration
Configure AWS EKS addons and third-party Helm addons:
```hcl
# AWS EKS Addons
aws_addons = {
  "aws-ebs-csi-driver" = {
    enabled                     = true
    addon_version              = "v1.36.0-eksbuild.1"
    create_service_account_role = true
    iam_policy_arns = [
      "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    ]
  }
  
  "aws-efs-csi-driver" = {
    enabled                     = true
    addon_version              = "v2.1.1-eksbuild.1"
    create_service_account_role = true
    iam_policy_arns = [
      "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
    ]
  }

  "metrics-server" = {
    enabled       = true
    addon_version = "v0.7.2-eksbuild.1"
  }
}

# Third-party Helm Addons
helm_addons = {
  "aws-load-balancer-controller" = {
    enabled                     = true
    chart                      = "aws-load-balancer-controller"
    chart_version              = "1.8.1"
    repository                 = "https://aws.github.io/eks-charts"
    namespace                  = "kube-system"
    create_service_account     = true
    service_account_name       = "aws-load-balancer-controller"
    create_service_account_role = true
    
    set = [
      {
        name  = "clusterName"
        value = "my-cluster"
      },
      {
        name  = "vpcId"
        value = "vpc-12345678"
      }
    ]
  }
  
  "nvidia-gpu-operator" = {
    enabled                     = true
    chart                      = "gpu-operator"
    chart_version              = "v24.9.0"
    repository                 = "https://helm.ngc.nvidia.com/nvidia"
    namespace                  = "gpu-operator"
    create_namespace           = true
    timeout                    = 600
  }
}
```

**Supported AWS EKS Addons:**
- `aws-ebs-csi-driver` - Persistent volumes with EBS (enabled by default)
- `aws-efs-csi-driver` - Shared file systems with EFS
- `aws-fsx-csi-driver` - High-performance file systems with FSx
- `metrics-server` - Resource metrics collection (enabled by default)

**Supported Third-party Addons:**
- `nvidia-gpu-operator` - GPU support for ML workloads with DCGM Exporter for GPU metrics
- `cluster-autoscaler` - Automatic node scaling

See [Addons Management Guide](docs/Addons-Management.md) for detailed configuration and custom addon creation.

For information about the YAML-based configuration approach, see [Helm Values Configuration Guide](docs/Helm-Values-Configuration.md).

#### GP3 Storage Classes
The stack creates optimized GP3 storage classes for different workload types:

- **gp3** - General purpose (3,000 IOPS, 125 MiB/s)
- **gp3-high-iops** - High IOPS workloads (10,000 IOPS, 500 MiB/s)
- **gp3-high-throughput** - High throughput workloads (6,000 IOPS, 1,000 MiB/s)
- **gp3-xfs** - XFS filesystem for large files (4,000 IOPS, 250 MiB/s)

```yaml
# Example PVC using high-performance storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: gp3-high-iops
  resources:
    requests:
      storage: 100Gi
```

See [Storage Classes Guide](docs/Storage-Classes.md) for detailed configuration and usage.

## Accessing Services

### Grafana Dashboard
```bash
# Port forward to access locally
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Or configure ingress in terraform.tfvars
```

### Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

### AlertManager
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

## Pre-configured Dashboards

The stack includes several pre-configured Grafana dashboards:

- **Kubernetes Cluster Monitoring** (ID: 7249) - Overall cluster health
- **Kubernetes Pod Monitoring** (ID: 6417) - Pod-level metrics
- **Node Exporter** (ID: 1860) - System-level metrics

## Alerting

Common alert rules are pre-configured:

- Pod crash looping detection
- Node not ready alerts
- Pod not ready alerts
- Resource utilization thresholds

## Security Features

- **IAM Roles**: Least-privilege access for all components
- **Security Groups**: Minimal required network access
- **Encryption**: EKS secrets encryption with KMS
- **RBAC**: Kubernetes role-based access control
- **Pod Security**: Pod security standards enforcement

## Multi-Environment Support

The stack includes pre-configured environments for different deployment scenarios:

| Environment | Use Case | Key Features |
|-------------|----------|--------------|
| **Development** | Cost-optimized development | Spot instances, minimal logging, SSH access |
| **Staging** | Production-like testing | Balanced resources, full monitoring, security enabled |
| **Production** | High-availability production | On-demand instances, comprehensive logging, security hardened |

### Environment Management

**Switch Environments:**
```bash
# Interactive environment switcher
./scripts/switch-env.sh dev
./scripts/switch-env.sh staging
./scripts/switch-env.sh prod
```

**Compare Environments:**
```bash
# See differences between environments
./scripts/compare-envs.sh
```

**Deploy Specific Environment:**
```bash
# Using Makefile
make dev        # Deploy development
make staging    # Deploy staging
make prod       # Deploy production

# Using Terraform directly
terraform apply -var-file="environments/dev.tfvars"
```

### Environment Characteristics

#### Development Environment
- **Cost Optimized**: t3.small spot instances, 7-day retention
- **Developer Friendly**: SSH access, permissive networking
- **Minimal Resources**: Basic monitoring, AlertManager disabled
- **Auto-Shutdown**: Tagged for cost management

#### Staging Environment  
- **Production Parity**: Similar configuration to production
- **Testing Focus**: Full observability stack, security enabled
- **Balanced Resources**: t3.medium instances, 15-day retention
- **Ingress Enabled**: Internal load balancer for testing

#### Production Environment
- **High Availability**: m5.large+ instances, multi-AZ deployment
- **Security Hardened**: Private endpoints, no SSH, full encryption
- **Comprehensive Monitoring**: 90-day retention, high-frequency scraping
- **Performance Optimized**: Placement groups, larger resources

### Adding Custom Dashboards

Add custom Grafana dashboards in the observability module configuration:

```hcl
dashboards = {
  default = {
    "my-custom-dashboard" = {
      gnetId     = 12345
      revision   = 1
      datasource = "Prometheus"
    }
  }
}
```

### Custom Alert Rules

Add custom PrometheusRule resources in the observability module.

## Troubleshooting

### Common Issues

1. **Prometheus PVCs stuck in Pending state**
   ```
   Error: PersistentVolumeClaim is stuck in Pending state
   ```
   - **Cause**: Missing EBS CSI driver addon in EKS cluster
   - **Solution**: The stack now automatically installs the EBS CSI driver addon
   - **Details**: See [EBS CSI Driver Fix Guide](docs/EBS-CSI-Driver-Fix.md)

2. **Insufficient subnets found**
   ```
   Error: Found 1 private subnets, but need at least 2
   ```
   - Ensure your VPC has at least 2 subnets of the specified type
   - Check subnet configuration: private subnets should not have `map_public_ip_on_launch = true`
   - Use `terraform output subnet_discovery_info` to see discovered subnets

3. **Node groups not joining cluster**
   - Verify subnet routing and security groups
   - Check IAM permissions for node group role

4. **Prometheus not scraping metrics**
   - Verify service discovery configuration
   - Check network policies and security groups

5. **Grafana dashboards not loading**
   - Verify Prometheus data source configuration
   - Check persistent volume provisioning

### Debugging Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -n monitoring

# Check subnet discovery
terraform output subnet_discovery_info

# Check Helm releases
helm list -n monitoring

# View logs
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana
kubectl logs -n monitoring statefulset/prometheus-kube-prometheus-stack-prometheus
```

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

**Note**: This will delete all resources including persistent volumes with monitoring data.

## Module Structure

```
├── main.tf                 # Root module configuration
├── variables.tf           # Variable definitions
├── outputs.tf            # Output definitions
├── terraform.tf          # Backend configuration
├── modules/
│   ├── eks-cluster/      # EKS cluster module
│   ├── node-groups/      # Node groups module
│   ├── addons/           # Extensible addon management
│   └── observability/    # Monitoring stack module
├── environments/         # Environment-specific configurations
│   ├── dev.tfvars       # Development environment
│   ├── staging.tfvars   # Staging environment
│   └── prod.tfvars      # Production environment
├── applications/         # Application deployments
│   └── README.md        # Application deployment guide
├── day-two-operations/   # Operational tools and utilities
│   ├── node-health-checker/  # Node health monitoring
│   └── README.md        # Operations guide
├── docs/                # Documentation
│   ├── Addons-Management.md       # Addon system guide
│   ├── Helm-Values-Configuration.md # YAML-based addon configuration
│   ├── GPU-Metrics-DCGM.md        # GPU metrics collection guide
│   ├── DCGM-Quick-Reference.md    # DCGM metrics reference
│   ├── Node-Exporter-Guide.md     # Node exporter metrics guide
│   ├── RAID0-Setup.md             # RAID0 configuration
│   ├── Storage-Classes.md         # Storage class guide
│   └── EBS-CSI-Driver-Fix.md      # Troubleshooting guide
└── examples/
    └── basic/            # Example configurations
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review AWS EKS documentation