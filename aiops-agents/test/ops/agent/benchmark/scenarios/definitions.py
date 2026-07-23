"""
Scenario definitions — the ground truth for benchmarking.
Each scenario has:
- A failure injection method
- Expected root cause
- Expected causal chain (for correlation depth scoring)
- Relevant data sources (logs, metrics, k8s events)
"""

SCENARIOS = {
    "oom-cascade": {
        "name": "OOMKill Cascade",
        "description": "PostgreSQL pod exceeds memory limit, causing OOMKill. "
                       "Frontend loses DB connection, returning 500 errors to users.",
        "injection": {
            "type": "resource_pressure",
            "target": "postgres",
            "method": "Run memory-intensive query to exceed 512Mi limit",
        },
        "expected_root_cause": "PostgreSQL pod OOMKilled due to memory limit (512Mi) exceeded under query load",
        "expected_causal_chain": [
            "PostgreSQL memory usage exceeds 512Mi limit",
            "Kernel OOMKiller terminates PostgreSQL process (exit code 137)",
            "Pod enters CrashLoopBackOff",
            "Frontend psycopg2 connections fail (Connection refused)",
            "Frontend returns HTTP 500 to users",
            "Redis cache misses increase (sessions can't be refreshed)",
        ],
        "expected_findings": {
            "critical": ["postgres OOMKilled", "CrashLoopBackOff"],
            "warning": ["frontend connection errors", "elevated 5xx rate"],
            "info": ["redis cache miss increase"],
        },
        "relevant_data_sources": [
            "cloudwatch_logs:error-summary",
            "cloudwatch_logs:pod-restart-analysis",
            "cloudwatch_metrics:pod_memory_utilization",
            "kubernetes:pod_status",
            "kubernetes:events",
        ],
    },
    "cpu-throttle": {
        "name": "CPU Throttling",
        "description": "Frontend pod hits CPU limit under load. Request latency degrades "
                       "from p95=200ms to p95=2000ms. No errors, just slow responses.",
        "injection": {
            "type": "load_test",
            "target": "frontend",
            "method": "Generate 100 concurrent requests sustained for 5 minutes",
        },
        "expected_root_cause": "Frontend pod CPU throttled at 250m limit under sustained load",
        "expected_causal_chain": [
            "Concurrent request count exceeds pod CPU capacity",
            "CPU throttling kicks in (cpu.cfs_throttled_periods increases)",
            "Request processing time increases (gunicorn workers blocked)",
            "p95 latency rises from ~200ms to ~2000ms",
            "No errors generated — requests complete but slowly",
            "Health check probes still pass (timeout > latency)",
        ],
        "expected_findings": {
            "critical": [],
            "warning": ["CPU utilization at limit", "p95 latency elevated"],
            "info": ["no pod restarts", "health checks passing"],
        },
        "relevant_data_sources": [
            "cloudwatch_logs:latency-breakdown",
            "cloudwatch_metrics:pod_cpu_utilization",
            "cloudwatch_logs:error-summary",
            "kubernetes:pod_status",
        ],
    },
    "disk-pressure": {
        "name": "Disk Pressure",
        "description": "PostgreSQL PVC fills to capacity. Write operations fail. "
                       "Frontend can read cached data but new writes produce errors.",
        "injection": {
            "type": "storage_fill",
            "target": "postgres-pvc",
            "method": "Write large temp table until PVC is at 95%+",
        },
        "expected_root_cause": "PostgreSQL PVC (5Gi) at capacity — ENOSPC on write operations",
        "expected_causal_chain": [
            "PVC storage usage reaches 95%+",
            "PostgreSQL WAL writes fail with 'No space left on device'",
            "INSERT/UPDATE queries return errors",
            "Frontend login works (reads from cache) but new sessions fail",
            "Task updates fail silently (no write confirmation)",
        ],
        "expected_findings": {
            "critical": ["disk full", "write failures"],
            "warning": ["new session creation failing"],
            "info": ["reads still working via Redis cache"],
        },
        "relevant_data_sources": [
            "cloudwatch_logs:error-summary",
            "cloudwatch_metrics:pod_memory_utilization",
            "kubernetes:pod_status",
            "kubernetes:events",
        ],
    },
    "dns-failure": {
        "name": "DNS Resolution Failure",
        "description": "CoreDNS pod becomes degraded. Intermittent DNS resolution failures "
                       "cause sporadic 503 errors across all services.",
        "injection": {
            "type": "network",
            "target": "coredns",
            "method": "Scale CoreDNS to 0 replicas briefly, then restore with degraded config",
        },
        "expected_root_cause": "CoreDNS degradation causing intermittent DNS resolution failures",
        "expected_causal_chain": [
            "CoreDNS pods become unavailable or degraded",
            "Service-to-service DNS lookups fail intermittently",
            "Frontend cannot resolve 'postgres.aiops-app.svc.cluster.local'",
            "Frontend cannot resolve 'redis.aiops-app.svc.cluster.local'",
            "Intermittent 503 errors (some requests succeed, some fail)",
            "Pattern: errors are not correlated with load — random distribution",
        ],
        "expected_findings": {
            "critical": ["DNS resolution failures"],
            "warning": ["intermittent 503s", "connection timeouts"],
            "info": ["no resource pressure", "pods show Running status"],
        },
        "relevant_data_sources": [
            "cloudwatch_logs:error-summary",
            "kubernetes:pod_status",
            "kubernetes:events",
        ],
    },
    "restart-loop": {
        "name": "Cascading Restart Loop",
        "description": "Frontend readiness probe path changed, probe fails, pod gets restarted "
                       "repeatedly. Load balancer removes all backends — full outage.",
        "injection": {
            "type": "misconfiguration",
            "target": "frontend",
            "method": "Change readiness probe path from /health to /healthz (non-existent)",
        },
        "expected_root_cause": "Frontend readiness probe misconfigured (/healthz returns 404), causing restart loop",
        "expected_causal_chain": [
            "Readiness probe to /healthz returns 404",
            "Kubernetes marks pod as not ready",
            "After failureThreshold exceeded, pod is restarted",
            "New pod starts, same probe fails again",
            "Pod enters CrashLoopBackOff with increasing backoff",
            "Service has 0 ready endpoints — all traffic returns 503",
            "No actual application error — app is healthy on /health",
        ],
        "expected_findings": {
            "critical": ["CrashLoopBackOff", "0 ready endpoints"],
            "warning": ["readiness probe failing"],
            "info": ["no application errors in logs", "container starts successfully"],
        },
        "relevant_data_sources": [
            "cloudwatch_logs:pod-restart-analysis",
            "kubernetes:pod_status",
            "kubernetes:events",
        ],
    },
}
