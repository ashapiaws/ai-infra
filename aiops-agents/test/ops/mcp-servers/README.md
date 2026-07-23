# MCP Servers - Recommendations & Implementation

## Architecture Decision: Deterministic + LLM Hybrid

The MCP servers below are designed with a **deterministic-first** approach:
- Tool inputs are parameterized templates (not free-form LLM queries)
- Outputs are structured JSON with consistent schemas
- The LLM interprets results, it doesn't generate the retrieval logic

This maximizes token efficiency and ensures grounded, reproducible outputs.

---

## Recommended MCP Servers

### 1. CloudWatch Metrics MCP Server

**Purpose:** Retrieve pre-defined metrics from Container Insights and custom namespaces.

**Key Tools:**
| Tool Name | Description | Input |
|-----------|-------------|-------|
| `get_metric_data` | Fetch metric data points for a time range | metric_name, namespace, dimensions, period, stat |
| `get_metric_anomalies` | Compare current values against baseline | metric_name, std_dev_threshold |
| `list_available_metrics` | Enumerate metrics for a cluster | namespace, dimension_filter |

**Design Principle:** No ad-hoc metric queries. All metrics are pre-defined in the agent config. The LLM selects which metric to check, not how to query it.

**Token Efficiency:** Returns pre-aggregated statistics (avg, p95, max) rather than raw data points. A 15-minute window at 1-min granularity = 15 data points vs. 900 for 1-second.

---

### 2. CloudWatch Log Insights MCP Server

**Purpose:** Execute parameterized log queries from version-controlled templates.

**Key Tools:**
| Tool Name | Description | Input |
|-----------|-------------|-------|
| `run_log_query` | Execute a named template query | template_name, parameters |
| `list_templates` | List available query templates | category_filter |
| `get_query_result` | Retrieve cached query result | query_id |

**Design Principle:** The LLM never writes CloudWatch Insights query syntax. It selects from pre-validated templates and provides parameters. This eliminates query syntax errors and ensures consistent output formats.

**Token Efficiency:** Results are pre-filtered and deduplicated (see `log-query/filters.py`). Stack traces are truncated. Only actionable entries are returned.

---

### 3. Kubernetes Resource MCP Server

**Purpose:** Read-only access to cluster state for diagnostics.

**Key Tools:**
| Tool Name | Description | Input |
|-----------|-------------|-------|
| `get_pod_status` | Get pod status with recent events | namespace, pod_name_pattern |
| `get_deployment_status` | Deployment rollout status | namespace, deployment_name |
| `list_events` | Recent K8s events filtered by type | namespace, event_type, time_range |
| `describe_resource` | Describe a specific resource | kind, namespace, name |

**Design Principle:** Read-only operations only. Write operations (scale, restart) require human approval and go through a separate approval workflow.

---

### 4. (Optional) OpenSearch MCP Server

**Purpose:** For environments with OpenSearch for log aggregation, provides indexed search capabilities.

**Key Tools:**
| Tool Name | Description | Input |
|-----------|-------------|-------|
| `search_logs` | Execute pre-defined search template | template_name, parameters |
| `get_aggregation` | Run pre-built aggregation queries | agg_template, time_range |

**When to Use:** When log volume exceeds CloudWatch cost thresholds, or when full-text search across historical data is needed.

---

## Integration Pattern

```
┌─────────────────────────────────────────┐
│            DevOps Agent (LLM)           │
│                                          │
│  "CPU is high on pod X, let me check    │
│   the error logs for that pod"          │
│                                          │
│  → Calls: run_log_query(                │
│      template="error-summary",          │
│      params={namespace: "aiops-app"}    │
│    )                                     │
│                                          │
│  → Calls: get_metric_data(              │
│      metric="pod_cpu_utilization",      │
│      dimensions={PodName: "X"}          │
│    )                                     │
└─────────────────────────────────────────┘
         │                    │
         ▼                    ▼
┌────────────────┐  ┌────────────────────┐
│ Log Insights   │  │ CloudWatch Metrics │
│ MCP Server     │  │ MCP Server         │
│                │  │                    │
│ (templates +   │  │ (pre-defined       │
│  filters +     │  │  metrics only)     │
│  caching)      │  │                    │
└────────────────┘  └────────────────────┘
```

## Configuration Example (mcp.json)

```json
{
  "mcpServers": {
    "cloudwatch-metrics": {
      "command": "python",
      "args": ["ops/mcp-servers/cloudwatch-metrics/server.py"],
      "env": {
        "AWS_REGION": "us-west-2",
        "CLUSTER_NAME": "aiops-test-cluster"
      }
    },
    "log-insights": {
      "command": "python",
      "args": ["ops/mcp-servers/log-insights/server.py"],
      "env": {
        "AWS_REGION": "us-west-2",
        "CLUSTER_NAME": "aiops-test-cluster",
        "TEMPLATES_DIR": "ops/log-query/templates"
      }
    },
    "k8s-resources": {
      "command": "python",
      "args": ["ops/mcp-servers/k8s-resources/server.py"],
      "env": {
        "KUBECONFIG": "~/.kube/config"
      }
    }
  }
}
```
