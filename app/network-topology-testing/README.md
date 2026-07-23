# Network Topology Testing — SageMaker HyperPod

This project validates the performance impact of network topology-aware scheduling on SageMaker HyperPod clusters for both training and inference workloads.

## Objective

Quantify the latency and throughput differences between **same-spine** and **cross-spine** node placements when running distributed ML workloads. This provides empirical evidence for topology-aware scheduling decisions in production HyperPod deployments.

## Structure

```
network-topology-testing/
├── training/          # 3-node distributed training with topology-aware scheduling
├── inference/         # 3-node inference backend with multiple parallelism strategies
└── README.md          # This file
```

## Test Matrix

| Workload   | Topology        | Parallelism Strategy | Primary Metric     |
|------------|-----------------|----------------------|--------------------|
| Training   | Same Spine      | Data Parallel (DDP)  | Throughput (samples/sec) |
| Training   | Cross Spine     | Data Parallel (DDP)  | Throughput (samples/sec) |
| Inference  | Same Spine      | Data Parallel        | Latency (p50/p99)  |
| Inference  | Cross Spine     | Data Parallel        | Latency (p50/p99)  |
| Inference  | Same Spine      | Pipeline Parallel    | Latency (p50/p99)  |
| Inference  | Cross Spine     | Pipeline Parallel    | Latency (p50/p99)  |
| Inference  | Same Spine      | Expert Parallel (MoE)| Latency (p50/p99)  |
| Inference  | Cross Spine     | Expert Parallel (MoE)| Latency (p50/p99)  |

## Prerequisites

- SageMaker HyperPod cluster with topology-aware scheduling enabled
- EFA-enabled instances (p4d.24xlarge, p5.48xlarge, or trn1.32xlarge)
- Topology labels exposed via HyperPod node annotations
- CloudWatch or Prometheus metrics collection configured

## Approach

1. Deploy workloads with explicit topology constraints (same-spine affinity vs anti-affinity)
2. Run identical workloads under both topology conditions
3. Collect metrics over sustained periods to account for variance
4. Compare results to quantify topology impact on collective communication patterns
