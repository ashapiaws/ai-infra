# GPU Metrics with DCGM Exporter

## Overview

DCGM (Data Center GPU Manager) Exporter is a tool that exposes GPU metrics from NVIDIA GPUs to Prometheus. It's automatically deployed as part of the NVIDIA GPU Operator and provides comprehensive GPU telemetry for monitoring and alerting.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              GPU Node (g6e.12xlarge)                  │  │
│  │                                                        │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │  │
│  │  │   NVIDIA     │  │    DCGM      │  │    DCGM    │ │  │
│  │  │   Driver     │◄─┤   Daemon     │◄─┤  Exporter  │ │  │
│  │  │              │  │              │  │   :9400    │ │  │
│  │  └──────────────┘  └──────────────┘  └─────┬──────┘ │  │
│  │                                              │        │  │
│  └──────────────────────────────────────────────┼────────┘  │
│                                                 │           │
│                                          ┌──────▼──────┐    │
│                                          │ ServiceMonitor│   │
│                                          │  (30s scrape) │   │
│                                          └──────┬──────┘    │
│                                                 │           │
│                                          ┌──────▼──────┐    │
│                                          │ Prometheus  │    │
│                                          │   Server    │    │
│                                          └──────┬──────┘    │
│                                                 │           │
│                                          ┌──────▼──────┐    │
│                                          │   Grafana   │    │
│                                          │  Dashboard  │    │
│                                          └─────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Automatic Deployment with GPU Operator

DCGM Exporter is automatically configured when you enable the NVIDIA GPU Operator:

```hcl
# environments/dev.tfvars
helm_addons = {
  "nvidia-gpu-operator" = {
    enabled                     = true
    chart                      = "gpu-operator"
    chart_version              = "v24.9.0"
    repository                 = "https://helm.ngc.nvidia.com/nvidia"
    namespace                  = "gpu-operator"
    create_namespace           = true
  }
}
```

The addon configuration in `modules/addons/addon-configs.tf` includes:

```hcl
# DCGM Exporter configuration
{
  name  = "dcgmExporter.enabled"
  value = "true"
}
{
  name  = "dcgmExporter.serviceMonitor.enabled"
  value = "true"
}
{
  name  = "dcgmExporter.serviceMonitor.interval"
  value = "30s"
}
{
  name  = "dcgmExporter.serviceMonitor.honorLabels"
  value = "true"
}
{
  name  = "dcgmExporter.serviceMonitor.additionalLabels.release"
  value = "kube-prometheus-stack"
}
```

### Resource Limits

DCGM Exporter is configured with conservative resource limits:

```hcl
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

## GPU Metrics Reference

### Core GPU Metrics

| Metric | Description | Unit | Example Query |
|--------|-------------|------|---------------|
| `DCGM_FI_DEV_GPU_UTIL` | GPU utilization | % | `DCGM_FI_DEV_GPU_UTIL` |
| `DCGM_FI_DEV_MEM_COPY_UTIL` | Memory bandwidth utilization | % | `DCGM_FI_DEV_MEM_COPY_UTIL` |
| `DCGM_FI_DEV_FB_USED` | Framebuffer memory used | MB | `DCGM_FI_DEV_FB_USED` |
| `DCGM_FI_DEV_FB_FREE` | Framebuffer memory free | MB | `DCGM_FI_DEV_FB_FREE` |
| `DCGM_FI_DEV_GPU_TEMP` | GPU temperature | °C | `DCGM_FI_DEV_GPU_TEMP` |
| `DCGM_FI_DEV_POWER_USAGE` | Power usage | W | `DCGM_FI_DEV_POWER_USAGE` |
| `DCGM_FI_DEV_SM_CLOCK` | SM clock frequency | MHz | `DCGM_FI_DEV_SM_CLOCK` |
| `DCGM_FI_DEV_MEM_CLOCK` | Memory clock frequency | MHz | `DCGM_FI_DEV_MEM_CLOCK` |

### Performance Metrics

| Metric | Description | Unit |
|--------|-------------|------|
| `DCGM_FI_PROF_GR_ENGINE_ACTIVE` | Graphics engine active time | % |
| `DCGM_FI_PROF_SM_ACTIVE` | Streaming multiprocessor active | % |
| `DCGM_FI_PROF_SM_OCCUPANCY` | SM occupancy | % |
| `DCGM_FI_PROF_PIPE_TENSOR_ACTIVE` | Tensor core active time | % |
| `DCGM_FI_PROF_DRAM_ACTIVE` | DRAM active time | % |
| `DCGM_FI_PROF_PCIE_TX_BYTES` | PCIe transmit bytes | bytes/sec |
| `DCGM_FI_PROF_PCIE_RX_BYTES` | PCIe receive bytes | bytes/sec |

### Error and Health Metrics

| Metric | Description | Unit |
|--------|-------------|------|
| `DCGM_FI_DEV_XID_ERRORS` | XID error count | count |
| `DCGM_FI_DEV_ECC_SBE_VOL_TOTAL` | Single-bit ECC errors | count |
| `DCGM_FI_DEV_ECC_DBE_VOL_TOTAL` | Double-bit ECC errors | count |
| `DCGM_FI_DEV_RETIRED_SBE` | Retired pages (single-bit) | count |
| `DCGM_FI_DEV_RETIRED_DBE` | Retired pages (double-bit) | count |
| `DCGM_FI_DEV_NVLINK_CRC_FLIT_ERROR_COUNT_TOTAL` | NVLink CRC errors | count |

### Compute Metrics

| Metric | Description | Unit |
|--------|-------------|------|
| `DCGM_FI_PROF_PIPE_FP64_ACTIVE` | FP64 pipe active time | % |
| `DCGM_FI_PROF_PIPE_FP32_ACTIVE` | FP32 pipe active time | % |
| `DCGM_FI_PROF_PIPE_FP16_ACTIVE` | FP16 pipe active time | % |
| `DCGM_FI_DEV_NVLINK_BANDWIDTH_TOTAL` | Total NVLink bandwidth | MB/s |

## Prometheus Queries

### GPU Utilization

```promql
# Average GPU utilization across all GPUs
avg(DCGM_FI_DEV_GPU_UTIL)

# GPU utilization per GPU
DCGM_FI_DEV_GPU_UTIL

# GPU utilization per node
avg by (kubernetes_node) (DCGM_FI_DEV_GPU_UTIL)

# GPU utilization per pod
avg by (pod) (DCGM_FI_DEV_GPU_UTIL)
```

### Memory Usage

```promql
# GPU memory usage percentage
100 * (DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE))

# Total GPU memory used across cluster
sum(DCGM_FI_DEV_FB_USED)

# Available GPU memory
DCGM_FI_DEV_FB_FREE

# Memory bandwidth utilization
DCGM_FI_DEV_MEM_COPY_UTIL
```

### Temperature and Power

```promql
# GPU temperature
DCGM_FI_DEV_GPU_TEMP

# Average temperature across all GPUs
avg(DCGM_FI_DEV_GPU_TEMP)

# Power consumption
DCGM_FI_DEV_POWER_USAGE

# Total power consumption
sum(DCGM_FI_DEV_POWER_USAGE)

# Power efficiency (compute per watt)
DCGM_FI_DEV_GPU_UTIL / DCGM_FI_DEV_POWER_USAGE
```

### Performance Metrics

```promql
# SM occupancy
DCGM_FI_PROF_SM_OCCUPANCY

# Tensor core utilization
DCGM_FI_PROF_PIPE_TENSOR_ACTIVE

# PCIe bandwidth
rate(DCGM_FI_PROF_PCIE_TX_BYTES[5m])
rate(DCGM_FI_PROF_PCIE_RX_BYTES[5m])

# NVLink bandwidth
DCGM_FI_DEV_NVLINK_BANDWIDTH_TOTAL
```

### Error Detection

```promql
# XID errors (critical GPU errors)
increase(DCGM_FI_DEV_XID_ERRORS[5m])

# ECC errors
increase(DCGM_FI_DEV_ECC_SBE_VOL_TOTAL[5m])
increase(DCGM_FI_DEV_ECC_DBE_VOL_TOTAL[5m])

# Retired pages (indicates hardware issues)
DCGM_FI_DEV_RETIRED_SBE
DCGM_FI_DEV_RETIRED_DBE
```

## Grafana Dashboards

### Pre-built Dashboards

1. **NVIDIA DCGM Exporter Dashboard** (ID: 12239)
   - Comprehensive GPU metrics visualization
   - GPU utilization, memory, temperature, power
   - Per-GPU and cluster-wide views

2. **NVIDIA GPU Monitoring** (ID: 14574)
   - Detailed GPU performance metrics
   - Tensor core utilization
   - PCIe and NVLink bandwidth

3. **GPU Cluster Overview** (Custom)
   - Multi-node GPU cluster monitoring
   - Resource allocation and utilization
   - Cost optimization insights

### Importing Dashboards

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Navigate to: http://localhost:3000
# Go to: Dashboards → Import
# Enter Dashboard ID: 12239 or 14574
# Select Prometheus data source
```

### Custom Dashboard Example

```json
{
  "title": "GPU Cluster Overview",
  "panels": [
    {
      "title": "GPU Utilization",
      "targets": [
        {
          "expr": "avg(DCGM_FI_DEV_GPU_UTIL)"
        }
      ],
      "type": "graph"
    },
    {
      "title": "GPU Memory Usage",
      "targets": [
        {
          "expr": "100 * (DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE))"
        }
      ],
      "type": "graph"
    },
    {
      "title": "GPU Temperature",
      "targets": [
        {
          "expr": "DCGM_FI_DEV_GPU_TEMP"
        }
      ],
      "type": "graph"
    },
    {
      "title": "Power Consumption",
      "targets": [
        {
          "expr": "sum(DCGM_FI_DEV_POWER_USAGE)"
        }
      ],
      "type": "stat"
    }
  ]
}
```

## Operational Tasks

### Verify DCGM Exporter Deployment

```bash
# Check DCGM Exporter pods
kubectl get pods -n gpu-operator -l app=nvidia-dcgm-exporter

# Expected output:
# NAME                                    READY   STATUS    RESTARTS   AGE
# nvidia-dcgm-exporter-xxxxx              1/1     Running   0          5m

# Check DaemonSet
kubectl get daemonset -n gpu-operator nvidia-dcgm-exporter

# Verify running on GPU nodes
kubectl get pods -n gpu-operator -l app=nvidia-dcgm-exporter -o wide
```

### Access DCGM Metrics Directly

```bash
# Port-forward to DCGM Exporter
kubectl port-forward -n gpu-operator \
  $(kubectl get pods -n gpu-operator -l app=nvidia-dcgm-exporter -o name | head -1) \
  9400:9400

# Query metrics
curl http://localhost:9400/metrics | grep DCGM_FI_DEV_GPU_UTIL
curl http://localhost:9400/metrics | grep DCGM_FI_DEV_FB_USED
curl http://localhost:9400/metrics | grep DCGM_FI_DEV_GPU_TEMP
```

### Verify ServiceMonitor

```bash
# Check ServiceMonitor exists
kubectl get servicemonitor -n gpu-operator

# View ServiceMonitor configuration
kubectl get servicemonitor -n gpu-operator nvidia-dcgm-exporter -o yaml

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/targets
# Look for: gpu-operator/nvidia-dcgm-exporter
```

### View Logs

```bash
# View DCGM Exporter logs
kubectl logs -n gpu-operator -l app=nvidia-dcgm-exporter --tail=50

# View DCGM daemon logs
kubectl logs -n gpu-operator -l app=nvidia-dcgm --tail=50

# Check for errors
kubectl logs -n gpu-operator -l app=nvidia-dcgm-exporter | grep -i error
```

## Alerting Rules

### Recommended Prometheus Alerts

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: gpu-alerts
  namespace: gpu-operator
spec:
  groups:
  - name: gpu
    interval: 30s
    rules:
    # High GPU utilization
    - alert: HighGPUUtilization
      expr: DCGM_FI_DEV_GPU_UTIL > 90
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High GPU utilization on {{ $labels.gpu }}"
        description: "GPU {{ $labels.gpu }} on {{ $labels.kubernetes_node }} has been above 90% for 5 minutes"
    
    # High GPU temperature
    - alert: HighGPUTemperature
      expr: DCGM_FI_DEV_GPU_TEMP > 85
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High GPU temperature on {{ $labels.gpu }}"
        description: "GPU {{ $labels.gpu }} temperature is {{ $value }}°C"
    
    # GPU memory exhaustion
    - alert: GPUMemoryExhaustion
      expr: (DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) > 0.95
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "GPU memory nearly exhausted on {{ $labels.gpu }}"
        description: "GPU {{ $labels.gpu }} memory usage is above 95%"
    
    # XID errors (critical GPU errors)
    - alert: GPUXIDErrors
      expr: increase(DCGM_FI_DEV_XID_ERRORS[5m]) > 0
      labels:
        severity: critical
      annotations:
        summary: "GPU XID errors detected on {{ $labels.gpu }}"
        description: "GPU {{ $labels.gpu }} has reported XID errors"
    
    # ECC errors
    - alert: GPUECCErrors
      expr: increase(DCGM_FI_DEV_ECC_DBE_VOL_TOTAL[5m]) > 0
      labels:
        severity: critical
      annotations:
        summary: "GPU ECC errors on {{ $labels.gpu }}"
        description: "GPU {{ $labels.gpu }} has double-bit ECC errors"
    
    # GPU not responding
    - alert: GPUNotResponding
      expr: up{job="nvidia-dcgm-exporter"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "DCGM Exporter not responding"
        description: "DCGM Exporter on {{ $labels.kubernetes_node }} is not responding"
```

### Applying Alert Rules

```bash
# Create the PrometheusRule
kubectl apply -f gpu-alerts.yaml

# Verify the rule is loaded
kubectl get prometheusrule -n gpu-operator

# Check in Prometheus UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/alerts
```

## Troubleshooting

### DCGM Exporter Not Running

**Problem:** DCGM Exporter pods not starting.

**Diagnosis:**
```bash
# Check pod status
kubectl get pods -n gpu-operator -l app=nvidia-dcgm-exporter

# Check events
kubectl get events -n gpu-operator --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs -n gpu-operator -l app=nvidia-dcgm-exporter
```

**Common Solutions:**
- Ensure GPU nodes have NVIDIA drivers installed
- Verify GPU Operator is fully deployed
- Check node taints and tolerations
- Ensure privileged pod security policy

### Metrics Not Appearing in Prometheus

**Problem:** GPU metrics not visible in Prometheus.

**Diagnosis:**
```bash
# Check ServiceMonitor
kubectl get servicemonitor -n gpu-operator nvidia-dcgm-exporter -o yaml

# Verify labels match Prometheus selector
kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorSelector

# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
```

**Solutions:**
- Ensure ServiceMonitor has correct labels: `release: kube-prometheus-stack`
- Verify Prometheus can reach DCGM Exporter service
- Check network policies
- Verify scrape interval configuration

### Missing GPU Metrics

**Problem:** Some GPU metrics are missing.

**Diagnosis:**
```bash
# Check available metrics
curl http://localhost:9400/metrics | grep DCGM

# Check DCGM configuration
kubectl exec -n gpu-operator <dcgm-exporter-pod> -- dcgmi discovery -l
```

**Solutions:**
- Verify GPU model supports the metric
- Check DCGM version compatibility
- Review DCGM field group configuration
- Update GPU drivers if needed

### High Scrape Duration

**Problem:** Prometheus scrape duration is high.

**Diagnosis:**
```bash
# Check scrape duration in Prometheus
# Query: scrape_duration_seconds{job="nvidia-dcgm-exporter"}
```

**Solutions:**
- Reduce scrape interval (increase from 30s to 60s)
- Reduce number of metrics collected
- Optimize DCGM field groups
- Check GPU node performance

## Best Practices

1. **Scrape Interval**: Use 30s for production, 60s for development
   - Balance between metric freshness and overhead
   - GPU metrics don't change as rapidly as CPU metrics

2. **Resource Limits**: Monitor DCGM Exporter resource usage
   - Adjust limits based on number of GPUs per node
   - Typical: 100m CPU, 128Mi memory per 8 GPUs

3. **Alert Thresholds**: Set appropriate thresholds
   - GPU utilization: >90% for sustained periods
   - Temperature: >85°C (varies by GPU model)
   - Memory: >95% usage
   - XID errors: Any occurrence is critical

4. **Retention**: Configure appropriate metric retention
   - Development: 7 days
   - Production: 30-90 days
   - Consider downsampling for long-term storage

5. **Dashboard Organization**: Create role-specific dashboards
   - ML Engineers: Utilization, memory, performance
   - Operations: Temperature, power, errors
   - Finance: Cost optimization, utilization trends

## Integration with ML Workflows

### GPU Utilization Tracking

Track GPU utilization during training:

```python
# Example: Log GPU metrics during training
import requests
import time

def get_gpu_metrics():
    response = requests.get('http://dcgm-exporter:9400/metrics')
    metrics = {}
    for line in response.text.split('\n'):
        if 'DCGM_FI_DEV_GPU_UTIL' in line and not line.startswith('#'):
            metrics['gpu_util'] = float(line.split()[-1])
        if 'DCGM_FI_DEV_FB_USED' in line and not line.startswith('#'):
            metrics['gpu_memory'] = float(line.split()[-1])
    return metrics

# During training loop
for epoch in range(num_epochs):
    train_model()
    metrics = get_gpu_metrics()
    log_metrics(epoch, metrics)
```

### Cost Optimization

Monitor GPU efficiency:

```promql
# GPU efficiency (utilization per watt)
DCGM_FI_DEV_GPU_UTIL / DCGM_FI_DEV_POWER_USAGE

# Idle GPU detection (utilization < 10% for 1 hour)
avg_over_time(DCGM_FI_DEV_GPU_UTIL[1h]) < 10

# Cost per GPU hour (assuming $3/hour for g6e.12xlarge with 4 GPUs)
(3 / 4) * (1 - (DCGM_FI_DEV_GPU_UTIL / 100))
```

## Additional Resources

- [DCGM Documentation](https://docs.nvidia.com/datacenter/dcgm/latest/)
- [DCGM Exporter GitHub](https://github.com/NVIDIA/dcgm-exporter)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [GPU Monitoring Best Practices](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/monitoring.html)
