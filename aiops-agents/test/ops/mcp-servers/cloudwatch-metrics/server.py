"""
CloudWatch Metrics MCP Server
Provides deterministic metric retrieval tools for the DevOps Agent.
All metrics are pre-defined — no ad-hoc queries.
"""
import os
import json
from datetime import datetime, timedelta

import boto3

REGION = os.environ.get("AWS_REGION", "us-west-2")
CLUSTER_NAME = os.environ.get("CLUSTER_NAME", "aiops-test-cluster")

# Pre-defined metrics the agent can query
AVAILABLE_METRICS = {
    "node_cpu_utilization": {
        "namespace": "ContainerInsights",
        "metric_name": "node_cpu_utilization",
        "dimensions": [{"Name": "ClusterName", "Value": CLUSTER_NAME}],
        "unit": "Percent",
    },
    "node_memory_utilization": {
        "namespace": "ContainerInsights",
        "metric_name": "node_memory_utilization",
        "dimensions": [{"Name": "ClusterName", "Value": CLUSTER_NAME}],
        "unit": "Percent",
    },
    "pod_cpu_utilization": {
        "namespace": "ContainerInsights",
        "metric_name": "pod_cpu_utilization",
        "dimensions": [
            {"Name": "ClusterName", "Value": CLUSTER_NAME},
            {"Name": "Namespace", "Value": ""},  # Filled at query time
        ],
        "unit": "Percent",
    },
    "pod_memory_utilization": {
        "namespace": "ContainerInsights",
        "metric_name": "pod_memory_utilization",
        "dimensions": [
            {"Name": "ClusterName", "Value": CLUSTER_NAME},
            {"Name": "Namespace", "Value": ""},
        ],
        "unit": "Percent",
    },
    "pod_number_of_container_restarts": {
        "namespace": "ContainerInsights",
        "metric_name": "pod_number_of_container_restarts",
        "dimensions": [
            {"Name": "ClusterName", "Value": CLUSTER_NAME},
            {"Name": "Namespace", "Value": ""},
        ],
        "unit": "Count",
    },
    "node_network_total_bytes": {
        "namespace": "ContainerInsights",
        "metric_name": "node_network_total_bytes",
        "dimensions": [{"Name": "ClusterName", "Value": CLUSTER_NAME}],
        "unit": "Bytes",
    },
    "cluster_node_count": {
        "namespace": "ContainerInsights",
        "metric_name": "cluster_node_count",
        "dimensions": [{"Name": "ClusterName", "Value": CLUSTER_NAME}],
        "unit": "Count",
    },
    "cluster_failed_node_count": {
        "namespace": "ContainerInsights",
        "metric_name": "cluster_failed_node_count",
        "dimensions": [{"Name": "ClusterName", "Value": CLUSTER_NAME}],
        "unit": "Count",
    },
}


def get_metric_data(
    metric_key: str,
    period_minutes: int = 15,
    stat: str = "Average",
    namespace_override: str | None = None,
    pod_name: str | None = None,
) -> dict:
    """
    Retrieve metric data for a pre-defined metric.
    Returns aggregated statistics, not raw data points.
    """
    if metric_key not in AVAILABLE_METRICS:
        return {
            "error": f"Unknown metric: {metric_key}",
            "available": list(AVAILABLE_METRICS.keys()),
        }

    metric_def = AVAILABLE_METRICS[metric_key].copy()
    dimensions = [d.copy() for d in metric_def["dimensions"]]

    # Fill in dynamic dimensions
    for dim in dimensions:
        if dim["Name"] == "Namespace" and namespace_override:
            dim["Value"] = namespace_override
        if dim["Name"] == "PodName" and pod_name:
            dim["Value"] = pod_name

    # Remove empty dimensions
    dimensions = [d for d in dimensions if d["Value"]]

    client = boto3.client("cloudwatch", region_name=REGION)

    end_time = datetime.utcnow()
    start_time = end_time - timedelta(minutes=period_minutes)

    response = client.get_metric_statistics(
        Namespace=metric_def["namespace"],
        MetricName=metric_def["metric_name"],
        Dimensions=dimensions,
        StartTime=start_time,
        EndTime=end_time,
        Period=max(60, period_minutes * 60 // 10),  # ~10 data points
        Statistics=[stat],
        Unit=metric_def["unit"],
    )

    datapoints = sorted(response.get("Datapoints", []), key=lambda x: x["Timestamp"])

    # Compute summary statistics
    values = [dp[stat] for dp in datapoints if stat in dp]
    summary = {}
    if values:
        summary = {
            "current": values[-1],
            "average": sum(values) / len(values),
            "max": max(values),
            "min": min(values),
            "data_points": len(values),
        }

    return {
        "metric": metric_key,
        "period_minutes": period_minutes,
        "stat": stat,
        "unit": metric_def["unit"],
        "summary": summary,
        "datapoints": [
            {"timestamp": dp["Timestamp"].isoformat(), "value": dp.get(stat)}
            for dp in datapoints[-5:]  # Only last 5 for token efficiency
        ],
    }


def get_metric_anomalies(std_dev_threshold: float = 2.0) -> dict:
    """
    Check all metrics against baseline and report anomalies.
    Returns only metrics that deviate significantly.
    """
    anomalies = []
    for metric_key in AVAILABLE_METRICS:
        try:
            result = get_metric_data(metric_key, period_minutes=60, stat="Average")
            summary = result.get("summary", {})
            if not summary:
                continue

            # Simple anomaly: current value > average + threshold * std_dev
            values = [dp["value"] for dp in result.get("datapoints", []) if dp["value"] is not None]
            if len(values) < 3:
                continue

            avg = sum(values) / len(values)
            variance = sum((v - avg) ** 2 for v in values) / len(values)
            std_dev = variance ** 0.5

            current = summary.get("current", 0)
            if std_dev > 0 and abs(current - avg) > std_dev_threshold * std_dev:
                anomalies.append({
                    "metric": metric_key,
                    "current": current,
                    "baseline_avg": avg,
                    "std_dev": std_dev,
                    "deviation": abs(current - avg) / std_dev,
                    "direction": "above" if current > avg else "below",
                })
        except Exception:
            continue

    return {
        "anomalies": anomalies,
        "metrics_checked": len(AVAILABLE_METRICS),
        "threshold_std_dev": std_dev_threshold,
    }


def list_available_metrics() -> dict:
    """List all available metrics the agent can query."""
    return {
        "metrics": [
            {"key": k, "namespace": v["namespace"], "unit": v["unit"]}
            for k, v in AVAILABLE_METRICS.items()
        ]
    }


# MCP Server interface would wrap these functions as tools
# For now, this serves as the implementation reference
if __name__ == "__main__":
    print("Available metrics:")
    print(json.dumps(list_available_metrics(), indent=2))
