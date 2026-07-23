# AIOps Agents - Test Environment

End-to-end test environment for validating AIOps agent capabilities against a real EKS cluster with observability stack.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        EKS Cluster                               │
│                                                                   │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────────┐   │
│  │ Frontend │───▶│  Redis   │    │  PostgreSQL (PVC/EBS)    │   │
│  │ (Flask)  │    │  Cache   │    │  - users table           │   │
│  └──────────┘    └──────────┘    │  - tasks table           │   │
│       │                           └──────────────────────────┘   │
│       └──────────────────────────────────────▲                   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Observability                                            │   │
│  │  - CloudWatch Container Insights                          │   │
│  │  - CloudWatch Logs (Fluent Bit)                          │   │
│  │  - Prometheus (optional)                                  │   │
│  │  - Grafana (optional)                                     │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Ops Layer                                     │
│                                                                   │
│  ┌──────────────┐   ┌────────────────┐   ┌──────────────────┐  │
│  │ DevOps Agent │◀──│ Log Querying   │◀──│ CloudWatch Logs   │  │
│  │              │   │ (Deterministic)│   │ OpenSearch (opt)  │  │
│  └──────────────┘   └────────────────┘   └──────────────────┘  │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  MCP Servers                                              │   │
│  │  - CloudWatch Metrics MCP                                 │   │
│  │  - Log Insights Query MCP                                 │   │
│  │  - K8s Resource MCP                                       │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
test/
├── infra/                    # Terraform - EKS + observability
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── eks.tf
│   ├── observability.tf
│   ├── ebs-csi.tf
│   ├── prometheus-grafana.tf
│   └── terraform.tfvars.example
├── app/                      # Kubernetes manifests
│   ├── namespace.yaml
│   ├── frontend/
│   ├── redis/
│   ├── database/
│   └── hydrate/
├── test/                     # Validation tests (Python)
│   ├── requirements.txt
│   ├── conftest.py
│   ├── test_cluster.py
│   ├── test_observability.py
│   ├── test_app.py
│   └── test_storage.py
└── ops/                      # DevOps Agent + Operations Format
    ├── README.md
    ├── agent/
    ├── log-query/
    ├── mcp-servers/
    └── operations-format/
```

## Quick Start

```bash
# 1. Stand up infrastructure
cd infra/
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 2. Deploy application stack
kubectl apply -f app/namespace.yaml
kubectl apply -f app/database/
kubectl apply -f app/redis/
kubectl apply -f app/frontend/
kubectl apply -f app/hydrate/

# 3. Run validation tests
cd test/
pip install -r requirements.txt
pytest -v

# 4. Set up ops layer
cd ops/
# Follow ops/README.md
```

## Design Principles

1. **Deterministic Operations** — Log querying and metric retrieval use pre-defined, parameterized queries (not LLM-generated) for consistency and token efficiency
2. **Grounded Validation** — All agent outputs are validated against actual CloudWatch metrics and logs
3. **Repeatable Format** — Operations follow a structured, versioned format that can be replayed
4. **Token Efficiency** — Minimize LLM token usage by pre-processing and filtering data before agent consumption
