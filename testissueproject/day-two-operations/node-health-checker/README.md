# Node Health Checker

A Kubernetes DaemonSet application written in Go that monitors node health by collecting and analyzing `dmesg` and `systemctl` information. Provides Prometheus metrics and health check endpoints for comprehensive node monitoring.

## Features

- **dmesg Analysis**: Collects and analyzes kernel messages for errors and warnings
- **systemctl Monitoring**: Tracks systemd service status, especially critical services
- **Prometheus Metrics**: Exposes metrics for integration with Prometheus/Grafana
- **Health Endpoints**: Provides `/healthz`, `/readyz`, and `/health/details` endpoints
- **DaemonSet Deployment**: Runs on every node in the cluster
- **Low Resource Usage**: Minimal CPU and memory footprint
- **Configurable**: Adjustable collection intervals and log levels

## Architecture

The application consists of three main components:

1. **Collectors**: Gather data from dmesg and systemctl
2. **Health Checker**: Evaluates node health based on collected data
3. **Metrics Exporter**: Exposes Prometheus metrics

### Metrics Exposed

#### dmesg Metrics
- `node_dmesg_errors_total`: Total number of error patterns found in dmesg
- `node_dmesg_warnings_total`: Total number of warning patterns found in dmesg
- `node_dmesg_last_collection_timestamp_seconds`: Timestamp of last collection

#### systemctl Metrics
- `node_systemd_services_total`: Total number of systemd services
- `node_systemd_services_failed`: Number of failed systemd services
- `node_systemd_services_active`: Number of active systemd services
- `node_systemd_last_collection_timestamp_seconds`: Timestamp of last collection

### Health Endpoints

- **`/healthz`**: Liveness probe - returns 200 if the application is running
- **`/readyz`**: Readiness probe - returns 200 if node is healthy, 503 otherwise
- **`/health/details`**: Detailed health information in JSON format

## Prerequisites

- Kubernetes cluster (1.19+)
- kubectl configured
- Docker (for building images)
- Go 1.21+ (for local development)

## Quick Start

### Build and Deploy

```bash
# Build the Docker image
make docker-build

# Deploy to Kubernetes
make deploy

# Check status
make status

# View logs
make logs
```

### Local Development

```bash
# Download dependencies
make deps

# Build binary
make build

# Run tests
make test

# Run locally (requires root for dmesg/systemctl access)
sudo make run
```

## Configuration

The application accepts the following command-line flags:

| Flag | Default | Description |
|------|---------|-------------|
| `--metrics-addr` | `:9100` | Address for Prometheus metrics endpoint |
| `--health-addr` | `:8080` | Address for health check endpoints |
| `--collection-interval` | `60s` | Interval for collecting node health data |
| `--dmesg-lines` | `100` | Number of recent dmesg lines to analyze |
| `--log-level` | `info` | Log level (debug, info, warn, error) |

### Example Configuration

```yaml
args:
- --metrics-addr=:9100
- --health-addr=:8080
- --collection-interval=30s
- --dmesg-lines=200
- --log-level=debug
```

## Deployment

### DaemonSet Deployment

The application is deployed as a DaemonSet to run on every node:

```bash
kubectl apply -f deployments/daemonset.yaml
kubectl apply -f deployments/service.yaml
```

### Key Features of Deployment

- **Privileged Mode**: Required to access dmesg and systemctl on host
- **Host Network**: Uses host network for direct access to system information
- **Tolerations**: Runs on all nodes including those with taints
- **Resource Limits**: Configured with minimal resource requirements
- **ServiceMonitor**: Automatic Prometheus scraping configuration

### Critical Services Monitored

The following services are considered critical and monitored for health:

- `kubelet` - Kubernetes node agent
- `containerd` - Container runtime
- `docker` - Docker daemon (if used)
- `sshd` - SSH daemon
- `systemd-journald` - System logging
- `dbus` - System message bus

## Monitoring Integration

### Prometheus Integration

The ServiceMonitor automatically configures Prometheus to scrape metrics:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: node-health-checker
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: node-health-checker
  endpoints:
  - port: metrics
    interval: 30s
```

### Grafana Dashboard

Create alerts and dashboards using the exposed metrics:

```promql
# Alert on dmesg errors
node_dmesg_errors_total > 0

# Alert on failed services
node_systemd_services_failed > 0

# Alert on critical service failures
node_systemd_services_active{service="kubelet"} == 0
```

## Health Check Examples

### Liveness Probe

```bash
curl http://localhost:8080/healthz
# Response: ok
```

### Readiness Probe

```bash
curl http://localhost:8080/readyz
# Response: ready (if healthy)
# Response: {"status":"not ready",...} (if unhealthy)
```

### Detailed Health Information

```bash
curl http://localhost:8080/health/details
```

Example response:

```json
{
  "timestamp": "2024-01-16T10:30:00Z",
  "uptime": "2h15m30s",
  "dmesg": {
    "error_count": 0,
    "warning_count": 2,
    "recent_errors": [],
    "healthy": true
  },
  "systemctl": {
    "total_services": 145,
    "failed_services": [],
    "critical_services": {
      "kubelet": "active/running",
      "containerd": "active/running",
      "sshd": "active/running"
    },
    "healthy": true
  },
  "overall_healthy": true
}
```

## Troubleshooting

### Pods Not Starting

Check if the DaemonSet is deployed:

```bash
kubectl get daemonset -n kube-system node-health-checker
```

View pod events:

```bash
kubectl describe pod -n kube-system -l app=node-health-checker
```

### Permission Issues

The container requires privileged mode to access dmesg and systemctl. Verify security context:

```bash
kubectl get pod -n kube-system -l app=node-health-checker -o yaml | grep privileged
```

### Metrics Not Appearing in Prometheus

Check ServiceMonitor:

```bash
kubectl get servicemonitor -n kube-system node-health-checker
```

Verify Prometheus is scraping:

```bash
kubectl logs -n monitoring prometheus-xxx | grep node-health-checker
```

### High Error Counts

View detailed health information:

```bash
kubectl exec -n kube-system node-health-checker-xxx -- \
  curl localhost:8080/health/details
```

Check dmesg directly on the node:

```bash
kubectl exec -n kube-system node-health-checker-xxx -- dmesg -T --level=err
```

## Development

### Project Structure

```
node-health-checker/
├── cmd/
│   └── main.go                 # Application entry point
├── internal/
│   ├── collector/
│   │   ├── dmesg.go           # dmesg collector
│   │   └── systemctl.go       # systemctl collector
│   └── health/
│       └── checker.go         # Health check handlers
├── deployments/
│   ├── daemonset.yaml         # Kubernetes DaemonSet
│   └── service.yaml           # Service and ServiceMonitor
├── Dockerfile                  # Container image definition
├── Makefile                    # Build automation
├── go.mod                      # Go module definition
└── README.md                   # This file
```

### Running Tests

```bash
# Run all tests
make test

# Run tests with coverage
make coverage

# View coverage report
open coverage.html
```

### Code Quality

```bash
# Format code
make fmt

# Lint code
make lint
```

## Security Considerations

- **Privileged Mode**: Required for system-level access
- **Host Access**: Mounts host filesystem and systemd
- **RBAC**: Minimal permissions for node read access
- **Non-root User**: Runs as non-root where possible (except for privileged operations)

## Performance

- **CPU**: ~50m request, 200m limit
- **Memory**: ~64Mi request, 128Mi limit
- **Collection Interval**: Default 60s (configurable)
- **Network**: Minimal (only metrics scraping)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run `make test` and `make lint`
6. Submit a pull request

## License

MIT License - see LICENSE file for details

## Related Documentation

- [EKS Observability Stack](../../README.md)
- [Prometheus Integration](../../docs/GPU-Metrics-DCGM.md)
- [Node Exporter Guide](../../docs/Node-Exporter-Guide.md)
