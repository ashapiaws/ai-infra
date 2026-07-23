# Phase 1 Testing Plan

## Test Area 1: Cold Start — Model Weight Loading

### Goal
Reduce time from pod scheduled → model ready to serve (currently 2-10 min depending on model size).

### Tests

| # | Strategy | How | Expected Benefit |
|---|----------|-----|-----------------|
| 1.1 | Linux page cache (baseline) | Pull from HuggingFace Hub on first boot, rely on node page cache for restarts | Baseline measurement |
| 1.2 | NVMe local storage | Pre-load model to instance NVMe SSD, mount as hostPath | Eliminate network pull on restart |
| 1.3 | NVMe + EFA cross-node pull | Use EFA-enabled compute instances as model cache, pull to G instances via NCCL/EFA | Fast distributed loading |
| 1.4 | FSx for Lustre | Mount FSx filesystem with model weights pre-staged from S3 | Shared, high-throughput parallel read |
| 1.5 | S3 Express One Zone | Mount via Mountpoint for S3, model stored in S3 Express | Low-latency object storage |
| 1.6 | S3 Standard + Mountpoint | Mount via Mountpoint for S3, standard tier | Cost-effective baseline |

### Metrics to Capture
- Time to first token (from pod creation)
- Model load time (vLLM logs)
- Network throughput during load
- Cost per load event

---

## Test Area 2: Disaggregated Serving

### Goal
Separate prefill (prompt processing) from decode (token generation) to optimize each independently.

### Why Split?
- **Prefill** is compute-bound (processes all input tokens in parallel) — benefits from high FLOPS
- **Decode** is memory-bandwidth-bound (generates one token at a time) — benefits from high memory bandwidth
- Splitting allows independent scaling and hardware optimization

### Tests

| # | Configuration | Description |
|---|--------------|-------------|
| 2.1 | Baseline (co-located) | Standard vLLM with prefill and decode on same GPU |
| 2.2 | vLLM disaggregated prefill | Use vLLM's built-in disaggregated prefill feature |
| 2.3 | Separate deployments | Prefill service → KV cache transfer → Decode service |

### Metrics
- TTFT (time to first token) — should improve with dedicated prefill
- Inter-token latency — should improve with dedicated decode
- Overall throughput under load
- GPU utilization per phase

---

## Test Area 3: Evals and Quantization

### Evals to Perform

| Eval | Tool | What It Measures |
|------|------|-----------------|
| MMLU | lm-eval-harness | General knowledge and reasoning |
| HumanEval | lm-eval-harness | Code generation accuracy |
| MT-Bench | FastChat | Multi-turn conversation quality |
| Perplexity | vLLM built-in | Language modeling quality |
| Latency under load | Custom benchmark | Real-world serving performance |

### Quantization Methods to Test

| Method | Bits | Approach | Expected Tradeoff |
|--------|------|----------|-------------------|
| FP16 (baseline) | 16 | No quantization | Best quality, most memory |
| AWQ | 4 | Activation-aware weight quantization | Good quality, 4x memory reduction |
| GPTQ | 4 | Post-training quantization | Similar to AWQ, different calibration |
| FP8 | 8 | Native FP8 on L40S/H100 | Minimal quality loss, 2x memory reduction |
| SqueezeLLM | 4 | Non-uniform quantization | Better quality at 4-bit |

### Test Matrix
For each model (8B, 70B):
- Run evals at FP16, AWQ-4bit, GPTQ-4bit, FP8
- Measure: accuracy delta, throughput gain, memory savings, latency change

---

## Test Area 4: Optimization

### Latency Targets

| Metric | Definition | Optimization Lever |
|--------|-----------|-------------------|
| TTFT | Time to first token | Chunked prefill, prefix caching, disaggregated prefill |
| TTFB | Time to first byte (network) | Connection pooling, HTTP/2, proximity |
| ITL | Inter-token latency | Decode optimization, speculative decoding |
| E2E | End-to-end request latency | All of the above + batching |

### Batching and Routing Tests

| # | Test | Description |
|---|------|-------------|
| 4.1 | Continuous batching baseline | vLLM default continuous batching |
| 4.2 | Max batch size tuning | Vary `--max-num-seqs` (64, 128, 256, 512) |
| 4.3 | Dynamic routing (least-busy) | LiteLLM routes to least loaded backend |
| 4.4 | Dynamic routing (latency-based) | LiteLLM routes based on P50 latency |
| 4.5 | Priority routing | Route by request priority (interactive vs batch) |
| 4.6 | Model-based routing | Route small prompts to 8B, complex to 70B |

### Tools
- **vLLM benchmarks**: `python -m vllm.entrypoints.openai.api_server --benchmark`
- **GenAI-Perf** (NVIDIA): Load testing for LLM endpoints
- **LiteLLM dashboard**: Built-in metrics and routing analytics
- **Custom scripts**: `testing/benchmarks/` directory

---

## Execution Order

1. Deploy base pattern (8B model, single GPU) ← **Start here**
2. Measure baseline cold start, TTFT, throughput
3. Run quantization comparison (FP16 vs AWQ vs FP8)
4. Test cold-start strategies (NVMe, FSx, S3)
5. Deploy 70B model, test tensor parallelism
6. Implement disaggregated serving
7. Tune batching and routing
8. Document accepted patterns
