# RAID0 Setup for EKS Nodes with Local NVMe Storage

This EKS observability stack includes automatic RAID0 configuration for EC2 instances with local NVMe storage, providing high-performance ephemeral storage for workloads that need fast I/O.

## Overview

The RAID0 setup automatically:
- Detects local NVMe devices (excludes EBS volumes)
- Creates RAID0 arrays for multiple devices or single device mounts
- Configures XFS or ext4 filesystems
- Sets up persistent mounting via `/etc/fstab`
- Applies performance optimizations
- Provides detailed logging and status information
- Uses proper MIME multipart format for EKS compatibility
- Runs in background to not interfere with EKS node bootstrapping

## Configuration

### Node Group Configuration

Add RAID0 configuration to your node groups in `terraform.tfvars`:

```hcl
node_groups = {
  ml_workload = {
    instance_types = ["g6e.12xlarge"]  # Instance with local NVMe
    capacity_type  = "SPOT"
    
    # ... other configuration ...
    
    raid0_config = {
      enabled     = true
      mount_point = "/mnt/nvme-raid0"
      filesystem  = "xfs"  # or "ext4"
    }
  }
}
```

### Supported Instance Types

Instance types with local NVMe storage that benefit from RAID0:
- **GPU Instances**: g6e.*, g5.*, p4d.*, p3.*
- **Compute Optimized**: c5d.*, c5ad.*, c6id.*
- **Memory Optimized**: r5d.*, r5ad.*, r6id.*, x1e.*
- **Storage Optimized**: i3.*, i3en.*, i4i.*

## Features

### Automatic Detection
- Identifies local NVMe devices vs EBS volumes
- Excludes root and boot devices
- Handles single or multiple NVMe devices

### RAID0 Configuration
- **Multiple devices**: Creates mdadm RAID0 array (`/dev/md0`)
- **Single device**: Direct mount without RAID overhead
- **Persistent**: Survives reboots via `/etc/fstab`

### Performance Optimizations
- Sets I/O scheduler to `none` for NVMe devices
- Configures read-ahead for sequential performance
- Creates convenience symlink at `/mnt/fast-storage`

### Filesystem Support
- **XFS**: Recommended for large files and high throughput
- **ext4**: Good general-purpose option

## Usage Examples

### High-Performance ML Training
```hcl
raid0_config = {
  enabled     = true
  mount_point = "/mnt/training-data"
  filesystem  = "xfs"
}
```

### Container Image Cache
```hcl
raid0_config = {
  enabled     = true
  mount_point = "/mnt/container-cache"
  filesystem  = "ext4"
}
```

### Temporary Scratch Space
```hcl
raid0_config = {
  enabled     = true
  mount_point = "/mnt/scratch"
  filesystem  = "xfs"
}
```

## Monitoring and Verification

### Check RAID Status
```bash
# For RAID arrays
sudo mdadm --detail /dev/md0

# Check mount status
df -h /mnt/nvme-raid0
mountpoint /mnt/nvme-raid0
```

### View Setup Information
```bash
# Check setup log
sudo cat /var/log/raid0-setup.log

# View configuration info
cat /mnt/nvme-raid0/raid0-info.txt
```

### Performance Testing
```bash
# Sequential write test
sudo dd if=/dev/zero of=/mnt/nvme-raid0/test bs=1M count=1000 oflag=direct

# Random I/O test (requires fio)
sudo fio --name=random-rw --ioengine=libaio --iodepth=32 --rw=randrw \
    --bs=4k --direct=1 --size=1G --numjobs=4 --runtime=60 \
    --filename=/mnt/nvme-raid0/fio-test
```

## Important Considerations

### Data Persistence
- **Ephemeral Storage**: Data is lost on instance stop/termination
- **Reboot Safe**: Data persists across reboots
- **Use Cases**: Temporary data, caches, scratch space, training datasets

### Performance Characteristics
- **High IOPS**: Excellent for random I/O workloads
- **High Throughput**: Great for sequential operations
- **Low Latency**: Direct attached storage with minimal overhead

### Best Practices
1. **Backup Important Data**: Use S3 or EFS for persistent storage
2. **Monitor Disk Usage**: Set up CloudWatch alarms for disk space
3. **Regular Health Checks**: Monitor RAID array status
4. **Graceful Shutdowns**: Ensure applications handle instance termination

## Troubleshooting

### Common Issues

#### No NVMe Devices Detected
```bash
# Check available block devices
lsblk
nvme list

# Verify instance type supports local storage
curl -s http://169.254.169.254/latest/meta-data/instance-type
```

#### Mount Failures
```bash
# Check setup log
sudo tail -f /var/log/raid0-setup.log

# Verify filesystem
sudo fsck /dev/md0  # or specific device

# Check fstab entry
grep raid0 /etc/fstab
```

#### Performance Issues
```bash
# Check I/O scheduler
cat /sys/block/nvme*/queue/scheduler

# Monitor I/O performance
iostat -x 1

# Check RAID status
cat /proc/mdstat
```

## Integration with Kubernetes

### Pod Volume Mounts
```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: ml-training
    volumeMounts:
    - name: fast-storage
      mountPath: /data
  volumes:
  - name: fast-storage
    hostPath:
      path: /mnt/nvme-raid0
      type: Directory
```

### Storage Classes
Consider creating a storage class for local NVMe storage:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-nvme
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

## Security Considerations

- RAID0 volumes are encrypted at rest when using encrypted EBS root volumes
- Local NVMe storage is not encrypted by default
- Consider application-level encryption for sensitive data
- Implement proper access controls and pod security policies

## Cost Optimization

- Use Spot instances for cost-effective high-performance storage
- Scale down node groups when not needed
- Monitor usage patterns to optimize instance selection
- Consider reserved instances for predictable workloads