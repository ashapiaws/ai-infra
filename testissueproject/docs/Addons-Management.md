# EKS Addons Management

This document describes the extensible addon management system that supports both AWS EKS addons and third-party Helm addons.

## Overview

The addon management system provides a unified way to install and manage:

1. **AWS EKS Addons**: Native AWS-managed addons like EBS CSI Driver, EFS CSI Driver, FSx CSI Driver
2. **Third-party Helm Addons**: Community addons like AWS Load Balancer Controller, NVIDIA GPU Operator, Cluster Autoscaler

## Architecture

The system consists of:

- **Addons Module** (`modules/addons/`): Core addon management logic
- **Pre-configured Addons** (`modules/addons/addon-configs.tf`): Common addon configurations
- **Environment-specific Configuration**: Addon settings per environment (dev/staging/prod)

## Supported Addons

### AWS EKS Addons

| Addon | Purpose | Default Status |
|-------|---------|----------------|
| `aws-ebs-csi-driver` | Persistent volumes with EBS | ✅ Enabled |
| `aws-efs-csi-driver` | Shared file systems with EFS | ❌ Disabled |
| `aws-fsx-csi-driver` | High-performance file systems | ❌ Disabled |
| `aws-load-balancer-controller` | ALB/NLB integration (EKS addon) | ❌ Disabled |
| `metrics-server` | Resource metrics collection | ✅ Enabled |

### Third-party Helm Addons

| Addon | Purpose | Default Status |
|-------|---------|----------------|
| `nvidia-gpu-operator` | GPU support for ML workloads with DCGM metrics | ❌ Disabled |
| `cluster-autoscaler` | Automatic node scaling | ❌ Disabled |

**Note:** When `nvidia-gpu-operator` is enabled, DCGM Exporter is automatically deployed with ServiceMonitor for GPU metrics collection. See [GPU Metrics Guide](GPU-Metrics-DCGM.md) for details.

## Configuration

### Basic Addon Configuration

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
}

# Helm Addons
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
        name  = "serviceAccount.create"
        value = "false"
      }
    ]
  }
}
```

### Advanced Configuration Options

#### AWS EKS Addons

```hcl
aws_addons = {
  "aws-ebs-csi-driver" = {
    enabled                      = true
    addon_version               = "v1.36.0-eksbuild.1"
    create_service_account_role = true
    iam_policy_arns = [
      "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    ]
    custom_iam_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["ec2:CreateSnapshot"]
          Resource = "*"
        }
      ]
    })
    service_account_conditions = {
      "StringEquals" = {
        "example.com/custom-condition" = "value"
      }
    }
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "PRESERVE"
    configuration_values = jsonencode({
      controller = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
    })
    preserve = false
    tags = {
      Component = "storage"
    }
  }
}
```

#### Helm Addons

```hcl
helm_addons = {
  "nvidia-gpu-operator" = {
    enabled                     = true
    chart                      = "gpu-operator"
    chart_version              = "v24.9.0"
    repository                 = "https://helm.ngc.nvidia.com/nvidia"
    namespace                  = "gpu-operator"
    create_namespace           = true
    
    # Service Account with IRSA
    create_service_account      = true
    service_account_name        = "gpu-operator"
    create_service_account_role = true
    iam_policy_arns = [
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
    ]
    
    # Namespace configuration
    namespace_labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
    namespace_annotations = {
      "scheduler.alpha.kubernetes.io/node-selector" = "accelerator=nvidia"
    }
    
    # Helm values
    values = [
      file("${path.module}/gpu-operator-values.yaml")
    ]
    
    set = [
      {
        name  = "operator.defaultRuntime"
        value = "containerd"
      }
    ]
    
    set_sensitive = [
      {
        name  = "registry.password"
        value = var.nvidia_registry_password
      }
    ]
    
    # Advanced Helm options
    wait                       = true
    timeout                    = 600
    force_update              = false
    recreate_pods             = false
    max_history               = 5
    atomic                    = true
    cleanup_on_fail           = true
    
    tags = {
      Component = "gpu"
      Workload  = "ml"
    }
  }
}
```

## Environment-Specific Configurations

### Development Environment

- **EBS CSI Driver**: Enabled (required for storage)
- **Metrics Server**: Enabled (required for resource metrics)
- **Other addons**: Disabled for cost optimization
- **Focus**: Minimal setup for development

```hcl
aws_addons = {
  "aws-ebs-csi-driver" = {
    enabled = true
    addon_version = "v1.36.0-eksbuild.1"
    create_service_account_role = true
    iam_policy_arns = [
      "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    ]
  }

  "metrics-server" = {
    enabled = true
    addon_version = "v0.7.2-eksbuild.1"
  }
}

helm_addons = {
  "nvidia-gpu-operator" = { enabled = false }
  "cluster-autoscaler" = { enabled = false }
}
```

### Staging Environment

- **EBS CSI Driver**: Enabled
- **EFS CSI Driver**: Enabled for testing shared storage
- **Metrics Server**: Enabled for resource metrics
- **Cluster Autoscaler**: Enabled for scaling tests

### Production Environment

- **All CSI Drivers**: Enabled for comprehensive storage options
- **Metrics Server**: Enabled for resource metrics
- **NVIDIA GPU Operator**: Enabled for ML workloads
- **Cluster Autoscaler**: Enabled for production scaling

## Adding Custom Addons

### Adding a New AWS EKS Addon

1. **Update the validation list** in `modules/addons/variables.tf`:

```hcl
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
      "your-new-addon",  # Add here
      # ... other addons
    ], addon_name)
  ])
}
```

2. **Add configuration** in environment files:

```hcl
aws_addons = {
  "your-new-addon" = {
    enabled                     = true
    addon_version              = "v1.0.0-eksbuild.1"
    create_service_account_role = true
    iam_policy_arns = [
      "arn:aws:iam::aws:policy/YourAddonPolicy"
    ]
  }
}
```

### Adding a New Helm Addon

1. **Add configuration** in environment files:

```hcl
helm_addons = {
  "your-helm-addon" = {
    enabled                     = true
    chart                      = "your-chart"
    chart_version              = "1.0.0"
    repository                 = "https://your-repo.github.io/helm-charts"
    namespace                  = "your-namespace"
    create_namespace           = true
    
    # Optional: Service account with IRSA
    create_service_account      = true
    service_account_name        = "your-service-account"
    create_service_account_role = true
    iam_policy_arns = [
      "arn:aws:iam::aws:policy/YourPolicy"
    ]
    
    set = [
      {
        name  = "config.key"
        value = "value"
      }
    ]
  }
}
```

2. **Optional: Add to pre-configured addons** in `modules/addons/addon-configs.tf`:

```hcl
local {
  common_helm_addons = {
    "your-helm-addon" = {
      enabled                = false  # Default disabled
      chart                 = "your-chart"
      chart_version         = "1.0.0"
      repository            = "https://your-repo.github.io/helm-charts"
      namespace             = "your-namespace"
      create_namespace      = true
      
      set = [
        {
          name  = "clusterName"
          value = var.cluster_name
        }
      ]
    }
  }
}
```

## IAM Roles and Service Accounts

The addon system automatically creates:

1. **IAM Roles**: For addons that need AWS API access
2. **Service Accounts**: Kubernetes service accounts with IRSA annotations
3. **Policy Attachments**: Both AWS managed and custom policies

### IRSA (IAM Roles for Service Accounts) Flow

1. **OIDC Provider**: Created by EKS cluster module
2. **IAM Role**: Created with trust policy for specific service account
3. **Service Account**: Created with role ARN annotation
4. **Pod**: Uses service account to assume IAM role

## Monitoring and Troubleshooting

### Check Addon Status

```bash
# AWS EKS Addons
kubectl get addon -A
aws eks describe-addon --cluster-name <cluster-name> --addon-name <addon-name>

# Helm Addons
helm list -A
kubectl get pods -n <namespace>
```

### Common Issues

1. **IAM Permission Errors**
   - Check service account role ARN annotation
   - Verify IAM policy attachments
   - Ensure OIDC provider is configured

2. **Helm Installation Failures**
   - Check Helm repository accessibility
   - Verify chart version compatibility
   - Review namespace permissions

3. **Service Account Issues**
   - Ensure service account exists
   - Check IRSA annotations
   - Verify trust policy conditions

### Debugging Commands

```bash
# Check service account
kubectl get sa <service-account-name> -n <namespace> -o yaml

# Check IAM role
aws iam get-role --role-name <role-name>
aws iam list-attached-role-policies --role-name <role-name>

# Check addon logs
kubectl logs -n <namespace> -l app=<addon-name>

# Check Helm release
helm get values <release-name> -n <namespace>
helm get manifest <release-name> -n <namespace>
```

## Best Practices

1. **Environment Separation**: Use different addon configurations per environment
2. **Version Pinning**: Always specify addon and chart versions
3. **Resource Limits**: Set appropriate resource requests and limits
4. **Security**: Use least-privilege IAM policies
5. **Monitoring**: Monitor addon health and resource usage
6. **Testing**: Test addon functionality in staging before production
7. **Documentation**: Document custom addon configurations

## Migration from Hardcoded Addons

If you have existing hardcoded addons (like the previous EBS CSI driver), follow these steps:

1. **Remove hardcoded resources** from existing modules
2. **Add addon configuration** to environment files
3. **Plan and apply** changes carefully
4. **Verify functionality** after migration

The system is designed to be backward compatible and handles conflicts gracefully using the `resolve_conflicts_on_update` setting.

## Security Considerations

1. **IAM Policies**: Use least-privilege access
2. **Service Account Tokens**: Enable `automount_service_account_token` only when needed
3. **Network Policies**: Implement network segmentation
4. **Pod Security**: Use appropriate pod security standards
5. **Secrets Management**: Use AWS Secrets Manager or similar for sensitive values
6. **Image Security**: Use trusted container registries and scan images

## Cost Optimization

1. **Selective Enablement**: Only enable addons needed for each environment
2. **Resource Sizing**: Right-size addon resource requests and limits
3. **Spot Instances**: Use spot instances for non-critical addon workloads
4. **Monitoring**: Monitor addon resource usage and costs
5. **Cleanup**: Remove unused addons and associated resources