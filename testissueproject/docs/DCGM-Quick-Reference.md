# DCGM Exporter Quick Reference

## Quick Start

### Enable DCGM Exporter
```hcl
# environments/dev.tfvars
helm_addons = {
  "nvidia-gpu-operator" = {
    enabled = true
  }
}
```

DCGM Exporter is automatically enabled with ServiceMonitor when GPU Operator is deployed.

### Verify Deployment
```bash
# Check DCGM Exporter pods
kubectl get pods -n gpu-operator -l app=nvidia-dcgm-exporter

# Access metrics
kubectl port-forward -n gpu-operator \
  $(kubectl get pods -n gpu-operator -l app=nvidia-dcgm-exporter -o name | head -1) \
  9400:9400

curl http://localhost:9400/metrics | grep DCGM
```

## Essential Metrics

| Metric | What It Measures | Alert Threshold |
|--------|------------------|-----------------|
| `DCGM_FI_DEV_GPU_UTIL` | GPU compute utilization (%) | > 90% sustained |
| `DCGM_FI_DEV_FB_USED` | GPU memory used (MB) | > 95% of total |
| `DCGM_FI_DEV_GPU_TEMP` | GPU temperature (°C) | > 85°C |
| `DCGM_FI_DEV_POWER_USAGE` | Power consumption (W) | > rated TDP |
| `DCGM_FI_DEV_XID_ERRORS` | Critical GPU errors | Any increase |
| `DCGM_FI_DEV_MEM_COPY_UTIL` | Memory bandwidth (%) | > 90% sustained |

## Common Queries

### GPU Utilization
```promql
# Average across all GPUs
avg(DCGM_FI_DEV_GPU_UTIL)

# Per GPU
DCGM_FI_DEV_GPU_UTIL

# Per node
avg by (kubernetes_node) (DCGM_FI_DEV_GPU_UTIL)
```

### Memory Usage
```promql
# Memory usage percentage
100 * (DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE))

# Total memory used
sum(DCGM_FI_DEV_FB_USED)
```

### Temperature & Power
```promql
# Temperature
DCGM_FI_DEV_GPU_TEMP

# Power consumption
DCGM_FI_DEV_POWER_USAGE

# Efficiency (compute per watt)
DCGM_FI_DEV_GPU_UTIL / DCGM_FI_DEV_POWER_USAGE
```

### Error Detection
```promql
# XID errors (critical)
increase(DCGM_FI_DEV_XID_ERRORS[5m])

# ECC errors
increase(DCGM_FI_DEV_ECC_DBE_VOL_TOTAL[5m])
```

## Grafana Dashboards

### Import Pre-built Dashboard
1. Access Grafana: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`
2. Navigate to: Dashboards → Import
3. Enter Dashboard ID: **12239** (NVIDIA DCGM Exporter Dashboard)
4. Select Prometheus data source
5. Click Import

### Recommended Dashboards
- **12239** - NVIDIA DCGM Exporter Dashboard (comprehensive)
- **14574** - NVIDIA GPU Monitoring (detailed performance)

## Troubleshooting

### DCGM Exporter Not Running
```bash
# Check status
kubectl get pods -n gpu-operator -l app=nvidia-dcgm-exporter

# View logs
kubectl logs -n gpu-operator -l app=nvidia-dcgm-exporter --tail=50

# Check events
kubectl get events -n gpu-operator --sort-by='.lastTimestamp'
```

### Metrics Not in Prometheus
```bash
# Verify ServiceMonitor
kubectl get servicemonitor -n gpu-operator

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/targets
# Look for: gpu-operator/nvidia-dcgm-exporter
```

### Missing Metrics
```bash
# List available metrics
curl http://localhost:9400/metrics | grep DCGM | cut -d' ' -f1 | sort -u

# Check GPU detection
kubectl exec -n gpu-operator <dcgm-exporter-pod> -- dcgmi discovery -l
```

## Alert Examples

### High GPU Utilization
```yaml
- alert: HighGPUUtilization
  expr: DCGM_FI_DEV_GPU_UTIL > 90
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "GPU {{ $labels.gpu }} utilization > 90%"
```

### High Temperature
```yaml
- alert: HighGPUTemperature
  expr: DCGM_FI_DEV_GPU_TEMP > 85
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "GPU {{ $labels.gpu }} temperature {{ $value }}°C"
```

### Memory Exhaustion
```yaml
- alert: GPUMemoryExhaustion
  expr: (DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) > 0.95
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "GPU {{ $labels.gpu }} memory > 95%"
```

### Critical Errors
```yaml
- alert: GPUXIDErrors
  expr: increase(DCGM_FI_DEV_XID_ERRORS[5m]) > 0
  labels:
    severity: critical
  annotations:
    summary: "GPU {{ $labels.gpu }} XID errors detected"
```

## Configuration Reference

### ServiceMonitor Settings
```hcl
# In modules/addons/addon-configs.tf
dcgmExporter.serviceMonitor.enabled = true
dcgmExporter.serviceMonitor.interval = "30s"
dcgmExporter.serviceMonitor.honorLabels = true
dcgmExporter.serviceMonitor.additionalLabels.release = "kube-prometheus-stack"
```

### Resource Limits
```hcl
dcgmExporter.resources.limits.cpu = "200m"
dcgmExporter.resources.limits.memory = "256Mi"
dcgmExporter.resources.requests.cpu = "100m"
dcgmExporter.resources.requests.memory = "128Mi"
```

## Performance Tips

1. **Scrape Interval**: 30s is optimal for most workloads
   - Increase to 60s for cost savings
   - Decrease to 15s for high-frequency monitoring

2. **Metric Retention**: Configure in Prometheus
   - Development: 7 days
   - Production: 30-90 days

3. **Dashboard Refresh**: Set to match scrape interval
   - 30s scrape → 30s dashboard refresh

4. **Alert Evaluation**: Balance responsiveness vs noise
   - Use `for: 5m` to avoid alert flapping
   - Adjust thresholds based on workload patterns

## Cost Optimization

### Identify Idle GPUs
```promql
# GPUs with < 10% utilization for 1 hour
avg_over_time(DCGM_FI_DEV_GPU_UTIL[1h]) < 10
```

### Calculate GPU Efficiency
```promql
# Compute per watt
DCGM_FI_DEV_GPU_UTIL / DCGM_FI_DEV_POWER_USAGE

# Wasted capacity (idle time)
100 - DCGM_FI_DEV_GPU_UTIL
```

### Cost Per GPU Hour
```promql
# For g6e.12xlarge ($3/hour, 4 GPUs)
# Cost of idle GPU time
(3 / 4) * (1 - (DCGM_FI_DEV_GPU_UTIL / 100))
```

## Integration Examples

### Python Script
```python
import requests

def get_gpu_metrics():
    response = requests.get('http://dcgm-exporter:9400/metrics')
    metrics = {}
    for line in response.text.split('\n'):
        if 'DCGM_FI_DEV_GPU_UTIL' in line and not line.startswith('#'):
            gpu_id = line.split('gpu="')[1].split('"')[0]
            value = float(line.split()[-1])
            metrics[f'gpu_{gpu_id}_util'] = value
    return metrics

# Usage in training loop
metrics = get_gpu_metrics()
print(f"GPU Utilization: {metrics}")
```

### Kubernetes Job Monitoring
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ml-training
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9400"
spec:
  template:
    spec:
      containers:
      - name: training
        image: ml-training:latest
        resources:
          limits:
            nvidia.com/gpu: 1
```

## Additional Resources

- [Full GPU Metrics Guide](GPU-Metrics-DCGM.md)
- [DCGM Documentation](https://docs.nvidia.com/datacenter/dcgm/latest/)
- [Prometheus Queries](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
