# EKS Terraform Migration

This Terraform configuration migrates the eksctl-managed EKS cluster to Terraform management.

## Migration from eksctl

### Current eksctl Configuration Features Migrated:
- ✅ EKS cluster with OIDC provider
- ✅ GPU instances (g6e.12xlarge) with EFA support
- ✅ Custom AMI (Amazon Linux 2023)
- ✅ Placement groups for GPU instances
- ✅ Local NVMe storage configured as RAID0
- ✅ IAM policies for EBS, FSx, EFS
- ✅ Private networking
- ✅ Custom node labels and tags

### Prerequisites

1. **Backup existing cluster configuration**:
   ```bash
   kubectl get all --all-namespaces -o yaml > cluster-backup.yaml
   ```

2. **Install required tools**:
   - Terraform >= 1.5.7
   - AWS CLI configured
   - kubectl

### Deployment Steps

1. **Copy and customize variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Plan the deployment**:
   ```bash
   terraform plan
   ```

4. **Apply the configuration**:
   ```bash
   terraform apply
   ```

5. **Update kubeconfig**:
   ```bash
   aws eks --region us-east-2 update-kubeconfig --name dev-ops-cluster-01
   ```

### Important Notes

#### EFA (Elastic Fabric Adapter) Support
- Automatically installed via user data script
- Required for high-performance GPU workloads
- Configured for g6e.12xlarge instances

#### Local Storage Configuration
- NVMe drives automatically configured as RAID0
- Mounted at `/mnt/local-ssd`
- Provides high-performance local storage for GPU workloads

#### Placement Groups
- Creates cluster placement group for low-latency networking
- All nodes in the same availability zone (us-east-2a)
- Optimized for GPU compute workloads

#### Migration Considerations
- **Downtime**: This creates a new cluster, plan for application migration
- **Data**: Backup persistent volumes before migration
- **Networking**: Ensure security groups and NACLs allow EKS traffic
- **IAM**: Verify service roles have necessary permissions

### Customization

#### Adding More Node Groups
```hcl
eks_managed_node_groups = {
  # Existing GPU node group
  ng-g-01 = { ... }
  
  # Add CPU-only node group
  ng-cpu-01 = {
    name           = "ng-cpu-01"
    instance_types = ["m5.large"]
    min_size       = 1
    max_size       = 5
    desired_size   = 2
    labels = {
      role = "general"
    }
  }
}
```

#### Updating AMI
To get the latest EKS-optimized AMI:
```bash
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.32/amazon-linux-2023/x86_64/standard/recommended/image_id \
  --region us-east-2 \
  --query "Parameter.Value" \
  --output text
```

### Troubleshooting

#### Common Issues
1. **Placement Group Capacity**: g6e.12xlarge instances may have limited availability
2. **EFA Driver Installation**: Check user data logs in `/var/log/cloud-init-output.log`
3. **Local Storage**: Verify NVMe devices are available on instance type

#### Validation Commands
```bash
# Check cluster status
kubectl get nodes -o wide

# Verify EFA installation
kubectl describe node | grep efa

# Check local storage
kubectl exec -it <pod-name> -- df -h /mnt/local-ssd
```

### Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```

**Warning**: This will delete the entire EKS cluster and all associated resources.