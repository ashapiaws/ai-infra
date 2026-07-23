# EBS CSI Driver Fix for Prometheus PVC Issues

## Problem Description

Prometheus persistent volume claims (PVCs) were stuck in pending state despite having GP3 storage classes configured. This issue occurs because:

1. **Missing EBS CSI Driver**: EKS clusters don't automatically include the EBS CSI driver addon
2. **Storage Class Dependency**: GP3 storage classes require `ebs.csi.aws.com` provisioner
3. **IAM Permissions**: The EBS CSI driver needs proper IAM permissions to create and manage EBS volumes

## Root Cause

The storage classes were configured to use `ebs.csi.aws.com` as the provisioner:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com  # This requires EBS CSI driver
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
```

However, the EKS cluster didn't have the EBS CSI driver addon installed, causing PVCs to remain in pending state.

## Solution Implemented

### 1. Added EBS CSI Driver Addon

Added the AWS EBS CSI driver addon to the EKS cluster module (`modules/eks-cluster/main.tf`):

```hcl
# EBS CSI Driver IAM Role
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# EBS CSI Driver Addon
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_driver_version
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}
```

### 2. Added IAM Permissions

The EBS CSI driver requires specific IAM permissions to manage EBS volumes:

```hcl
# Attach EBS CSI Driver policy
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}
```

### 3. Added Configuration Variables

Added configurable EBS CSI driver version:

- **Variable**: `ebs_csi_driver_version` (default: `v1.36.0-eksbuild.1`)
- **Environment Files**: Added to all environment configurations
- **Module Integration**: Passed through from root module to EKS cluster module

## Deployment Steps

### 1. Apply the Fix

```bash
# Switch to development environment
make switch-env ENV=dev

# Plan the changes
terraform plan -var-file=environments/dev.tfvars

# Apply the changes
terraform apply -var-file=environments/dev.tfvars
```

### 2. Verify EBS CSI Driver Installation

```bash
# Check if the addon is installed
kubectl get addon -A

# Verify EBS CSI driver pods are running
kubectl get pods -n kube-system | grep ebs-csi

# Check storage classes
kubectl get storageclass
```

### 3. Verify Prometheus PVCs

```bash
# Check PVC status
kubectl get pvc -n monitoring

# Check PVC events for troubleshooting
kubectl describe pvc -n monitoring

# Verify volumes are bound
kubectl get pv
```

## Expected Results

After applying the fix:

1. **EBS CSI Driver**: Addon will be installed and running
2. **Storage Classes**: GP3 storage classes will be functional
3. **Prometheus PVCs**: Will transition from Pending to Bound state
4. **Prometheus Pods**: Will start successfully with persistent storage

## Troubleshooting

### If PVCs Still Pending

1. **Check EBS CSI Driver Status**:
   ```bash
   kubectl get pods -n kube-system -l app=ebs-csi-controller
   kubectl logs -n kube-system -l app=ebs-csi-controller
   ```

2. **Verify IAM Permissions**:
   ```bash
   # Check if the service account has the correct role annotation
   kubectl get sa ebs-csi-controller-sa -n kube-system -o yaml
   ```

3. **Check Storage Class Configuration**:
   ```bash
   kubectl describe storageclass gp3
   ```

4. **Review PVC Events**:
   ```bash
   kubectl describe pvc prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0 -n monitoring
   ```

### Common Issues

1. **Wrong EBS CSI Driver Version**: Update `ebs_csi_driver_version` in environment files
2. **IAM Role Issues**: Ensure OIDC provider is correctly configured
3. **Node Group Permissions**: Verify node groups have necessary EBS permissions
4. **Availability Zone Mismatch**: Ensure PVCs and nodes are in compatible AZs

## Version Compatibility

| EKS Version | EBS CSI Driver Version | Status |
|-------------|------------------------|---------|
| 1.28        | v1.36.0-eksbuild.1    | ✅ Tested |
| 1.29        | v1.36.0-eksbuild.1    | ✅ Compatible |
| 1.30        | v1.36.0-eksbuild.1    | ✅ Compatible |

## Security Considerations

1. **IAM Least Privilege**: EBS CSI driver role only has necessary EBS permissions
2. **IRSA Integration**: Uses IAM Roles for Service Accounts for secure authentication
3. **Encryption**: All storage classes enforce encryption by default
4. **Network Security**: EBS volumes are created in the same VPC as the cluster

## Cost Impact

- **EBS CSI Driver**: No additional cost (AWS managed addon)
- **EBS Volumes**: Standard EBS pricing applies for Prometheus storage
- **GP3 Performance**: Configurable IOPS and throughput for cost optimization

## Monitoring

Monitor EBS CSI driver health:

```bash
# Check driver metrics
kubectl get --raw /metrics | grep ebs_csi

# Monitor volume operations
kubectl get events --field-selector reason=VolumeBinding -n monitoring
```