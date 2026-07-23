# Training Platform

Batch training infrastructure for distributed model training, fine-tuning, and ML pipeline orchestration.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                     Training Platform                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  GPU Infrastructure                                                │
│  ┌─────────────────────┐                                          │
│  │  NVIDIA GPU Operator │                                          │
│  └──────────┬──────────┘                                          │
│             │                                                      │
│  Scheduling & Orchestration                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                        │
│  │ Volcano  │  │ KubeRay  │  │  Flyte   │                        │
│  │ (gang    │  │ (distrib │  │ (workflow │                        │
│  │  sched)  │  │  compute)│  │  orch)   │                        │
│  └──────────┘  └──────────┘  └──────────┘                        │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Purpose |
|-----------|---------|
| NVIDIA GPU Operator | GPU drivers, runtime, device plugin |
| Volcano | Gang scheduling for multi-node training jobs |
| KubeRay | Distributed Ray clusters (data parallel, model parallel) |
| Flyte | ML pipeline DAGs, experiment tracking |

## Usage

```bash
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Notes

- NVIDIA GPU Operator is a shared dependency with the inference platform. If both
  inference and training deploy to the same cluster, only one should install it
  (coordinate via the `enable_nvidia_operator` toggle).
- Volcano provides gang scheduling needed for multi-node training (all pods start
  together or none do).
- KubeRay manages Ray clusters for distributed training via RayJob CRDs.
