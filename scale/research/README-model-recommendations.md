# Step 1: Model Recommendations for G-Series Instances

## Instance GPU Memory Summary

| Instance | GPU | Memory/GPU | Max GPUs | Total GPU Memory | NVMe | Network |
|----------|-----|-----------|----------|-----------------|------|---------|
| g5.xlarge–g5.48xlarge | NVIDIA A10G | 24 GB | 8 | 192 GB | Yes | Up to 100 Gbps |
| g6.xlarge–g6.48xlarge | NVIDIA L4 | 24 GB | 8 | 192 GB | Yes | Up to 100 Gbps |
| g6e.xlarge–g6e.48xlarge | NVIDIA L40S | 48 GB | 8 | 384 GB | Yes | Up to 400 Gbps |

## Recommended Models by Instance Size

### Single GPU (24 GB — g5.xlarge / g6.xlarge)

| Model | Parameters | VRAM Required | vLLM Features to Explore |
|-------|-----------|---------------|--------------------------|
| Mistral-7B-Instruct-v0.3 | 7B | ~14 GB FP16 | Continuous batching, prefix caching |
| Llama-3.1-8B-Instruct | 8B | ~16 GB FP16 | Speculative decoding, chunked prefill |
| Qwen2.5-7B-Instruct | 7B | ~14 GB FP16 | Tool calling, structured output |
| Gemma-2-9B-it | 9B | ~18 GB FP16 | Sliding window attention |
| Phi-3-medium-4k-instruct | 14B | ~14 GB (AWQ 4-bit) | Quantization comparison |

### Single GPU (48 GB — g6e.xlarge)

| Model | Parameters | VRAM Required | vLLM Features to Explore |
|-------|-----------|---------------|--------------------------|
| Llama-3.1-8B-Instruct | 8B | ~16 GB FP16 | Large KV cache, high concurrency |
| Mistral-Nemo-Instruct-2407 | 12B | ~24 GB FP16 | Long context (128k) |
| CodeLlama-34B-Instruct | 34B | ~34 GB (AWQ) | Code generation, FP8 quantization |
| Qwen2.5-32B-Instruct | 32B | ~34 GB (AWQ) | Structured output, function calling |

### Multi-GPU (2x A10G = 48 GB — g5.12xlarge / 2x L40S = 96 GB — g6e.12xlarge)

| Model | Parameters | VRAM Required | vLLM Features to Explore |
|-------|-----------|---------------|--------------------------|
| Llama-3.1-70B-Instruct | 70B | ~70 GB (AWQ) | Tensor parallelism, disaggregated prefill |
| Mixtral-8x7B-Instruct-v0.1 | 47B (MoE) | ~90 GB FP16 | MoE routing, expert parallelism |
| Qwen2.5-72B-Instruct | 72B | ~72 GB (AWQ) | Multi-step scheduling |

### Multi-GPU (4x L40S = 192 GB — g6e.24xlarge)

| Model | Parameters | VRAM Required | vLLM Features to Explore |
|-------|-----------|---------------|--------------------------|
| Llama-3.1-70B-Instruct | 70B | ~140 GB FP16 | Full precision, max throughput |
| DeepSeek-V2-Lite / DeepSeek-Coder-V2 | 16B/236B MoE | Varies | MoE, pipeline parallelism |
| Qwen2.5-72B-Instruct | 72B | ~144 GB FP16 | Full precision serving |

## Recommended Starting Point

**Primary model for learning vLLM features:** `meta-llama/Llama-3.1-8B-Instruct`

Rationale:
- Fits comfortably on a single 24 GB GPU with room for KV cache
- Excellent community support and benchmarks
- Supports all major vLLM features (speculative decoding, chunked prefill, prefix caching)
- Easy to compare FP16 vs AWQ vs GPTQ vs FP8 quantization
- Good baseline for disaggregated serving experiments

**Secondary model for scale testing:** `meta-llama/Llama-3.1-70B-Instruct`

Rationale:
- Requires tensor parallelism (multi-GPU) — exercises distributed serving
- Large enough to stress cold-start and model loading
- Good candidate for disaggregated prefill/decode
- Meaningful quantization tradeoffs at this scale

## vLLM Features to Exercise

| Feature | Description | Why It Matters |
|---------|-------------|----------------|
| Continuous Batching | Dynamic request batching | Maximizes GPU utilization |
| PagedAttention | Efficient KV cache management | Reduces memory waste |
| Prefix Caching | Cache common prompt prefixes | Reduces TTFT for repeated prefixes |
| Speculative Decoding | Draft model predicts tokens | Reduces latency for single requests |
| Chunked Prefill | Overlap prefill with decode | Improves TTFB under load |
| Tensor Parallelism | Split model across GPUs | Serve larger models |
| Quantization (AWQ/GPTQ/FP8) | Reduce model precision | Fit larger models, increase throughput |
| Structured Output | JSON schema enforcement | Production API reliability |
| Tool/Function Calling | OpenAI-compatible tool use | Agent workflows |
| Disaggregated Serving | Separate prefill and decode | Optimize each phase independently |
| Multi-step Scheduling | Schedule multiple decode steps | Reduce scheduling overhead |
