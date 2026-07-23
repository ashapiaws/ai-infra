# Simple Inference - Chat Web UI

A lightweight OpenAI-compatible chat application (Python/FastAPI) that routes through Envoy AI Gateway to vLLM model endpoints.

## Architecture

```
┌─────────────┐      ┌───────────────────┐      ┌──────────────────┐
│  Chat Web   │ ───► │  Envoy AI Gateway │ ───► │  vLLM (model-a)  │
│  (FastAPI)  │      │  /v1/chat/...     │      └──────────────────┘
└─────────────┘      │                   │      ┌──────────────────┐
                     │  Routes by model   │ ───► │  vLLM (model-b)  │
                     └───────────────────┘      └──────────────────┘
```

## Features

- OpenAI-compatible chat completions (streaming via SSE)
- Model selector (model-a, model-b)
- Real-time streaming responses
- Auto-discovers models from the gateway
- Dark theme UI

## Local Development

```bash
pip install -r requirements.txt
uvicorn app:app --reload --port 3000
```

Set `GATEWAY_URL` to point at your gateway endpoint:

```bash
GATEWAY_URL=http://localhost:8080 uvicorn app:app --reload --port 3000
```

## Kubernetes Deployment

```bash
# Build and push the image
docker build -t chat-ui:latest .

# Deploy
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/gateway-route.yaml
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GATEWAY_URL` | `http://envoy-ai-gateway.envoy-ai-gateway.svc.cluster.local:8080` | Envoy AI Gateway endpoint |

## Request Flow

1. User picks `model-a` or `model-b` in the dropdown and sends a message
2. Frontend POSTs to `/api/chat` with the selected model name
3. FastAPI proxies to `GATEWAY_URL/v1/chat/completions` (OpenAI format)
4. Envoy AI Gateway routes to the correct vLLM instance based on model name
5. Streaming tokens flow back through SSE to the UI
