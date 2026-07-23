# AI Platform - EKS Systems Deployment

Modular Terraform deployment for AI/ML infrastructure components on an existing EKS cluster. Each component is deployed via Helm and toggled independently through boolean variables, making future migration to ArgoCD straightforward.

Cluster endpoint and CA certificate are fetched dynamically via `data.aws_eks_cluster` — just provide the cluster name.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Existing EKS Cluster (VPC, subnets, GPU node groups g6/g7)                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Layer 1: GPU Infrastructure                                                 │
│  ┌─────────────────────┐                                                    │
│  │  NVIDIA GPU Operator │                                                    │
│  └──────────┬──────────┘                                                    │
│             │                                                                │
│  Layer 2: Scheduling & Orchestration                                         │
│  ┌──────────┐  ┌──────────┐  ┌────────────────┐                            │
│  │ KubeRay  │  │  Flyte   │  │    Volcano     │                            │
│  └──────────┘  └──────────┘  └────────────────┘                            │
│                                                                              │
│  Layer 3: Networking                                                         │
│  ┌──────────┐  ┌──────────┐                                                │
│  │  Istio   │  │ KGateway │                                                │
│  └──────────┘  └─────┬────┘                                                │
│                       │                                                      │
│  Layer 4: Inference Engines                                                  │
│  ┌──────────┐  ┌──────────┐                                                │
│  │   vLLM   │  │  SGLang  │                                                │
│  └─────┬────┘  └────┬─────┘                                                │
│        │             │                                                       │
│  Layer 5: AI Gateways / Model Serving                                        │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐                         │
│  │  KServe  │  │ Bifrost  │  │ Envoy AI Gateway  │ ← routes to vLLM/SGLang │
│  └──────────┘  └──────────┘  └───────────────────┘                         │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Purpose | Layer |
|-----------|---------|-------|
| NVIDIA GPU Operator | Automates GPU driver, runtime, device plugin | 1 - GPU Infra |
| KubeRay | Manages Ray clusters for distributed compute | 2 - Scheduling |
| Flyte | Workflow orchestration for ML pipelines | 2 - Scheduling |
| Volcano | Gang scheduling for ML/HPC batch jobs | 2 - Scheduling |
| Istio | Service mesh for traffic/observability/security | 3 - Networking |
| KGateway | Kubernetes Gateway API (Envoy-based) | 3 - Networking |
| vLLM | High-throughput LLM inference engine | 4 - Inference |
| SGLang | Fast LLM serving with RadixAttention | 4 - Inference |
| KServe | Serverless model serving platform | 5 - AI Gateway |
| Bifrost | Unified AI gateway for LLM routing | 5 - AI Gateway |
| Envoy AI Gateway | Envoy-based gateway for AI inference traffic | 5 - AI Gateway |

## Prerequisites

- Existing EKS cluster (3-node GPU cluster with g6/g7 instances)
- VPC and subnets already provisioned
- AWS CLI configured with cluster access
- Terraform >= 1.5.0

## Usage

```bash
# Initialize
terraform init

# Plan with dev environment
terraform plan -var-file=dev.tfvars

# Apply
terraform apply -var-file=dev.tfvars
```

## Toggle Components

Each component can be independently enabled/disabled in your `.tfvars` file:

```hcl
# Core infrastructure
enable_nvidia_operator = true
enable_volcano         = true
enable_kuberay         = true
enable_flyte           = true

# Networking (pick one or both)
enable_istio    = true
enable_kgateway = true

# Inference engines (pick one or both)
enable_vllm   = true
enable_sglang = true

# AI Gateways (pick one or more to test)
enable_kserve           = true
enable_bifrost          = false
enable_envoy_ai_gateway = false
```

## Inference Routing

The `inference_router` variable controls which backends KServe and Bifrost point to:

```hcl
inference_router = "vllm"    # Route to vLLM only
inference_router = "sglang"  # Route to SGLang only
inference_router = "both"    # Route to both (Bifrost load-balances)
```

## Dependency Order

```
Layer 1: nvidia-operator
Layer 2: kuberay (needs GPU) | flyte | volcano (independent)
Layer 3: istio | kgateway (independent)
Layer 4: vllm (needs GPU + kuberay) | sglang (needs GPU)
Layer 5: kserve (needs istio/kgateway + inference) | bifrost (needs kgateway + inference) | envoy-ai-gateway (needs kgateway + inference)
```

## Testing Architectures

Mix and match to compare approaches:

| Scenario | Toggles |
|----------|---------|
| KServe + vLLM | `enable_kserve=true, enable_vllm=true, inference_router="vllm"` |
| KServe + SGLang | `enable_kserve=true, enable_sglang=true, inference_router="sglang"` |
| Bifrost + both engines | `enable_bifrost=true, enable_vllm=true, enable_sglang=true, inference_router="both"` |
| KGateway direct | `enable_kgateway=true, enable_vllm=true` (route at Gateway level) |

## ArgoCD Migration Path

Each module maps 1:1 to an ArgoCD Application. When ready to migrate:
1. Export the Helm values from each module
2. Create an ArgoCD Application per component pointing to the same chart/repo
3. Remove the corresponding `enable_*` toggle and module block
