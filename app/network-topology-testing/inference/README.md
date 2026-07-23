# Inference — Network Topology Testing

## Overview

Launch a 3-node inference backend on SageMaker HyperPod to measure the latency impact of same-spine vs cross-spine node placement across three parallelism strategies: data parallelism, pipeline parallelism, and expert parallelism (MoE).

## Architecture

### Data Parallelism (DP)

```
                    ┌──────────────┐
                    │  Load Balancer│
                    └──────┬───────┘
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  Node 0  │ │  Node 1  │ │  Node 2  │
        │ Full Model│ │ Full Model│ │ Full Model│
        │ Replica  │ │ Replica  │ │ Replica  │
        └──────────┘ └──────────┘ └──────────┘

Each node serves independently. Cross-node traffic: KV-cache sync (if prefix caching shared).
Topology impact: Low for independent requests, higher for shared prefix scenarios.
```

### Pipeline Parallelism (PP)

```
        Request ──► ┌──────────┐    ┌──────────┐    ┌──────────┐ ──► Response
                    │  Node 0  │───►│  Node 1  │───►│  Node 2  │
                    │ Layers   │    │ Layers   │    │ Layers   │
                    │  0-10    │    │  11-21   │    │  22-32   │
                    └──────────┘    └──────────┘    └──────────┘

Sequential activation flow. Each token generation requires full pipeline traverse.
Topology impact: HIGH — latency is additive across each hop.
```

### Expert Parallelism (EP / MoE)

```
                    ┌──────────────┐
                    │   Router     │
                    │  (All Nodes) │
                    └──────┬───────┘
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  Node 0  │ │  Node 1  │ │  Node 2  │
        │Experts 0-5│ │Experts 6-11│ │Experts 12-15│
        │+ Shared  │ │+ Shared  │ │+ Shared  │
        └──────────┘ └──────────┘ └──────────┘
              ▲            ▲            ▲
              └────────────┼────────────┘
                    All-to-All Communication

Token routing to experts requires all-to-all collectives every layer.
Topology impact: HIGH — all-to-all is the most topology-sensitive collective.
```

## Design Choices

### Why 3 Nodes?

- Minimum to exercise all three parallelism patterns meaningfully
- Pipeline parallelism with 3 stages shows clear per-hop latency contribution
- Expert parallelism with 3 nodes demonstrates realistic all-to-all patterns
- Data parallelism with 3 replicas shows load distribution and optional sync patterns

### Parallelism Strategy Selection

| Strategy | Why Test It | Topology Sensitivity |
|----------|-------------|---------------------|
| Data Parallel | Baseline — minimal cross-node traffic per request | Low (independent serving) |
| Pipeline Parallel | Sequential dependency — latency directly proportional to hop count | High (serial communication) |
| Expert Parallel (MoE) | All-to-all every layer — maximum collective sensitivity | Very High (all-to-all pattern) |

### Model Selection Per Strategy

**Data Parallel:** Llama 2 7B (or similar) — fits single GPU, standard serving characteristics

**Pipeline Parallel:** Llama 2 70B (or larger) — requires model partitioning across nodes, realistic PP use case

**Expert Parallel:** Mixtral 8x7B — native MoE architecture with expert routing, authentic EP workload

### Serving Framework: vLLM

- Native support for all three parallelism strategies
- PagedAttention for efficient KV-cache management
- Built-in metrics (TTFT, TPOT, throughput)
- Mature distributed inference with Ray backend
- Consistent framework across all tests eliminates confounding variables

### Topology-Aware Scheduling

**Same Spine Deployment:**
```yaml
affinity:
  podAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: inference-topology-test
            strategy: pipeline-parallel  # or data-parallel, expert-parallel
        topologyKey: "topology.hyperpod.amazonaws.com/spine"
```

**Cross Spine Deployment:**
```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: inference-topology-test
            strategy: pipeline-parallel
        topologyKey: "topology.hyperpod.amazonaws.com/spine"
```

### Communication Configuration

```bash
# NCCL for inter-node GPU communication
NCCL_ALGO=Ring              # Ring for PP, Tree for EP all-to-all
NCCL_PROTO=Simple
FI_EFA_USE_DEVICE_RDMA=1
NCCL_TOPO_FILE=/opt/aws/topology.xml

# vLLM distributed config
VLLM_DISTRIBUTED_BACKEND=nccl
RAY_DEDUP_LOGS=0
```

## Metrics

### Primary: Inference Latency

| Metric | Description | Collection Method |
|--------|-------------|-------------------|
| `ttft_ms` | Time to First Token (prompt processing latency) | vLLM metrics endpoint |
| `tpot_ms` | Time Per Output Token (decode latency) | vLLM metrics endpoint |
| `e2e_latency_ms` | End-to-end request latency | Client-side measurement |
| `p50_latency_ms` | Median latency | Percentile aggregation |
| `p95_latency_ms` | 95th percentile latency | Percentile aggregation |
| `p99_latency_ms` | 99th percentile latency (tail) | Percentile aggregation |
| `itl_ms` | Inter-token latency (token streaming) | Client-side token timing |

### Secondary: Throughput Under Load

| Metric | Description | Collection Method |
|--------|-------------|-------------------|
| `tokens_per_second` | Total output token throughput | vLLM metrics |
| `requests_per_second` | Request serving rate at target latency | Load test client |
| `queue_depth` | Pending request count | vLLM scheduler metrics |
| `batch_size_running` | Active batch size during continuous batching | vLLM metrics |
| `gpu_kv_cache_usage_pct` | KV-cache memory utilization | vLLM metrics |

### Tertiary: Network-Level

| Metric | Description | Collection Method |
|--------|-------------|-------------------|
| `efa_tx_bytes` | EFA transmitted bytes per second | CloudWatch / node_exporter |
| `efa_rx_bytes` | EFA received bytes per second | CloudWatch / node_exporter |
| `nccl_send_latency_us` | Point-to-point send latency (PP pipeline stages) | NCCL profiling |
| `nccl_alltoall_latency_us` | All-to-all latency (EP expert routing) | NCCL profiling |
| `gpu_utilization_pct` | GPU SM utilization | DCGM / nvidia-smi |
| `gpu_memory_used_pct` | GPU memory pressure | DCGM |

### Expected Results

| Strategy | Topology | Expected Latency Impact | Reasoning |
|----------|----------|------------------------|-----------|
| Data Parallel | Same Spine | Baseline | Requests served independently, minimal cross-node traffic |
| Data Parallel | Cross Spine | ~Same as baseline | Independent replicas, topology irrelevant per-request |
| Pipeline Parallel | Same Spine | Baseline | Activation transfers between stages are fast (1 hop) |
| Pipeline Parallel | Cross Spine | **15-40% higher TPOT** | Each token decode traverses full pipeline; each stage-to-stage hop adds latency |
| Expert Parallel | Same Spine | Baseline | All-to-all within spine is efficient |
| Expert Parallel | Cross Spine | **20-50% higher TPOT** | All-to-all crosses spine boundary every MoE layer; most sensitive to topology |

**Key Insight:** Data parallelism should show negligible topology impact (validating our test methodology), while pipeline and expert parallelism should show clear degradation — with EP being the worst case due to all-to-all patterns at every MoE layer.

## Load Testing Approach

### Tool: Custom client or `genai-perf` / `llmperf`

```
Load Profiles:
├── Low concurrency:    1 req/s  — isolate per-request latency
├── Medium concurrency: 10 req/s — realistic serving load
└── High concurrency:   50 req/s — stress test with queuing
```

### Request Parameters
- Input length: 128, 512, 2048 tokens (short, medium, long context)
- Output length: 128, 512 tokens
- Streaming enabled for ITL measurement

## Implementation Plan

### Phase 1: Framework Setup
1. Build vLLM container with EFA + NCCL + Ray support
2. Validate single-node inference serving
3. Configure metrics collection (Prometheus + Grafana)

### Phase 2: Data Parallel Test
1. Deploy 3 independent vLLM replicas with load balancer
2. Run same-spine and cross-spine variants
3. Load test at all concurrency levels
4. Collect latency distributions (expect minimal difference — validates methodology)

### Phase 3: Pipeline Parallel Test
1. Deploy vLLM with `--tensor-parallel-size 1 --pipeline-parallel-size 3`
2. Run same-spine placement, collect metrics
3. Run cross-spine placement, collect metrics
4. Compare TTFT and TPOT distributions

### Phase 4: Expert Parallel Test
1. Deploy Mixtral with `--tensor-parallel-size 1 --expert-parallel-size 3`
2. Run same-spine placement, collect metrics
3. Run cross-spine placement, collect metrics
4. Analyze per-layer expert routing latency

### Phase 5: Analysis & Report
1. Statistical comparison across all scenarios
2. Latency distribution plots (histograms, CDFs)
3. Identify crossover points (at what load does topology start to matter?)
4. Production recommendations for scheduling policies

## File Structure (Planned)

```
inference/
├── README.md                        # This file
├── Dockerfile                       # vLLM + EFA + NCCL inference container
├── config/
│   ├── data-parallel/
│   │   ├── same-spine.yaml          # 3 independent replicas, spine affinity
│   │   └── cross-spine.yaml         # 3 independent replicas, spine anti-affinity
│   ├── pipeline-parallel/
│   │   ├── same-spine.yaml          # PP=3 deployment, spine affinity
│   │   └── cross-spine.yaml         # PP=3 deployment, spine anti-affinity
│   └── expert-parallel/
│       ├── same-spine.yaml          # EP=3 MoE deployment, spine affinity
│       └── cross-spine.yaml         # EP=3 MoE deployment, spine anti-affinity
├── load-test/
│   ├── client.py                    # Custom load generator with latency tracking
│   ├── profiles/                    # Load profiles (low/med/high concurrency)
│   └── analyze.py                   # Results aggregation and comparison
├── metrics/
│   ├── prometheus-config.yaml       # Scrape targets for vLLM + node metrics
│   └── grafana-dashboard.json       # Real-time latency monitoring
└── analysis/
    ├── compare.py                   # Cross-topology statistical comparison
    ├── plots.py                     # Latency distribution visualizations
    └── report_template.md           # Final results report
```

## Success Criteria

- [ ] Data parallel shows <5% latency difference (validates test isolation)
- [ ] Pipeline parallel shows measurable per-hop latency addition cross-spine
- [ ] Expert parallel shows highest topology sensitivity (all-to-all pattern)
- [ ] Results are reproducible (3+ runs per configuration, overlapping CIs)
- [ ] Clear production recommendation: when to enforce topology constraints
- [ ] Identified throughput/latency tradeoff for each parallelism strategy
