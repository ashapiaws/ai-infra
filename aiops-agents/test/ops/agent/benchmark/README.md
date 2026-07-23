# DevOps Agent Benchmark: Naive vs Structured Operations

## Purpose

Compare two approaches to DevOps Agent operations:

1. **Naive Agent** — General one-shot prompting, raw data dump, no structure
2. **Structured Agent** — Deterministic queries, pre-processed data, Operations Format

## Test Domains

| Domain | What We Measure |
|--------|----------------|
| **Time** | End-to-end latency from trigger to actionable output |
| **Accuracy** | Correct identification of root cause (precision/recall against known issues) |
| **Root Cause Correlation** | Depth of causal chain, correct linkage between symptoms and causes |

## Test Methodology

We inject known failure scenarios into the cluster and measure how each agent approach diagnoses them.

### Scenarios

1. **OOMKill Cascade** — PostgreSQL runs out of memory → frontend connection errors
2. **CPU Throttling** — Pod hits CPU limit → request latency spikes
3. **Disk Pressure** — PVC fills up → database write failures → app errors
4. **Network Partition** — DNS resolution failures → intermittent 503s
5. **Cascading Restart** — Readiness probe misconfiguration → rolling restart loop

### Scoring Rubric

Each scenario is scored 0-10 on:

- **Time to Diagnosis (TTD)**: How fast the agent produces a root cause (lower = better)
- **Root Cause Accuracy (RCA)**: Did it identify the actual root cause? (binary + partial credit)
- **Correlation Depth (CD)**: How many causal links were correctly identified?
- **False Positives (FP)**: Incorrect claims about the system state
- **Evidence Grounding (EG)**: Are claims backed by actual data references?
- **Token Efficiency (TE)**: Input + output tokens consumed

## Running Benchmarks

```bash
# Inject a scenario
python scenarios/inject.py --scenario oom-cascade

# Run both agents against same data
python runner.py --mode naive --scenario oom-cascade
python runner.py --mode structured --scenario oom-cascade

# Compare results
python evaluate.py --scenario oom-cascade
```
