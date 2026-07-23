# Helm Values Configuration Guide

This guide explains the new YAML-based configuration approach for Helm addons in the EKS Observability Stack.

## Overview

All Helm addon configurations are now managed through YAML values files located in `modules/addons/helm-values/`. This approach provides:

- **Better maintainability**: Configuration is centralized in YAML files instead of scattered across environment files
- **Simplified environment files**: Environment files only need to enable/disable addons
- **Version control friendly**: YAML files are easier to read and diff than Terraform HCL
- **Reusability**: Same configuration applies across all environments by default

## Architecture

### Configuration Files

```
modules/addons/
├── helm-values/
│   ├── nvidia-gpu-operator.yaml      # GPU operator with DCGM configuration
│   ├── cluster-autoscaler.yaml       # Cluster autoscaler configuration
│   ├── prometheus-node-exporter.yaml # Node exporter configuration
│   └── metrics-server.yaml           # Metrics server configuration
├── addon-configs.tf                  # Default addon configurations
└── main.tf                           # Addon deployment logic
```

### Configuration Merging

The system uses a three-tier configuration approach:

1. **Default configurations** (`addon-configs.tf`): Provides base configuration for all addons
2. **YAML values files** (`helm-values/*.yaml`): Contains detailed Helm chart values
3. **Environment overrides** (`environments/*.tfvars`): Only specifies `enabled = true/false`

Configurations are merged with user values taking precedence over defaults.

## Usage

### Enabling/Disabling Addons

In your environment file (e.g., `environments/dev.tfvars`):

```hcl
helm_addons = {
  "nvidia-gpu-operator" = {
    enabled = true  # Enable the addon
  }
  
  "cluster-autoscaler" = {
    enabled = false  # Disable the addon
  }
}
```

### Customizing Addon Configuration

To customize an addon's configuration, edit the corresponding YAML file in `modules/addons/helm-values/`.

#### Example: NVIDIA GPU Operator

File: `modules/addons/helm-values/nvidia-gpu-operator.yaml`

```yaml
# GPU Operator configuration
operator:
  defaultRuntime: containerd

# DCGM Exporter configuration with ServiceMonitor
dcgmExporter:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
```

#### Example: Cluster Autoscaler

File: `modules/addons/helm-values/cluster-autoscaler.yaml`

```yaml
# Autoscaler configuration
autoDiscovery:
  clusterName: CLUSTER_NAME_PLACEHOLDER  # Replaced by Terraform

awsRegion: AWS_REGION_PLACEHOLDER  # Replaced by Terraform

# Resource limits
resources:
  limits:
    cpu: 100m
    memory: 300Mi
```

Note: Placeholders like `CLUSTER_NAME_PLACEHOLDER` are automatically replaced by Terraform using `templatefile()`.

## Available Addons

### NVIDIA GPU Operator

**Purpose**: Manages NVIDIA GPU drivers and runtime on Kubernetes

**Configuration file**: `modules/addons/helm-values/nvidia-gpu-operator.yaml`

**Key features**:
- Automatic GPU driver installation
- DCGM Exporter for GPU metrics
- ServiceMonitor for Prometheus integration
- Containerd runtime configuration

**Enable in**: Environments with GPU node groups

### Cluster Autoscaler

**Purpose**: Automatically adjusts cluster size based on pod resource requirements

**Configuration file**: `modules/addons/helm-values/cluster-autoscaler.yaml`

**Key features**:
- Auto-discovery of node groups
- IRSA (IAM Roles for Service Accounts) support
- Configurable scaling behavior

**Enable in**: Production and staging environments

### Prometheus Node Exporter

**Purpose**: Collects hardware and OS metrics from nodes

**Configuration file**: `modules/addons/helm-values/prometheus-node-exporter.yaml`

**Key features**:
- Runs on all nodes (including GPU nodes)
- ServiceMonitor for Prometheus integration
- Resource limits configured

**Enable in**: All environments with monitoring

### Metrics Server

**Purpose**: Provides resource metrics for Horizontal Pod Autoscaling

**Configuration file**: `modules/addons/helm-values/metrics-server.yaml`

**Key features**:
- Lightweight resource metrics collection
- Required for HPA (Horizontal Pod Autoscaler)
- High availability configuration

**Enable in**: All environments

## Dynamic Configuration

Some addons require environment-specific values (like cluster name or region). These are handled using Terraform's `templatefile()` function:

```hcl
values = [
  templatefile("${path.module}/helm-values/cluster-autoscaler.yaml", {
    cluster_name = var.cluster_name
    aws_region   = data.aws_region.current.name
  })
]
```

Placeholders in YAML files are replaced at deployment time:
- `CLUSTER_NAME_PLACEHOLDER` → actual cluster name
- `AWS_REGION_PLACEHOLDER` → actual AWS region

## Migration from Set Blocks

### Before (Old Approach)

```hcl
helm_addons = {
  "nvidia-gpu-operator" = {
    enabled = true
    chart = "gpu-operator"
    chart_version = "v24.9.0"
    repository = "https://helm.ngc.nvidia.com/nvidia"
    namespace = "gpu-operator"
    
    set = [
      {
        name  = "operator.defaultRuntime"
        value = "containerd"
      },
      {
        name  = "dcgmExporter.enabled"
        value = "true"
      },
      # ... many more set blocks
    ]
  }
}
```

### After (New Approach)

**Environment file**:
```hcl
helm_addons = {
  "nvidia-gpu-operator" = {
    enabled = true
  }
}
```

**YAML values file** (`modules/addons/helm-values/nvidia-gpu-operator.yaml`):
```yaml
operator:
  defaultRuntime: containerd

dcgmExporter:
  enabled: true
```

## Best Practices

1. **Keep environment files minimal**: Only specify `enabled = true/false`
2. **Centralize configuration**: Put all addon settings in YAML files
3. **Use comments**: Document why specific values are set in YAML files
4. **Version control**: Commit YAML files to track configuration changes
5. **Test changes**: Validate YAML syntax before applying
6. **Use placeholders**: For environment-specific values, use placeholders and `templatefile()`

## Troubleshooting

### Addon not deploying

1. Check if addon is enabled in environment file
2. Verify YAML file syntax: `yamllint modules/addons/helm-values/*.yaml`
3. Check Terraform plan output for errors
4. Review Helm release status: `helm list -A`

### Configuration not applied

1. Ensure YAML file is referenced in `addon-configs.tf`
2. Verify `values = [file(...)]` or `values = [templatefile(...)]` is set
3. Check for syntax errors in YAML file
4. Run `terraform plan` to see what will be applied

### Placeholder not replaced

1. Verify placeholder name matches `templatefile()` variable
2. Check that `templatefile()` is used instead of `file()`
3. Ensure variable is passed to `templatefile()` function

## Related Documentation

- [Addons Management](./Addons-Management.md) - General addon management guide
- [GPU Metrics DCGM](./GPU-Metrics-DCGM.md) - DCGM metrics collection guide
- [DCGM Quick Reference](./DCGM-Quick-Reference.md) - DCGM metrics reference
- [Node Exporter Guide](./Node-Exporter-Guide.md) - Node exporter metrics guide
