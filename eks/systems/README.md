# EKS Systems

Platform services deployed on top of the base EKS cluster. Each system is an independent Terraform root with its own state, enabling isolated iteration cycles.

## Structure

```
systems/
├── inference/          # Tiered inference platform (routing, engines, serving)
├── training/           # Batch training (schedulers, distributed compute)
├── agents/             # Agent runtime (state, durable execution, tools)
└── ai/                 # [DEPRECATED] Original monolithic layout — use above
```

## Dependency Graph

```
                    ┌──────────────┐
                    │  base cluster │  (eks/quick-cluster/base)
                    └──────┬───────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
    ┌───────▼──────┐  ┌───▼────┐  ┌──────▼──────┐
    │  inference   │  │training│  │   agents    │
    │              │  │        │  │             │
    │ Tier1: GW    │  │Volcano │  │ Redis       │
    │ Tier2: vLLM  │  │KubeRay │  │ Temporal    │
    │ Tier3: Serve │  │Flyte   │  │ MCP Gateway │
    └──────────────┘  └────────┘  └─────────────┘
            │                              │
            └──────────── apps ────────────┘
                     (app/ layer)
```

## Design Principles

1. **Independent state** — Each system has its own `terraform.tfstate`. Apply inference without touching training.
2. **Toggle-driven** — Every component is behind a `enable_*` boolean. Start minimal, add components as needed.
3. **Data source coupling** — Systems read cluster info via `data.aws_eks_cluster` (cluster name only). No hard state references between roots.
4. **Version pinned** — All Helm charts pinned with override variables per environment.
5. **Shared dependencies** — NVIDIA GPU Operator is needed by both inference and training. Only install from one (default: inference owns it, training disables it if sharing a cluster).

## Usage

```bash
# Deploy inference platform
cd inference && terraform init && terraform apply -var-file=dev.tfvars

# Deploy training platform
cd training && terraform init && terraform apply -var-file=dev.tfvars

# Deploy agent infrastructure
cd agents && terraform init && terraform apply -var-file=dev.tfvars
```

## Change Velocity

| System | Typical Change Cadence | Reason |
|--------|----------------------|--------|
| inference | Days/weeks | Gateway policy, engine upgrades, new models |
| training | Weeks/months | Stable once scheduler + orchestrator are set |
| agents | Days | New tool servers, state schema changes |
