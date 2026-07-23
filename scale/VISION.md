# AI at Scale — Vision Document

## Mission

Build repeatable, production-grade patterns for Training and Inference workloads on Amazon EKS, enabling teams to operate large-scale AI systems with confidence across Operations, Optimization, Observability, and Scale.

## Stack

| Layer | Technology |
|-------|-----------|
| Orchestration | Amazon EKS |
| Inference | vLLM |
| Training | Ray |
| Framework | PyTorch |
| Compute | G-series instances (G5, G6, G6e) |

## Domains

1. **Operations** — Deployment patterns, lifecycle management, upgrades, rollbacks
2. **Optimization** — Latency (TTFT, TTFB), throughput, batching, quantization, disaggregated serving
3. **Observability** — Metrics, tracing, model health, SLO tracking
4. **Scale** — Autoscaling, multi-model serving, routing, capacity planning

## Current Phase: Inference

### Phase 1 — Foundation & Testing

#### Objectives

- Establish a repeatable base deployment pattern (EKS + vLLM + G instances)
- Explore model cold-start improvements
- Build disaggregated serving (prefill/decode split)
- Run evals and quantization experiments
- Optimize for TTFT, TTFB, latency, throughput
- Implement dynamic routing and batching

#### Testing Areas

| Area | Tests |
|------|-------|
| Cold Start | Linux file caching, NVMe+EFA pull from compute instances, FSx mount, S3 mount |
| Disaggregated Serving | Prefill/decode split — how and why |
| Evals & Quantization | Eval frameworks, quantization methods (AWQ, GPTQ, FP8), accuracy vs speed tradeoffs |
| Optimization | TTFT, TTFB, latency profiling, continuous batching, dynamic routing |

---

## Revision History

| Date | Change |
|------|--------|
| 2026-05-28 | Initial vision, Phase 1 scope defined |
