"""
Kubernetes Resource MCP Server
Read-only access to cluster state for DevOps Agent diagnostics.
Write operations are NOT exposed — they require separate approval workflows.
"""
import os
import json
from datetime import datetime, timezone

from kubernetes import client, config


def _init_k8s():
    """Initialize Kubernetes client."""
    try:
        config.load_kube_config()
    except config.ConfigException:
        config.load_incluster_config()


def tool_get_pod_status(namespace: str = "aiops-app", pod_name_pattern: str | None = None) -> dict:
    """
    MCP Tool: Get pod status with recent events.
    Returns structured pod health info for agent consumption.
    """
    _init_k8s()
    v1 = client.CoreV1Api()

    pods = v1.list_namespaced_pod(namespace=namespace)
    results = []

    for pod in pods.items:
        name = pod.metadata.name
        if pod_name_pattern and pod_name_pattern not in name:
            continue

        # Extract container statuses
        container_statuses = []
        for cs in (pod.status.container_statuses or []):
            status_info = {
                "name": cs.name,
                "ready": cs.ready,
                "restart_count": cs.restart_count,
                "state": "running" if cs.state.running else "waiting" if cs.state.waiting else "terminated",
            }
            if cs.state.waiting:
                status_info["reason"] = cs.state.waiting.reason
            if cs.state.terminated:
                status_info["reason"] = cs.state.terminated.reason
                status_info["exit_code"] = cs.state.terminated.exit_code
            container_statuses.append(status_info)

        results.append({
            "name": name,
            "phase": pod.status.phase,
            "node": pod.spec.node_name,
            "containers": container_statuses,
            "conditions": [
                {"type": c.type, "status": c.status, "reason": c.reason}
                for c in (pod.status.conditions or [])
            ],
        })

    return {"namespace": namespace, "pods": results, "count": len(results)}


def tool_get_deployment_status(namespace: str = "aiops-app", deployment_name: str | None = None) -> dict:
    """
    MCP Tool: Get deployment rollout status.
    """
    _init_k8s()
    apps_v1 = client.AppsV1Api()

    if deployment_name:
        dep = apps_v1.read_namespaced_deployment(name=deployment_name, namespace=namespace)
        deployments = [dep]
    else:
        dep_list = apps_v1.list_namespaced_deployment(namespace=namespace)
        deployments = dep_list.items

    results = []
    for dep in deployments:
        results.append({
            "name": dep.metadata.name,
            "replicas": {
                "desired": dep.spec.replicas,
                "ready": dep.status.ready_replicas or 0,
                "available": dep.status.available_replicas or 0,
                "unavailable": dep.status.unavailable_replicas or 0,
            },
            "conditions": [
                {"type": c.type, "status": c.status, "reason": c.reason, "message": c.message}
                for c in (dep.status.conditions or [])
            ],
            "strategy": dep.spec.strategy.type if dep.spec.strategy else "Unknown",
        })

    return {"namespace": namespace, "deployments": results}


def tool_list_events(namespace: str = "aiops-app", event_type: str | None = None, limit: int = 20) -> dict:
    """
    MCP Tool: List recent Kubernetes events.
    Useful for understanding pod failures, scaling events, etc.
    """
    _init_k8s()
    v1 = client.CoreV1Api()

    events = v1.list_namespaced_event(namespace=namespace)
    results = []

    # Sort by last timestamp, most recent first
    sorted_events = sorted(
        events.items,
        key=lambda e: e.last_timestamp or e.metadata.creation_timestamp or datetime.min.replace(tzinfo=timezone.utc),
        reverse=True,
    )

    for event in sorted_events[:limit]:
        if event_type and event.type != event_type:
            continue
        results.append({
            "type": event.type,
            "reason": event.reason,
            "message": event.message[:200] if event.message else "",
            "object": f"{event.involved_object.kind}/{event.involved_object.name}",
            "count": event.count,
            "last_seen": event.last_timestamp.isoformat() if event.last_timestamp else None,
        })

    return {"namespace": namespace, "events": results[:limit], "count": len(results)}


# MCP Tool registry
TOOLS = {
    "get_pod_status": {
        "function": tool_get_pod_status,
        "description": "Get pod status with container health and restart counts",
        "parameters": {
            "namespace": {"type": "string", "default": "aiops-app"},
            "pod_name_pattern": {"type": "string", "required": False},
        },
    },
    "get_deployment_status": {
        "function": tool_get_deployment_status,
        "description": "Get deployment rollout status and replica counts",
        "parameters": {
            "namespace": {"type": "string", "default": "aiops-app"},
            "deployment_name": {"type": "string", "required": False},
        },
    },
    "list_events": {
        "function": tool_list_events,
        "description": "List recent Kubernetes events (warnings, errors, scaling)",
        "parameters": {
            "namespace": {"type": "string", "default": "aiops-app"},
            "event_type": {"type": "string", "required": False, "enum": ["Normal", "Warning"]},
            "limit": {"type": "integer", "default": 20},
        },
    },
}

if __name__ == "__main__":
    print("K8s Resources MCP Server - Available tools:")
    for name, tool in TOOLS.items():
        print(f"  {name}: {tool['description']}")
