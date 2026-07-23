# Day Two Operations

This directory contains operational tools and utilities for managing and monitoring the EKS cluster after initial deployment. These tools help with ongoing maintenance, troubleshooting, and optimization.

## Overview

Day-two operations refer to the ongoing activities required to maintain, monitor, and optimize a production Kubernetes cluster. This includes:

- **Health Monitoring**: Continuous monitoring of node and cluster health
- **Troubleshooting**: Tools for diagnosing and resolving issues
- **Performance Optimization**: Utilities for analyzing and improving performance
- **Maintenance**: Automated maintenance tasks and scripts
- **Incident Response**: Tools for responding to and resolving incidents

## Available Tools

### Node Health Checker

A Go-based containerized application that monitors node health by collecting and analyzing system information.

**Location**: `node-health-checker/`

**Features**:
- Collects and analyzes dmesg output for kernel errors
- Monitors systemd service status
- Exposes Prometheus metrics
- Provides health check endpoints
- Runs as a DaemonSet on all nodes

**Quick Start**:
```bash
cd node-health-checker
make docker-build
make deploy
```

See [Node Health Checker README](./node-health-checker/README.md) for detailed documentation.

## Planned Tools

### Log Aggregator
- Centralized log collection and analysis
- Integration with CloudWatch Logs
- Custom log parsing and alerting

### Performance Analyzer
- Node performance profiling
- Resource utilization analysis
- Bottleneck identification

### Backup and Recovery
- Automated backup scripts
- Disaster recovery procedures
- State restoration tools

### Cost Optimizer
- Resource usage analysis
- Cost optimization recommendations
- Right-sizing suggestions

## Integration with EKS Observability Stack

These day-two operations tools integrate seamlessly with the main EKS Observability Stack:

- **Prometheus**: Metrics from operational tools are scraped by Prometheus
- **Grafana**: Dashboards visualize operational metrics alongside cluster metrics
- **AlertManager**: Alerts from operational tools trigger notifications
- **ServiceMonitor**: Automatic discovery and scraping configuration

## Best Practices

1. **Deploy Early**: Install operational tools during initial cluster setup
2. **Monitor Continuously**: Set up alerts for critical operational metrics
3. **Regular Reviews**: Periodically review operational data for trends
4. **Automate Responses**: Create automated responses for common issues
5. **Document Procedures**: Maintain runbooks for operational procedures

## Directory Structure

```
day-two-operations/
├── README.md                    # This file
├── node-health-checker/         # Node health monitoring tool
│   ├── cmd/                     # Application entry point
│   ├── internal/                # Internal packages
│   ├── deployments/             # Kubernetes manifests
│   ├── Dockerfile               # Container image
│   ├── Makefile                 # Build automation
│   └── README.md                # Tool documentation
└── [future tools]/              # Additional operational tools
```

## Contributing

When adding new operational tools:

1. Create a new directory for the tool
2. Include comprehensive README documentation
3. Provide Kubernetes deployment manifests
4. Add Prometheus metrics integration
5. Include health check endpoints
6. Write tests for critical functionality
7. Update this README with tool information

## Related Documentation

- [EKS Observability Stack](../README.md) - Main infrastructure documentation
- [Addons Management](../docs/Addons-Management.md) - Cluster addon management
- [GPU Metrics](../docs/GPU-Metrics-DCGM.md) - GPU monitoring setup
- [Node Exporter](../docs/Node-Exporter-Guide.md) - Node metrics collection

## Support

For issues or questions about day-two operations tools:
- Check tool-specific README files
- Review Kubernetes logs: `kubectl logs -n kube-system -l app=<tool-name>`
- Verify metrics in Prometheus
- Check health endpoints
