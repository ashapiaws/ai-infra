# Infrastructure Validation Tests

Simple pod deployments to validate base cluster components after Terraform apply.

## Usage

```bash
# Apply all tests
kubectl apply -f test/

# Check pod status
kubectl get pods -n infra-test

# Cleanup
kubectl delete -f test/
```

## Tests

| File | Validates |
|------|-----------|
| `00-namespace.yaml` | Creates the infra-test namespace |
| `01-pod-to-pod.yaml` | Pod-to-pod communication within the cluster |
| `02-pod-to-external.yaml` | Pod-to-external internet connectivity (DNS + HTTPS) |
| `03-service-lb.yaml` | AWS Load Balancer Controller creates a NLB via Service type LoadBalancer |
| `04-gateway-api-nlb.yaml` | Kubernetes Gateway API spec with NLB provisioning |
