# Inference Pattern — vLLM on EKS

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Amazon EKS Cluster                        │
│                                                                  │
│  ┌──────────┐     ┌──────────────┐     ┌────────────────────┐  │
│  │Open WebUI│────▶│LiteLLM Gateway│────▶│ vLLM (8B, 1xGPU)  │  │
│  │  :8080   │     │    :4000      │     │      :8000         │  │
│  └──────────┘     └──────────────┘     └────────────────────┘  │
│                          │                                       │
│                          │              ┌────────────────────┐  │
│                          └─────────────▶│ vLLM (70B, 4xGPU) │  │
│                                         │      :8000         │  │
│                                         └────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Purpose | Port |
|-----------|---------|------|
| vLLM | Model inference server (OpenAI-compatible) | 8000 |
| LiteLLM | AI Gateway — routing, load balancing, observability | 4000 |
| Open WebUI | Chat interface (OpenAI-compatible client) | 8080 |

## Prerequisites

1. EKS cluster with GPU node groups (g5, g6, or g6e instances)
2. NVIDIA device plugin installed (`kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.5/nvidia-device-plugin.yml`)
3. HuggingFace token with access to gated models (Llama 3.1)
4. Storage class `gp3` available (EBS CSI driver)
5. AWS Load Balancer Controller (for Ingress)

## Deployment

```bash
# 1. Create namespace and deploy vLLM
kubectl apply -k patterns/inference/

# 2. Create the HF token secret (replace with your token)
kubectl create secret generic hf-token \
  --namespace inference \
  --from-literal=token=hf_YOUR_TOKEN_HERE

# 3. Deploy the AI gateway and web UI
kubectl apply -k patterns/gateway/

# 4. Verify pods are running
kubectl get pods -n inference

# 5. Port-forward to test locally
kubectl port-forward svc/open-webui -n inference 8080:8080
kubectl port-forward svc/litellm-gateway -n inference 4000:4000
```

## Testing the API

```bash
# Direct vLLM call
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-3.1-8b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'

# Through LiteLLM gateway
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-CHANGE-ME-IN-PRODUCTION" \
  -d '{
    "model": "llama-3.1-8b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

## Configuration Variants

To test different models or features, modify the ConfigMap:

```bash
# Switch to quantized model
kubectl patch configmap vllm-config -n inference \
  --type merge -p '{"data":{"QUANTIZATION":"awq","MODEL_ID":"TheBloke/Llama-2-7B-Chat-AWQ"}}'

# Enable speculative decoding
kubectl patch configmap vllm-config -n inference \
  --type merge -p '{"data":{"SPECULATIVE_MODEL":"meta-llama/Llama-3.2-1B"}}'

# Then restart the deployment
kubectl rollout restart deployment/vllm-inference -n inference
```

## Metrics

vLLM exposes Prometheus metrics at `/metrics`:
- `vllm:num_requests_running` — active requests
- `vllm:num_requests_waiting` — queued requests
- `vllm:gpu_cache_usage_perc` — KV cache utilization
- `vllm:avg_generation_throughput_toks_per_s` — token throughput
- `vllm:e2e_request_latency_seconds` — end-to-end latency

LiteLLM exposes metrics at `:4000/metrics`:
- Request counts, latency histograms, error rates per model
