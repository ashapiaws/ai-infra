# Operations Format Specification v1.0.0

## Purpose

Every operation performed by the DevOps Agent is recorded in this structured format. This provides:

1. **Auditability** — Every action has a clear chain of evidence
2. **Reproducibility** — Operations can be replayed with the same inputs
3. **Token Tracking** — Monitor and optimize LLM token usage over time
4. **Escalation Context** — When a human needs to intervene, they have full context

## Design Principles

### Deterministic Components (NOT LLM-generated)
- Query templates (CloudWatch Insights)
- Metric retrieval (pre-defined metric keys)
- Kubernetes resource reads
- Pre-processing filters

### LLM Components (Agent interprets)
- Correlating findings across data sources
- Severity ranking
- Recommendation generation
- Natural language summary

### Grounded Validation Rules
1. Every `observation` in `findings` MUST reference specific `evidence` (log line, metric value)
2. The agent MUST NOT state a metric value that wasn't retrieved via a tool call
3. `confidence` reflects data completeness: 1.0 = all relevant data available, 0.5 = partial data
4. Recommendations MUST be actionable and reference specific resources

## Operation Lifecycle

```
1. TRIGGER
   ├── Alert fires (CloudWatch Alarm)
   ├── Scheduled check (cron)
   └── Manual request (user)

2. DATA GATHERING (deterministic)
   ├── Run relevant log query templates
   ├── Fetch key metrics
   └── Read K8s resource state

3. PRE-PROCESSING (deterministic)
   ├── Deduplicate logs
   ├── Filter by severity
   ├── Truncate stack traces
   └── Aggregate into structured payload

4. ANALYSIS (LLM)
   ├── Correlate findings
   ├── Rank by severity
   └── Generate recommendations

5. ACTION (requires approval for writes)
   ├── Log operation in format
   ├── Execute auto-remediation (if approved)
   └── Escalate if confidence < threshold

6. RECORD
   └── Full operation stored as JSON
```

## Token Efficiency Strategy

| Stage | Token Cost | Strategy |
|-------|-----------|----------|
| Raw logs | High (5000+) | Pre-filter, dedup, truncate → ~500 tokens |
| Metrics | Medium (1000) | Return summary stats, not raw data points → ~100 tokens |
| K8s state | Medium (2000) | Only unhealthy resources → ~200 tokens |
| Agent output | Fixed budget | Enforce schema, max 1000 output tokens |

**Target:** Total context per operation < 2000 tokens (input to LLM)
