# Applications

This directory contains application deployments and configurations for running workloads on the EKS cluster.

## Overview

The applications directory is organized to separate different types of workloads and their configurations. This structure helps maintain clear boundaries between infrastructure (managed by Terraform) and application deployments (managed by Kubernetes manifests or Helm charts).

## Directory Structure

```
applications/
├── README.md                    # This file
├── examples/                    # Example application deployments
├── ml-workloads/               # Machine learning applications
├── web-services/               # Web applications and APIs
├── batch-jobs/                 # Batch processing jobs
└── monitoring-apps/            # Monitoring and observability applications
```

## Deployment Patterns

### Helm Charts

For complex applications with multiple components:

```bash
helm install my-app ./applications/my-app \
  --namespace my-namespace \
  --create-namespace \
  --values values.yaml
```

### Kubernetes Manifests

For simpler applications:

```bash
kubectl apply -f applications/my-app/
```

### Kustomize

For environment-specific configurations:

```bash
kubectl apply -k applications/my-app/overlays/production
```

## Application Categories

### ML Workloads

Machine learning and AI applications that leverage GPU resources:

- Training jobs
- Inference services
- Jupyter notebooks
- MLflow tracking

**Requirements**:
- GPU node groups
- NVIDIA GPU Operator
- Persistent storage for models
- High-performance networking

### Web Services

HTTP-based applications and APIs:

- REST APIs
- GraphQL services
- Web applications
- Microservices

**Requirements**:
- Ingress controller
- TLS certificates
- Horizontal Pod Autoscaling
- Service mesh (optional)

### Batch Jobs

Scheduled and one-time batch processing:

- CronJobs
- Data processing pipelines
- ETL jobs
- Backup jobs

**Requirements**:
- Job scheduling
- Resource quotas
- Persistent storage
- Monitoring

### Monitoring Applications

Additional monitoring and observability tools:

- Custom dashboards
- Log aggregators
- APM tools
- Tracing systems

**Requirements**:
- Integration with Prometheus
- Access to cluster metrics
- Persistent storage
- ServiceMonitors

## Best Practices

### Resource Management

1. **Set Resource Requests and Limits**:
   ```yaml
   resources:
     requests:
       cpu: 100m
       memory: 128Mi
     limits:
       cpu: 500m
       memory: 512Mi
   ```

2. **Use Namespaces**: Isolate applications in separate namespaces
3. **Apply Resource Quotas**: Prevent resource exhaustion
4. **Use LimitRanges**: Set default resource constraints

### Security

1. **Use Service Accounts**: Create dedicated service accounts
2. **Apply RBAC**: Implement least-privilege access
3. **Network Policies**: Control pod-to-pod communication
4. **Pod Security Standards**: Enforce security policies
5. **Secrets Management**: Use Kubernetes Secrets or external secret managers

### Observability

1. **Add Prometheus Annotations**:
   ```yaml
   annotations:
     prometheus.io/scrape: "true"
     prometheus.io/port: "8080"
     prometheus.io/path: "/metrics"
   ```

2. **Implement Health Checks**:
   ```yaml
   livenessProbe:
     httpGet:
       path: /healthz
       port: 8080
   readinessProbe:
     httpGet:
       path: /readyz
       port: 8080
   ```

3. **Structured Logging**: Use JSON format for logs
4. **Distributed Tracing**: Implement OpenTelemetry

### High Availability

1. **Multiple Replicas**: Run at least 2 replicas
2. **Pod Disruption Budgets**: Ensure availability during updates
3. **Anti-Affinity Rules**: Spread pods across nodes
4. **Readiness Gates**: Control traffic during deployments

## Integration with EKS Stack

Applications deployed in this directory integrate with the EKS Observability Stack:

- **Prometheus**: Automatic metrics collection via ServiceMonitors
- **Grafana**: Visualize application metrics in dashboards
- **AlertManager**: Receive alerts for application issues
- **Storage Classes**: Use GP3 storage for persistent volumes
- **GPU Operator**: Access GPU resources for ML workloads
- **Cluster Autoscaler**: Automatic scaling based on demand

## Example Application Structure

```
applications/my-app/
├── README.md                    # Application documentation
├── Chart.yaml                   # Helm chart metadata (if using Helm)
├── values.yaml                  # Default values
├── values-dev.yaml             # Development overrides
├── values-prod.yaml            # Production overrides
├── templates/                   # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── servicemonitor.yaml
│   └── hpa.yaml
└── tests/                       # Application tests
    └── test-connection.yaml
```

## Deployment Workflow

1. **Development**:
   ```bash
   # Deploy to dev namespace
   helm install my-app ./applications/my-app \
     --namespace dev \
     --values values-dev.yaml
   ```

2. **Testing**:
   ```bash
   # Run tests
   helm test my-app -n dev
   
   # Check metrics
   kubectl port-forward -n dev svc/my-app 8080:8080
   curl http://localhost:8080/metrics
   ```

3. **Production**:
   ```bash
   # Deploy to production
   helm upgrade --install my-app ./applications/my-app \
     --namespace production \
     --values values-prod.yaml \
     --wait
   ```

## Monitoring Applications

### View Application Logs

```bash
kubectl logs -n <namespace> -l app=<app-name> --tail=100 -f
```

### Check Application Metrics

```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Query application metrics
# Open http://localhost:9090
```

### View Application in Grafana

```bash
# Port forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Open http://localhost:3000
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n <namespace>

# Describe pod
kubectl describe pod -n <namespace> <pod-name>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Application Errors

```bash
# View logs
kubectl logs -n <namespace> <pod-name>

# Check previous container logs
kubectl logs -n <namespace> <pod-name> --previous

# Execute commands in pod
kubectl exec -it -n <namespace> <pod-name> -- /bin/sh
```

### Resource Issues

```bash
# Check resource usage
kubectl top pods -n <namespace>

# Check resource quotas
kubectl describe resourcequota -n <namespace>

# Check limit ranges
kubectl describe limitrange -n <namespace>
```

## Contributing

When adding new applications:

1. Create a dedicated directory
2. Include comprehensive README
3. Provide example configurations
4. Add monitoring integration
5. Include health checks
6. Document resource requirements
7. Add deployment instructions

## Related Documentation

- [EKS Observability Stack](../README.md)
- [Day Two Operations](../day-two-operations/README.md)
- [Addons Management](../docs/Addons-Management.md)
- [Storage Classes](../docs/Storage-Classes.md)
