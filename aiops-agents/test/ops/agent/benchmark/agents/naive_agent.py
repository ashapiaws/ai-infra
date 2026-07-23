"""
Naive DevOps Agent — One-shot prompting approach.

This agent represents the typical "just dump everything to the LLM" approach:
- No structured queries — asks the LLM to figure out what to look for
- Raw, unprocessed data — full logs and metrics dumped into context
- No pre-filtering — all data regardless of relevance
- Free-form output — no enforced schema
- Single LLM call — one-shot with everything

This is the BASELINE to compare against the structured approach.
"""
import os
import json
import time
import boto3
from datetime import datetime, timedelta
from kubernetes import client, config

# Simulated LLM client (replace with actual bedrock/openai call)
# For benchmark purposes, we measure what goes IN and comes OUT


class NaiveAgent:
    """
    Naive DevOps Agent — dumps all available data to a single LLM prompt.
    No query templates, no pre-filtering, no structured output.
    """

    def __init__(self, cluster_name: str, region: str = "us-west-2", namespace: str = "aiops-app"):
        self.cluster_name = cluster_name
        self.region = region
        self.namespace = namespace
        self.metrics = {
            "start_time": None,
            "end_time": None,
            "input_tokens": 0,
            "output_tokens": 0,
            "data_gathering_ms": 0,
            "llm_call_ms": 0,
            "total_ms": 0,
        }

    def _get_all_logs(self, time_range_minutes: int = 30) -> str:
        """
        Naive approach: Fetch ALL recent logs from ALL log groups.
        No filtering, no dedup, no summarization.
        """
        logs_client = boto3.client("logs", region_name=self.region)
        all_logs = []

        log_groups = [
            f"/aws/containerinsights/{self.cluster_name}/application",
            f"/aws/containerinsights/{self.cluster_name}/performance",
            f"/aws/eks/{self.cluster_name}/app",
            f"/aws/eks/{self.cluster_name}/cluster",
        ]

        end_time = int(time.time() * 1000)
        start_time = end_time - (time_range_minutes * 60 * 1000)

        for log_group in log_groups:
            try:
                # Just grab everything — no filtering
                response = logs_client.filter_log_events(
                    logGroupName=log_group,
                    startTime=start_time,
                    endTime=end_time,
                    limit=100,  # Arbitrary limit
                )
                for event in response.get("events", []):
                    all_logs.append(f"[{log_group}] {event['message']}")
            except Exception as e:
                all_logs.append(f"[ERROR] Could not read {log_group}: {e}")

        return "\n".join(all_logs)

    def _get_all_metrics(self, time_range_minutes: int = 30) -> str:
        """
        Naive approach: Dump all available Container Insights metrics.
        Returns raw data points, not summaries.
        """
        cw_client = boto3.client("cloudwatch", region_name=self.region)

        metrics_response = cw_client.list_metrics(
            Namespace="ContainerInsights",
            Dimensions=[{"Name": "ClusterName", "Value": self.cluster_name}],
        )

        all_metrics = []
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=time_range_minutes)

        for metric in metrics_response.get("Metrics", [])[:20]:  # Cap at 20
            try:
                data = cw_client.get_metric_statistics(
                    Namespace=metric["Namespace"],
                    MetricName=metric["MetricName"],
                    Dimensions=metric["Dimensions"],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=60,
                    Statistics=["Average", "Maximum", "Minimum"],
                )
                for dp in data.get("Datapoints", []):
                    all_metrics.append(
                        f"{metric['MetricName']} [{dp['Timestamp']}]: "
                        f"avg={dp.get('Average', 'N/A')}, "
                        f"max={dp.get('Maximum', 'N/A')}, "
                        f"min={dp.get('Minimum', 'N/A')}"
                    )
            except Exception:
                continue

        return "\n".join(all_metrics)

    def _get_all_k8s_state(self) -> str:
        """
        Naive approach: Dump full kubectl output for all resources.
        """
        try:
            config.load_kube_config()
        except Exception:
            config.load_incluster_config()

        v1 = client.CoreV1Api()
        apps_v1 = client.AppsV1Api()

        state_parts = []

        # All pods — full detail
        pods = v1.list_namespaced_pod(namespace=self.namespace)
        state_parts.append("=== PODS ===")
        for pod in pods.items:
            state_parts.append(json.dumps(
                client.ApiClient().sanitize_for_serialization(pod),
                indent=2
            ))

        # All events
        events = v1.list_namespaced_event(namespace=self.namespace)
        state_parts.append("\n=== EVENTS ===")
        for event in events.items:
            state_parts.append(
                f"[{event.type}] {event.reason}: {event.message} "
                f"(object: {event.involved_object.kind}/{event.involved_object.name}, "
                f"count: {event.count})"
            )

        # All services
        services = v1.list_namespaced_service(namespace=self.namespace)
        state_parts.append("\n=== SERVICES ===")
        for svc in services.items:
            state_parts.append(json.dumps(
                client.ApiClient().sanitize_for_serialization(svc),
                indent=2
            ))

        # Deployments
        deployments = apps_v1.list_namespaced_deployment(namespace=self.namespace)
        state_parts.append("\n=== DEPLOYMENTS ===")
        for dep in deployments.items:
            state_parts.append(json.dumps(
                client.ApiClient().sanitize_for_serialization(dep),
                indent=2
            ))

        return "\n".join(state_parts)

    def build_prompt(self, trigger_description: str) -> str:
        """
        Naive approach: One giant prompt with all data.
        No structure, no guidance on output format, no tool usage.
        """
        return f"""You are a DevOps engineer. An alert has been triggered for a Kubernetes cluster.

ALERT: {trigger_description}

Here is all the available data from the cluster. Analyze it and determine the root cause.

=== CLOUDWATCH LOGS (last 30 minutes) ===
{self._get_all_logs()}

=== CLOUDWATCH METRICS (last 30 minutes) ===
{self._get_all_metrics()}

=== KUBERNETES STATE ===
{self._get_all_k8s_state()}

Based on the above data, provide:
1. What is the root cause?
2. What is the impact?
3. What should we do to fix it?
"""

    def diagnose(self, trigger_description: str) -> dict:
        """
        Run the naive agent against a scenario.
        Returns the prompt + metrics for comparison.
        """
        self.metrics["start_time"] = time.time()

        # Data gathering phase
        gather_start = time.time()
        prompt = self.build_prompt(trigger_description)
        gather_end = time.time()
        self.metrics["data_gathering_ms"] = int((gather_end - gather_start) * 1000)

        # Estimate token count (rough: 4 chars per token)
        self.metrics["input_tokens"] = len(prompt) // 4

        # In a real benchmark, we'd call the LLM here
        # For now, return the prompt for external evaluation
        llm_start = time.time()

        # ---- LLM CALL WOULD GO HERE ----
        # response = bedrock.invoke_model(prompt=prompt, ...)
        # ---- END LLM CALL ----

        llm_end = time.time()
        self.metrics["llm_call_ms"] = int((llm_end - llm_start) * 1000)
        self.metrics["end_time"] = time.time()
        self.metrics["total_ms"] = int((self.metrics["end_time"] - self.metrics["start_time"]) * 1000)

        return {
            "agent_type": "naive",
            "prompt": prompt,
            "prompt_length_chars": len(prompt),
            "estimated_input_tokens": self.metrics["input_tokens"],
            "metrics": self.metrics,
            "response": None,  # Filled by benchmark runner after LLM call
        }
