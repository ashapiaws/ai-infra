# EFA & NCCL Baseline Validation

Pre-flight check to confirm EFA connectivity and NCCL collective operations work correctly before running topology training tests.

## What This Validates

1. **EFA Device Discovery** — All EFA interfaces are visible and operational on each node
2. **NCCL Initialization** — NCCL can establish connections between all nodes via EFA
3. **All-Reduce Baseline** — Measures raw all-reduce latency/bandwidth without training overhead
4. **Point-to-Point Bandwidth** — EFA send/recv bandwidth between node pairs

## Usage

```bash
# Deploy the validation job (2-node minimum, 3-node for full test)
kubectl apply -f job.yaml

# Watch logs
kubectl logs -f -l app=efa-nccl-validate -n topology-training

# Check results
kubectl logs job/efa-nccl-validate -n topology-training --all-containers
```

## Expected Output

- EFA devices listed (e.g., `rdmap0s6, rdmap16s6, rdmap32s6, rdmap48s6` for p4d)
- NCCL info logs showing EFA transport selection
- All-reduce bandwidth numbers (expect ~300-400 Gbps aggregate on p4d)
- Point-to-point bandwidth per EFA device (~25 Gbps per interface)
