# Envoy Gateway System

Standalone Envoy deployment for customizable L7 routing, traffic management, and multi-cluster connectivity. This is separate from the inference-tier Envoy AI Gateway — it provides a general-purpose programmable proxy layer.

## Purpose

- Central ingress/egress routing for the platform
- Custom Envoy configuration (filters, clusters, listeners)
- Foundation for hub-and-spoke multi-cluster routing
- Service mesh lite (no full Istio sidecar injection)

## Architecture

```
                    ┌─────────────────────────────┐
                    │        Hub Cluster           │
                    │                              │
                    │   ┌──────────────────────┐   │
  Clients ────────▶│   │   Envoy Gateway      │   │
                    │   │   (this module)       │   │
                    │   └──────┬───────────────┘   │
                    │          │                    │
                    └──────────┼────────────────────┘
                               │
               ┌───────────────┼───────────────┐
               │               │               │
       ┌───────▼──────┐ ┌─────▼──────┐ ┌──────▼──────┐
       │ Spoke: Infer  │ │ Spoke: Train│ │ Spoke: Agent│
       │ (vLLM/SGLang) │ │ (Ray/Flyte) │ │ (Temporal)  │
       └───────────────┘ └────────────┘ └─────────────┘
```

## Structure

```
envoy/
├── main.tf              # Root module — Envoy + bootstrap config
├── variables.tf         # Inputs (cluster, envoy version, listeners)
├── outputs.tf           # Gateway endpoint, admin URL
├── versions.tf          # Provider constraints
├── dev.tfvars           # Dev environment values
├── manifests/           # Raw K8s manifests for custom Envoy config
│   ├── namespace.yaml
│   ├── envoy-configmap.yaml
│   ├── envoy-deployment.yaml
│   └── envoy-service.yaml
└── backlog.md           # Scaling roadmap (hub → spoke routing)
```

## Usage

```bash
cd eks/systems/envoy
terraform init
terraform apply -var-file=dev.tfvars
```

## Customization

The Envoy config is fully exposed via a ConfigMap (`manifests/envoy-configmap.yaml`). Edit listeners, clusters, routes, and filters directly. The Terraform wrapper deploys the manifests and manages the lifecycle.

For more advanced scenarios (xDS, ADS), see the backlog for dynamic configuration evolution.
