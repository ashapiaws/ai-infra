# Training — Network Topology Testing

## Overview

Launch a 3-node distributed training cluster on SageMaker HyperPod to measure the throughput impact of same-spine vs cross-spine node placement using topology-aware scheduling.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Spine Switch (Same Spine)                     │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Leaf Switch   │   Leaf Switch   │        Leaf Switch          │
│       │         │       │         │            │                │
│   ┌───┴───┐     │   ┌───┴───┐    │   ┌────────┴────────┐      │
│   │Node 0 │     │   │Node 1 │    │   │     Node 2      │      │
│   │(Rank 0)│    │   │(Rank 1)│   │   │    (Rank 2)     │      │
│   └───────┘     │   └───────┘    │   └─────────────────┘      │
└─────────────────┴─────────────────┴─────────────────────────────┘

Same Spine: All 3 nodes under same spine → 1 hop for all-reduce
Cross Spine: Nodes under different spines → 2+ hops for all-reduce
```

## Design Choices

### Why 3 Nodes?

- Minimum cluster size that exercises real all-reduce patterns (ring/tree topologies)
- Small enough to isolate topology effects without confounding variables
- Represents a realistic unit of a larger training job partition

### Distributed Strategy: Data Parallel (DDP)

- PyTorch DistributedDataParallel for straightforward gradient synchronization
- All-reduce is the dominant collective — directly sensitive to network topology
- Each node holds a full model replica; gradients are synchronized after each step
- Clear throughput signal: samples processed per second scales with communication efficiency

### Model Selection

Using a medium-sized model (e.g., GPT-2 1.5B or ResNet-152) that:
- Generates meaningful gradient traffic (not trivially small)
- Fits in a single GPU's memory (isolates communication from memory pressure)
- Has well-understood training characteristics for baseline comparison

### Topology-Aware Scheduling

SageMaker HyperPod exposes topology labels on nodes:
- `sagemaker.amazonaws.com/node-health-status`
- `topology.kubernetes.io/zone`
- Custom spine/leaf annotations via HyperPod topology discovery

**Same Spine Deployment:**
```yaml
affinity:
  podAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: training-topology-test
        topologyKey: "topology.hyperpod.amazonaws.com/spine"
```

**Cross Spine Deployment:**
```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: training-topology-test
        topologyKey: "topology.hyperpod.amazonaws.com/spine"
```

### Communication Backend

- NCCL over EFA for GPU-to-GPU communication
- EFA provides consistent low-latency RDMA — topology differences become the variable
- NCCL environment tuned for topology awareness:
  ```
  NCCL_ALGO=Ring
  NCCL_PROTO=Simple
  NCCL_TOPO_FILE=/opt/aws/topology.xml
  FI_EFA_USE_DEVICE_RDMA=1
  ```

## Metrics

### Primary: Training Throughput

| Metric | Description | Collection Method |
|--------|-------------|-------------------|
| `samples_per_second` | Global throughput across all 3 nodes | PyTorch callback / custom logger |
| `step_time_ms` | Time per training step (forward + backward + sync) | Timer around `optimizer.step()` |
| `communication_time_ms` | Time spent in all-reduce per step | NCCL profiling / `torch.cuda.Event` |
| `computation_time_ms` | Time in forward + backward (excluding sync) | Derived: step_time - comm_time |
| `comm_compute_ratio` | Communication overhead relative to compute | Derived ratio |

### Secondary: Network-Level

| Metric | Description | Collection Method |
|--------|-------------|-------------------|
| `efa_tx_bytes` | EFA transmitted bytes per second | CloudWatch EFA metrics |
| `efa_rx_bytes` | EFA received bytes per second | CloudWatch EFA metrics |
| `nccl_allreduce_latency_us` | Per-operation all-reduce latency | NCCL debug logs |
| `gpu_utilization_pct` | GPU compute utilization (higher = less comm stall) | `nvidia-smi` / DCGM |
| `memory_bandwidth_utilization` | HBM bandwidth usage | DCGM metrics |

### Expected Results

| Scenario | Expected Throughput Impact | Reasoning |
|----------|---------------------------|-----------|
| Same Spine | Baseline (higher) | Single hop between leaf switches, lower latency all-reduce |
| Cross Spine | 5-20% lower | Multi-hop through spine switches adds latency to each all-reduce |

The degradation magnitude depends on:
- Model size (larger gradients → more time in communication → larger penalty)
- Batch size (larger batches → more compute per step → smaller relative penalty)
- Network congestion on spine links

## Implementation Plan

### Phase 1: Baseline Setup
1. Deploy HyperPod cluster with topology labels verified
2. Create training container with PyTorch DDP, NCCL, EFA drivers
3. Validate single-node training runs correctly

### Phase 2: Same Spine Test
1. Deploy 3-node training job with spine affinity
2. Verify all nodes are on same spine (check node labels)
3. Run training for N steps (e.g., 1000) and collect metrics
4. Repeat 3x for statistical significance

### Phase 3: Cross Spine Test
1. Deploy 3-node training job with spine anti-affinity
2. Verify nodes span different spines
3. Run identical training config for N steps
4. Repeat 3x for statistical significance

### Phase 4: Analysis
1. Compare throughput distributions (same vs cross spine)
2. Break down step time into compute vs communication
3. Correlate with EFA-level metrics
4. Produce report with confidence intervals

## File Structure (Planned)

```
training/
├── README.md                    # This file
├── Dockerfile                   # Training container with PyTorch + NCCL + EFA
├── train.py                     # DDP training script with metric collection
├── config/
│   ├── same-spine.yaml          # K8s manifest with spine affinity
│   ├── cross-spine.yaml         # K8s manifest with spine anti-affinity
│   └── training-config.yaml     # Hyperparameters and model config
├── metrics/
│   ├── collector.py             # Custom metric collection and export
│   └── dashboard.json           # Grafana dashboard for live monitoring
└── analysis/
    ├── compare.py               # Post-run comparison script
    └── report_template.md       # Results report template
```

## Success Criteria

- [ ] Both deployments (same/cross spine) run to completion without errors
- [ ] Throughput difference is measurable and statistically significant (p < 0.05)
- [ ] Communication time breakdown clearly shows topology impact
- [ ] Metrics are reproducible across multiple runs
- [ ] Results inform production topology scheduling decisions
