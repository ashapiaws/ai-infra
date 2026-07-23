"""
Validate observability stack (CloudWatch, Container Insights, Fluent Bit).
"""
import pytest
import time


class TestCloudWatchLogs:
    """Validate CloudWatch log groups and streams exist."""

    def test_app_log_group_exists(self, logs_client, cluster_name):
        """Verify application log group exists."""
        log_group = f"/aws/eks/{cluster_name}/app"
        response = logs_client.describe_log_groups(logGroupNamePrefix=log_group)
        groups = [g["logGroupName"] for g in response["logGroups"]]
        assert log_group in groups, f"Log group {log_group} not found"

    def test_cluster_log_group_exists(self, logs_client, cluster_name):
        """Verify cluster log group exists."""
        log_group = f"/aws/eks/{cluster_name}/cluster"
        response = logs_client.describe_log_groups(logGroupNamePrefix=log_group)
        groups = [g["logGroupName"] for g in response["logGroups"]]
        assert log_group in groups, f"Log group {log_group} not found"

    def test_container_insights_log_group(self, logs_client, cluster_name):
        """Verify Container Insights performance log group."""
        log_group = f"/aws/containerinsights/{cluster_name}/performance"
        response = logs_client.describe_log_groups(logGroupNamePrefix=log_group)
        groups = [g["logGroupName"] for g in response["logGroups"]]
        assert log_group in groups, f"Container Insights log group not found"

    def test_log_retention_configured(self, logs_client, cluster_name):
        """Verify log retention is set (not infinite)."""
        log_group = f"/aws/eks/{cluster_name}/app"
        response = logs_client.describe_log_groups(logGroupNamePrefix=log_group)
        for group in response["logGroups"]:
            if group["logGroupName"] == log_group:
                assert "retentionInDays" in group, "Retention not set"
                assert group["retentionInDays"] <= 30


class TestContainerInsights:
    """Validate Container Insights metrics are being collected."""

    def test_cloudwatch_agent_running(self, k8s_client):
        """Verify CloudWatch agent pods are running."""
        pods = k8s_client.list_namespaced_pod(namespace="amazon-cloudwatch")
        running = [p for p in pods.items if p.status.phase == "Running"]
        assert len(running) >= 1, "No CloudWatch agent pods running"

    def test_container_insights_metrics(self, cloudwatch_client, cluster_name):
        """Verify Container Insights metrics are available."""
        response = cloudwatch_client.list_metrics(
            Namespace="ContainerInsights",
            Dimensions=[
                {"Name": "ClusterName", "Value": cluster_name},
            ],
        )
        metric_names = [m["MetricName"] for m in response["Metrics"]]
        # Check for key Container Insights metrics
        expected = ["node_cpu_utilization", "pod_cpu_utilization", "node_memory_utilization"]
        for metric in expected:
            assert metric in metric_names, f"Missing metric: {metric}"


class TestFluentBit:
    """Validate Fluent Bit log forwarding."""

    def test_fluent_bit_daemonset_running(self, k8s_client):
        """Verify Fluent Bit is running on nodes."""
        pods = k8s_client.list_namespaced_pod(
            namespace="amazon-cloudwatch",
            label_selector="app.kubernetes.io/name=fluent-bit",
        )
        assert len(pods.items) >= 1, "Fluent Bit not running"
