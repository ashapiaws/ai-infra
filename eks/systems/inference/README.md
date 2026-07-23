# Inference Platform

Tiered inference architecture for routing requests to self-hosted models (vLLM/SGLang) and managed endpoints (Bedrock).

## Architecture

```
                    ┌─────────────────────────────────────────────────────┐
                    │              Client / App Layer                      │
                    │         (sends OpenAI-format requests)               │
                    └───────────────────────┬─────────────────────────────┘
                                            │
                    ┌───────────────────────▼─────────────────────────────┐
                    │         TIER 1: Ingress Gateway                      │
                    │                                                      │
                    │  • API key validation & auth                         │
                    │  • Model name → backend resolution                   │
                    │  • Rate limiting (per-tenant, per-model)             │
                    │  • Fallback routing (self-hosted → Bedrock)          │
                    │                                                      │
                    │  Implementations: KGateway + Envoy AI Gateway        │
                    └──────┬─────────────────┬────────────────┬───────────┘
                           │                 │                │
              ┌────────────▼──┐   ┌──────────▼────┐   ┌──────▼────────────┐
              │  TIER 2:      │   │  TIER 2:      │   │  TIER 2:          │
              │  vLLM         │   │  SGLang       │   │  Bedrock          │
              │  (self-hosted)│   │  (self-hosted)│   │  (managed, no     │
              │               │   │               │   │   infra needed)   │
              │  GPU nodes    │   │  GPU nodes    │   │                   │
              └───────────────┘   └───────────────┘   └───────────────────┘
                           │                 │                │
              ┌────────────▼─────────────────▼────────────────▼───────────┐
              │         TIER 3: Model Serving Orchestration (optional)     │
              │                                                            │
              │  • Autoscaling & scale-to-zero                             │
              │  • Canary rollouts                                          │
              │  • Model lifecycle management                               │
              │                                                            │
              │  Implementations: KServe, Bifrost                           │
              └────────────────────────────────────────────────────────────┘
```

## Tiers

| Tier | Purpose | Components | Change Frequency |
|------|---------|------------|------------------|
| **1** | Routing, auth, rate-limiting | KGateway, Envoy AI Gateway | Moderate (policy changes) |
| **2** | Model execution | NVIDIA Operator, vLLM, SGLang, Bedrock | Low (engine upgrades) |
| **3** | Orchestration | KServe, Bifrost | Low (serving strategy) |

## Usage

```bash
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Iteration Path

1. **Phase 1**: KGateway + Envoy AI Gateway → vLLM (current)
2. **Phase 2**: Add Bedrock routing rules for managed models
3. **Phase 3**: Enable rate-limiting at Tier 1
4. **Phase 4**: Add SGLang, benchmark vLLM vs SGLang
5. **Phase 5**: Enable KServe or Bifrost for autoscaling/canary

## Module Layout

```
modules/
  tier1-gateway/
    kgateway/            # Kubernetes Gateway API implementation
    envoy-ai-gateway/   # AI-aware routing, Bedrock fan-out, rate-limiting
  tier2-backends/
    nvidia-operator/     # GPU drivers & device plugin
    vllm/                # Self-hosted LLM inference
    sglang/              # Alternative inference engine
  tier3-serving/
    kserve/              # Serverless model serving
    bifrost/             # Unified AI gateway
```
