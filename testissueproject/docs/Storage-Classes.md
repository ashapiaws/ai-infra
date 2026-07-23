# GP3 Storage Classes for EKS

This EKS observability stack includes optimized GP3 storage classes for different workload types, providing high-performance, cost-effective storage for Kubernetes applications.

## Overview

The stack automatically creates four GP3 storage classes:

1. **gp3** - General purpose, balanced performance
2. **gp3-high-iops** - Optimized for high IOPS workloads (databases)
3. **gp3-high-throughput** - Optimized for high throughput workloads (data processing)
4. **gp3-xfs** - XFS filesystem for large files and high performance

## Storage Class Details

### gp3 (Default)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
  iops: "3000"      # Base IOPS
  throughput: "125" # Base throughput (MiB/s)
```

**Use Cases:**
- General application storage
- Web applications
- Development workloads
- Small to medium databases

**Performance:**
- IOPS: 3,000 (baseline)
- Throughput: 125 MiB/s
- Cost-effective for most workloads

### gp3-high-iops
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-high-iops
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
  iops: "10000"     # High IOPS
  throughput: "500" # High throughput
```

**Use Cases:**
- Transactional databases (PostgreSQL, MySQL)
- OLTP workloads
- High-frequency trading applications
- Real-time analytics

**Performance:**
- IOPS: 10,000 (high)
- Throughput: 500 MiB/s
- Optimized for random I/O patterns

### gp3-high-throughput
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-high-throughput
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
  iops: "6000"      # Balanced IOPS
  throughput: "1000" # Maximum throughput
```

**Use Cases:**
- Data warehousing
- ETL processes
- Log processing
- Large file transfers
- Streaming applications

**Performance:**
- IOPS: 6,000 (balanced)
- Throughput: 1,000 MiB/s (maximum)
- Optimized for sequential I/O patterns

### gp3-xfs
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-xfs
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: xfs
  encrypted: "true"
  iops: "4000"
  throughput: "250"
```

**Use Cases:**
- Large file storage
- Media processing
- Scientific computing
- Backup storage
- Archive systems

**Performance:**
- IOPS: 4,000
- Throughput: 250 MiB/s
- XFS filesystem for large files (>16TB support)

## Configuration

### Environment-Specific Settings

#### Development
```hcl
storage_classes = {
  create_gp3_classes = true
  default_class      = "gp3"  # Cost-effective default
}
```

#### Staging
```hcl
storage_classes = {
  create_gp3_classes = true
  default_class      = "gp3"  # Production-like but cost-conscious
}
```

#### Production
```hcl
storage_classes = {
  create_gp3_classes = true
  default_class      = "gp3-high-iops"  # Performance-focused default
}
```

### Disabling Storage Classes
```hcl
storage_classes = {
  create_gp3_classes = false
  default_class      = ""
}
```

## Usage Examples

### Database Workload
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3-high-iops
  resources:
    requests:
      storage: 100Gi
```

### Data Processing Pipeline
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: etl-workspace
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3-high-throughput
  resources:
    requests:
      storage: 500Gi
```

### Media Storage
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: media-files
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3-xfs
  resources:
    requests:
      storage: 1Ti
```

### General Application Storage
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3  # Uses default GP3 class
  resources:
    requests:
      storage: 50Gi
```

## Performance Tuning

### Custom IOPS and Throughput
You can override the default performance settings per PVC:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: custom-performance
  annotations:
    # Override default IOPS and throughput
    volume.beta.kubernetes.io/storage-class: gp3
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 200Gi
  # Custom parameters (if supported by CSI driver)
  volumeMode: Filesystem
```

### Performance Monitoring
Monitor storage performance using:

```bash
# Check PVC status
kubectl get pvc

# Describe PVC for events
kubectl describe pvc <pvc-name>

# Monitor I/O metrics (requires monitoring stack)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Access Grafana and check "Kubernetes / Persistent Volumes" dashboard
```

## Cost Optimization

### GP3 vs GP2 Cost Comparison
- **GP3 Base Cost**: Lower per GB than GP2
- **Performance**: Pay only for IOPS/throughput you need
- **Flexibility**: Adjust performance independently of size

### Best Practices
1. **Right-size volumes**: Start with smaller sizes and expand as needed
2. **Choose appropriate class**: Match storage class to workload requirements
3. **Monitor usage**: Use CloudWatch metrics to optimize performance settings
4. **Lifecycle management**: Implement backup and archival strategies

## Troubleshooting

### Common Issues

#### PVC Stuck in Pending
```bash
# Check events
kubectl describe pvc <pvc-name>

# Common causes:
# - Insufficient node capacity
# - AZ constraints
# - Storage class not found
```

#### Performance Issues
```bash
# Check volume performance
aws ec2 describe-volumes --volume-ids <volume-id>

# Monitor CloudWatch metrics:
# - VolumeReadOps/VolumeWriteOps
# - VolumeThroughputPercentage
# - VolumeConsumedReadWriteOps
```

#### Storage Class Not Found
```bash
# List available storage classes
kubectl get storageclass

# Check if GP3 classes are created
kubectl get storageclass | grep gp3
```

## Security Considerations

### Encryption
- All GP3 storage classes use encryption at rest
- Uses AWS managed keys by default
- Can be configured to use customer-managed KMS keys

### Access Control
```yaml
# Example RBAC for storage management
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: storage-admin
rules:
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list"]
```

## Integration with Monitoring

The storage classes integrate with the observability stack:

- **Prometheus**: Collects volume metrics
- **Grafana**: Provides storage dashboards
- **AlertManager**: Alerts on storage issues

### Key Metrics
- Volume utilization
- IOPS consumption
- Throughput utilization
- Volume queue depth
- Latency metrics

## Migration Guide

### From GP2 to GP3
1. **Create new PVC** with GP3 storage class
2. **Copy data** from old volume to new volume
3. **Update application** to use new PVC
4. **Delete old PVC** after verification

### Example Migration Script
```bash
#!/bin/bash
# Migrate from GP2 to GP3
OLD_PVC="app-storage-gp2"
NEW_PVC="app-storage-gp3"

# Create new PVC with GP3
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $NEW_PVC
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 100Gi
EOF

# Wait for PVC to be bound
kubectl wait --for=condition=Bound pvc/$NEW_PVC --timeout=300s

# Copy data (using a temporary pod)
kubectl run data-migration --image=busybox --rm -it --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"data-migration","image":"busybox","command":["sh"],"volumeMounts":[{"name":"old","mountPath":"/old"},{"name":"new","mountPath":"/new"}]}],"volumes":[{"name":"old","persistentVolumeClaim":{"claimName":"'$OLD_PVC'"}},{"name":"new","persistentVolumeClaim":{"claimName":"'$NEW_PVC'"}}]}}' \
  -- cp -r /old/* /new/

# Update application to use new PVC
# Delete old PVC after verification
```