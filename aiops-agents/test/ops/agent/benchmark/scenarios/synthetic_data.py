"""
Synthetic Data Generator — Simulates cluster state for offline benchmarking.
Produces realistic CloudWatch logs, metrics, and K8s state for each scenario
so the benchmark can run without a live cluster.
"""
import json
import random
from datetime import datetime, timedelta

from definitions import SCENARIOS


def generate_oom_cascade_data() -> dict:
    """Generate synthetic data for OOMKill cascade scenario."""
    now = datetime.utcnow()

    logs = [
        {"@timestamp": (now - timedelta(minutes=25)).isoformat(), "level": "INFO", "pod": "postgres-5c8f9d7b6-m4n2q", "message": "PostgreSQL starting up..."},
        {"@timestamp": (now - timedelta(minutes=20)).isoformat(), "level": "WARNING", "pod": "postgres-5c8f9d7b6-m4n2q", "message": "memory usage at 85% of limit (435Mi/512Mi)"},
        {"@timestamp": (now - timedelta(minutes=15)).isoformat(), "level": "ERROR", "pod": "postgres-5c8f9d7b6-m4n2q", "message": "out of memory: killed process 1 (postgres) total-vm:612480kB, anon-rss:524288kB"},
        {"@timestamp": (now - timedelta(minutes=14)).isoformat(), "level": "WARNING", "pod": "postgres-5c8f9d7b6-m4n2q", "message": "Back-off restarting failed container"},
        {"@timestamp": (now - timedelta(minutes=12)).isoformat(), "level": "ERROR", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "psycopg2.OperationalError: could not connect to server: Connection refused"},
        {"@timestamp": (now - timedelta(minutes=12)).isoformat(), "level": "ERROR", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "psycopg2.OperationalError: could not connect to server: Connection refused"},
        {"@timestamp": (now - timedelta(minutes=11)).isoformat(), "level": "ERROR", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "psycopg2.OperationalError: could not connect to server: Connection refused"},
        {"@timestamp": (now - timedelta(minutes=10)).isoformat(), "level": "ERROR", "pod": "frontend-7d9f8b6c4-a8b3c", "message": "psycopg2.OperationalError: could not connect to server: Connection refused"},
        {"@timestamp": (now - timedelta(minutes=8)).isoformat(), "level": "WARNING", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "Redis cache miss for session:alice — backend unavailable"},
        {"@timestamp": (now - timedelta(minutes=5)).isoformat(), "level": "ERROR", "pod": "postgres-5c8f9d7b6-m4n2q", "message": "out of memory: killed process 1 (postgres) total-vm:612480kB, anon-rss:524288kB"},
        {"@timestamp": (now - timedelta(minutes=3)).isoformat(), "level": "ERROR", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "HTTP 500 returned to client: Internal server error"},
    ]

    metrics = {
        "pod_memory_utilization": {
            "summary": {"current": 99.8, "average": 87.3, "max": 99.8, "min": 45.2},
            "datapoints": [
                {"timestamp": (now - timedelta(minutes=30)).isoformat(), "value": 45.2},
                {"timestamp": (now - timedelta(minutes=25)).isoformat(), "value": 72.1},
                {"timestamp": (now - timedelta(minutes=20)).isoformat(), "value": 85.4},
                {"timestamp": (now - timedelta(minutes=15)).isoformat(), "value": 99.8},
                {"timestamp": (now - timedelta(minutes=5)).isoformat(), "value": 99.8},
            ],
        },
        "pod_cpu_utilization": {
            "summary": {"current": 35.2, "average": 28.4, "max": 42.1, "min": 22.0},
        },
        "pod_number_of_container_restarts": {
            "summary": {"current": 3, "average": 1.5, "max": 3, "min": 0},
        },
    }

    k8s_state = {
        "pods": [
            {
                "name": "postgres-5c8f9d7b6-m4n2q",
                "phase": "Running",
                "containers": [{"name": "postgres", "ready": False, "restart_count": 3, "state": "waiting", "reason": "CrashLoopBackOff"}],
                "conditions": [{"type": "Ready", "status": "False", "reason": "ContainersNotReady"}],
            },
            {
                "name": "frontend-7d9f8b6c4-x2k1p",
                "phase": "Running",
                "containers": [{"name": "frontend", "ready": True, "restart_count": 0, "state": "running"}],
                "conditions": [{"type": "Ready", "status": "True"}],
            },
            {
                "name": "frontend-7d9f8b6c4-a8b3c",
                "phase": "Running",
                "containers": [{"name": "frontend", "ready": True, "restart_count": 0, "state": "running"}],
                "conditions": [{"type": "Ready", "status": "True"}],
            },
            {
                "name": "redis-6b5d9f4c8-q7r3s",
                "phase": "Running",
                "containers": [{"name": "redis", "ready": True, "restart_count": 0, "state": "running"}],
                "conditions": [{"type": "Ready", "status": "True"}],
            },
        ],
        "events": [
            {"type": "Warning", "reason": "OOMKilled", "message": "Container postgres exceeded memory limit", "object": "Pod/postgres-5c8f9d7b6-m4n2q", "count": 3, "last_seen": (now - timedelta(minutes=5)).isoformat()},
            {"type": "Warning", "reason": "BackOff", "message": "Back-off restarting failed container", "object": "Pod/postgres-5c8f9d7b6-m4n2q", "count": 5, "last_seen": (now - timedelta(minutes=3)).isoformat()},
            {"type": "Normal", "reason": "Pulled", "message": "Container image postgres:16-alpine already present", "object": "Pod/postgres-5c8f9d7b6-m4n2q", "count": 3, "last_seen": (now - timedelta(minutes=4)).isoformat()},
        ],
    }

    return {"logs": logs, "metrics": metrics, "kubernetes": k8s_state}


def generate_cpu_throttle_data() -> dict:
    """Generate synthetic data for CPU throttling scenario."""
    now = datetime.utcnow()

    logs = [
        {"@timestamp": (now - timedelta(minutes=10)).isoformat(), "level": "INFO", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "request processed response_time=1850ms path=/login"},
        {"@timestamp": (now - timedelta(minutes=9)).isoformat(), "level": "INFO", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "request processed response_time=2100ms path=/login"},
        {"@timestamp": (now - timedelta(minutes=8)).isoformat(), "level": "INFO", "pod": "frontend-7d9f8b6c4-a8b3c", "message": "request processed response_time=1920ms path=/login"},
        {"@timestamp": (now - timedelta(minutes=7)).isoformat(), "level": "INFO", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "request processed response_time=2300ms path=/tasks/1"},
        {"@timestamp": (now - timedelta(minutes=5)).isoformat(), "level": "INFO", "pod": "frontend-7d9f8b6c4-a8b3c", "message": "request processed response_time=2050ms path=/login"},
    ]

    metrics = {
        "pod_cpu_utilization": {
            "summary": {"current": 99.2, "average": 95.8, "max": 99.8, "min": 88.4},
            "datapoints": [
                {"timestamp": (now - timedelta(minutes=15)).isoformat(), "value": 88.4},
                {"timestamp": (now - timedelta(minutes=12)).isoformat(), "value": 94.1},
                {"timestamp": (now - timedelta(minutes=9)).isoformat(), "value": 97.5},
                {"timestamp": (now - timedelta(minutes=6)).isoformat(), "value": 99.2},
                {"timestamp": (now - timedelta(minutes=3)).isoformat(), "value": 99.8},
            ],
        },
        "pod_memory_utilization": {
            "summary": {"current": 62.4, "average": 58.1, "max": 65.0, "min": 52.3},
        },
        "pod_number_of_container_restarts": {
            "summary": {"current": 0, "average": 0, "max": 0, "min": 0},
        },
    }

    k8s_state = {
        "pods": [
            {
                "name": "frontend-7d9f8b6c4-x2k1p",
                "phase": "Running",
                "containers": [{"name": "frontend", "ready": True, "restart_count": 0, "state": "running"}],
                "conditions": [{"type": "Ready", "status": "True"}],
            },
            {
                "name": "frontend-7d9f8b6c4-a8b3c",
                "phase": "Running",
                "containers": [{"name": "frontend", "ready": True, "restart_count": 0, "state": "running"}],
                "conditions": [{"type": "Ready", "status": "True"}],
            },
            {
                "name": "postgres-5c8f9d7b6-m4n2q",
                "phase": "Running",
                "containers": [{"name": "postgres", "ready": True, "restart_count": 0, "state": "running"}],
                "conditions": [{"type": "Ready", "status": "True"}],
            },
            {
                "name": "redis-6b5d9f4c8-q7r3s",
                "phase": "Running",
                "containers": [{"name": "redis", "ready": True, "restart_count": 0, "state": "running"}],
                "conditions": [{"type": "Ready", "status": "True"}],
            },
        ],
        "events": [],  # No warnings — system appears healthy from K8s perspective
    }

    return {"logs": logs, "metrics": metrics, "kubernetes": k8s_state}


def generate_restart_loop_data() -> dict:
    """Generate synthetic data for restart loop scenario."""
    now = datetime.utcnow()

    logs = [
        {"@timestamp": (now - timedelta(minutes=10)).isoformat(), "level": "INFO", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "Application started on 0.0.0.0:5000"},
        {"@timestamp": (now - timedelta(minutes=9)).isoformat(), "level": "INFO", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "Readiness probe: GET /healthz returned 404"},
        {"@timestamp": (now - timedelta(minutes=8)).isoformat(), "level": "INFO", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "Application started on 0.0.0.0:5000"},
        {"@timestamp": (now - timedelta(minutes=7)).isoformat(), "level": "INFO", "pod": "frontend-7d9f8b6c4-x2k1p", "message": "Readiness probe: GET /healthz returned 404"},
        {"@timestamp": (now - timedelta(minutes=5)).isoformat(), "level": "INFO", "pod": "frontend-7d9f8b6c4-a8b3c", "message": "Application started on 0.0.0.0:5000"},
        {"@timestamp": (now - timedelta(minutes=4)).isoformat(), "level": "INFO", "pod": "frontend-7d9f8b6c4-a8b3c", "message": "Readiness probe: GET /healthz returned 404"},
    ]

    metrics = {
        "pod_cpu_utilization": {
            "summary": {"current": 12.1, "average": 15.4, "max": 22.0, "min": 5.0},
        },
        "pod_memory_utilization": {
            "summary": {"current": 35.2, "average": 38.0, "max": 42.0, "min": 30.0},
        },
        "pod_number_of_container_restarts": {
            "summary": {"current": 8, "average": 4.5, "max": 8, "min": 0},
        },
    }

    k8s_state = {
        "pods": [
            {
                "name": "frontend-7d9f8b6c4-x2k1p",
                "phase": "Running",
                "containers": [{"name": "frontend", "ready": False, "restart_count": 8, "state": "waiting", "reason": "CrashLoopBackOff"}],
                "conditions": [{"type": "Ready", "status": "False", "reason": "ContainersNotReady"}],
            },
            {
                "name": "frontend-7d9f8b6c4-a8b3c",
                "phase": "Running",
                "containers": [{"name": "frontend", "ready": False, "restart_count": 6, "state": "waiting", "reason": "CrashLoopBackOff"}],
                "conditions": [{"type": "Ready", "status": "False", "reason": "ContainersNotReady"}],
            },
            {
                "name": "postgres-5c8f9d7b6-m4n2q",
                "phase": "Running",
                "containers": [{"name": "postgres", "ready": True, "restart_count": 0, "state": "running"}],
                "conditions": [{"type": "Ready", "status": "True"}],
            },
            {
                "name": "redis-6b5d9f4c8-q7r3s",
                "phase": "Running",
                "containers": [{"name": "redis", "ready": True, "restart_count": 0, "state": "running"}],
                "conditions": [{"type": "Ready", "status": "True"}],
            },
        ],
        "events": [
            {"type": "Warning", "reason": "Unhealthy", "message": "Readiness probe failed: HTTP probe failed with statuscode: 404", "object": "Pod/frontend-7d9f8b6c4-x2k1p", "count": 24, "last_seen": (now - timedelta(minutes=1)).isoformat()},
            {"type": "Warning", "reason": "Unhealthy", "message": "Readiness probe failed: HTTP probe failed with statuscode: 404", "object": "Pod/frontend-7d9f8b6c4-a8b3c", "count": 18, "last_seen": (now - timedelta(minutes=2)).isoformat()},
            {"type": "Warning", "reason": "BackOff", "message": "Back-off restarting failed container", "object": "Pod/frontend-7d9f8b6c4-x2k1p", "count": 8, "last_seen": (now - timedelta(minutes=1)).isoformat()},
            {"type": "Normal", "reason": "Started", "message": "Started container frontend", "object": "Pod/frontend-7d9f8b6c4-x2k1p", "count": 8, "last_seen": (now - timedelta(minutes=2)).isoformat()},
        ],
    }

    return {"logs": logs, "metrics": metrics, "kubernetes": k8s_state}


# Registry
SYNTHETIC_GENERATORS = {
    "oom-cascade": generate_oom_cascade_data,
    "cpu-throttle": generate_cpu_throttle_data,
    "restart-loop": generate_restart_loop_data,
}


def get_synthetic_data(scenario_key: str) -> dict:
    """Get synthetic data for a scenario."""
    generator = SYNTHETIC_GENERATORS.get(scenario_key)
    if not generator:
        return {"error": f"No synthetic data for scenario: {scenario_key}. Available: {list(SYNTHETIC_GENERATORS.keys())}"}
    return generator()


if __name__ == "__main__":
    import sys
    scenario = sys.argv[1] if len(sys.argv) > 1 else "oom-cascade"
    data = get_synthetic_data(scenario)
    print(json.dumps(data, indent=2, default=str))
