# Ops Layer - DevOps Agent + Structured Operations

This layer defines a repeatable, token-efficient operations framework for AI-powered DevOps agents.

## Core Philosophy

1. **Deterministic First** — Log queries and metric retrieval use pre-defined, parameterized templates (no LLM-generated queries)
2. **Grounded Validation** — Agent outputs are always validated against actual CloudWatch data
3. **Token Efficiency** — Pre-filter and summarize data before feeding to LLM; only send what's actionable
4. **Repeatable Format** — Every operation follows a versioned schema that can be audited and replayed

## Directory Structure

```
ops/
├── agent/                    # DevOps Agent configuration
│   ├── config.yaml           # Agent behavior and tool bindings
│   └── prompts/              # System prompts for agent modes
├── log-query/                # Deterministic log query templates
│   ├── templates/            # Parameterized CloudWatch Insights queries
│   ├── runner.py             # Query executor with caching
│   └── filters.py            # Pre-processing filters
├── mcp-servers/              # MCP Server definitions and recommendations
│   ├── README.md             # Server inventory + rationale
│   ├── cloudwatch-metrics/   # CW Metrics MCP
│   ├── log-insights/         # CW Log Insights MCP
│   └── k8s-resources/        # Kubernetes resource MCP
└── operations-format/        # Structured operation definitions
    ├── schema.json           # Operation format schema (v1)
    ├── examples/             # Example operations
    └── README.md             # Format specification
```

## Data Flow

```
CloudWatch Logs/Metrics
        │
        ▼ (deterministic query templates)
┌──────────────────┐
│  Query Runner    │  ← Parameterized, cached, filtered
└──────────────────┘
        │
        ▼ (structured JSON)
┌──────────────────┐
│  Pre-Processor   │  ← Summarize, deduplicate, rank
└──────────────────┘
        │
        ▼ (minimal, actionable context)
┌──────────────────┐
│  DevOps Agent    │  ← LLM with tool bindings (MCP)
└──────────────────┘
        │
        ▼ (structured operation)
┌──────────────────┐
│  Operation Log   │  ← Versioned, auditable, replayable
└──────────────────┘
```

## Agent Benchmark: Naive vs Structured

The `agent/benchmark/` directory contains a full comparison framework:

### Approach A: Naive Agent (One-Shot)
- Dumps ALL logs, metrics, and K8s state into a single prompt
- No pre-filtering, no deduplication, no structured output
- Represents typical "ask the LLM to figure it out" approach
- Typically uses 5,000-15,000 input tokens per diagnosis

### Approach B: Structured Agent (Deterministic + LLM)
- Runs only relevant query templates based on trigger type
- Pre-processes data (dedup, filter, truncate) before LLM
- Enforces structured output (Operations Format)
- Typically uses 1,500-3,000 input tokens per diagnosis

### Test Domains

| Domain | Measurement | Why It Matters |
|--------|-------------|---------------|
| **Time** | End-to-end latency | Faster diagnosis = faster MTTR |
| **Accuracy** | Root cause match against ground truth | Wrong diagnosis wastes time |
| **Correlation** | Causal chain depth | Deep correlation = preventive action |

### Running the Benchmark

```bash
# Option 1: With live cluster
cd agent/benchmark/
python scenarios/inject.py --scenario oom-cascade
python runner.py --scenario oom-cascade --model anthropic.claude-3-sonnet

# Option 2: With synthetic data (no cluster needed)
python runner.py --scenario oom-cascade --dry-run

# Evaluate results
python evaluate.py --scenario oom-cascade
python evaluate.py --scenario all --format json
```

### 5 Failure Scenarios
1. OOMKill Cascade (memory → crash → downstream errors)
2. CPU Throttling (load → latency → no errors)
3. Disk Pressure (PVC full → write failures)
4. DNS Failure (CoreDNS → intermittent 503s)
5. Restart Loop (probe misconfiguration → full outage)

---

## Getting Started

1. Configure your cluster credentials:
   ```bash
   aws eks update-kubeconfig --name aiops-test-cluster --region us-west-2
   ```

2. Set up the log query templates:
   ```bash
   cd log-query/
   python runner.py --template error-summary --cluster aiops-test-cluster
   ```

3. Review MCP server recommendations in `mcp-servers/README.md`

4. Run agent benchmark (synthetic mode):
   ```bash
   cd agent/benchmark/
   python runner.py --scenario all --dry-run
   python evaluate.py --scenario all
   ```
