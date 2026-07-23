# Gateway API - ALB TLS Re-encryption Pattern

## Overview

This directory contains Kubernetes Gateway API resources that provision an ALB
via the AWS Load Balancer Controller. The ALB terminates external TLS using an
ACM certificate and re-encrypts traffic (HTTPS) to the Istio Ingress Gateway.

## Prerequisites

1. **AWS Load Balancer Controller** installed in the EKS cluster
2. **Gateway API CRDs** installed (`kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml`)
3. **ACM Certificate** provisioned via Terraform (see `../terraform/`)
4. **Istio Ingress Gateway** deployed with ClusterIP service type (see `../istio-values.yaml`)

## Deployment Order

```bash
# 1. Provision ACM certificate
cd ../terraform
terraform apply -var-file=../../dev.tfvars

# 2. Get the ACM certificate ARN
export ACM_CERT_ARN=$(terraform output -raw acm_certificate_arn)

# 3. Update the Gateway manifest with the cert ARN
sed -i "s|\${ACM_CERTIFICATE_ARN}|${ACM_CERT_ARN}|g" gateway.yaml

# 4. Apply Gateway API resources
kubectl apply -f gatewayclass.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
```

## How It Works

```
Client ──HTTPS──► ALB (TLS termination via ACM)
                    │  Provisioned by AWS LB Controller via Gateway API
                    ▼ HTTPS (re-encrypt, backend-protocol: HTTPS)
              Istio Ingress Gateway (ClusterIP:443)
                    │  Presents self-signed cert from cert-manager
                    ▼
              Istio VirtualService → Backend Pods
```

## Key Annotations

| Annotation | Value | Purpose |
|-----------|-------|---------|
| `backend-protocol` | HTTPS | Re-encrypts traffic to Istio |
| `target-type` | ip | Routes directly to pod IPs |
| `healthcheck-port` | 15021 | Istio pilot agent status port |
| `healthcheck-path` | /healthz/ready | Istio readiness endpoint |
| `certificate-arn` | (from TF) | ACM cert for external TLS |
| `ssl-policy` | TLS13-1-2-2021-06 | Enforces TLS 1.2+ externally |

## Verifying

```bash
# Check Gateway status
kubectl get gateway istio-alb-gateway -n istio-system

# Check ALB was provisioned
kubectl describe gateway istio-alb-gateway -n istio-system

# Get ALB DNS name from Gateway status
kubectl get gateway istio-alb-gateway -n istio-system -o jsonpath='{.status.addresses[0].value}'
```
