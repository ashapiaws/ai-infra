"""
Structured DevOps Agent — Deterministic queries + Operations Format.

This agent represents the proper operational practices approach:
- Deterministic query templates (no LLM-generated queries)
- Pre-processed, filtered, deduplicated data
- Structured output format (Operations Format v1)
- Multi-step reasoning with tool calls
- Token-efficient context (only actionable data)

This is the OPTIMIZED approach to compare against naive.
"""
import os
import sys
import json
import time
from datetime import datetime
from pathlib import Path

# Add parent paths for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / "log-query"))
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / "mcp-servers" / "cloudwatch-metrics"))
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / "mcp-servers" / "k8s-resources"))

from runner import run_template
from filters import build_pipeline, dedup_logs, truncate_stack_traces, filter_by_severity, summarize_for_agent


class StructuredAgent:
    """
    Structured DevOps Agent — uses deterministic queries and produces
    structured output conforming to the Operations Format.
    """

    def __init__(self, cluster_name: str, region: str = "us-west-2", namespace: str = "aiops-app"):
        self.cluster_name = cluster_name
        self.region = region
        self.namespace = namespace
        self.data_sources_used = []
        self.metrics = {
            "start_time": None,
            "end_time": None,
            "input_tokens": 0,
            "output_tokens": 0,
            "data_gathering_ms": 0,
            "preprocessing_ms": 0,
            "llm_call_ms": 0,
            "total_ms": 0,
            "queries_executed": 0,
            "cache_hits": 0,
        }

        # Pre-processing pipeline
        self.pipeline = build_pipeline(
            lambda r: dedup_logs(r, threshold=3),
            lambda r: truncate_stack_traces(r, max_lines=3),
            lambda r: filter_by_severity(r, min_severity="warning"),
            lambda r: summarize_for_agent(r, max_entries=15, max_message_length=150),
        )

    def _query_logs(self, template_name: str, extra_params: dict | None = None) -> dict:
        """Execute a deterministic log query template."""
        params = {
            "cluster_name": self.cluster_name,
            "namespace": self.namespace,
            **(extra_params or {}),
        }

        result = run_template(
            template_name=template_name,
            params=params,
            use_cache=True,
            region=self.region,
        )

        self.metrics["queries_executed"] += 1
        if result.get("from_cache"):
            self.metrics["cache_hits"] += 1

        self.data_sources_used.append({
            "type": "cloudwatch_logs",
            "query": template_name,
            "parameters": params,
            "result_count": result.get("result_count", 0),
            "from_cache": result.get("from_cache", False),
        })

        return result

    def _query_metrics(self, metric_key: str, period_minutes: int = 15, stat: str = "Average") -> dict:
        """Fetch a pre-defined metric."""
        # Import from MCP server
        from server import get_metric_data

        result = get_metric_data(
            metric_key=metric_key,
            period_minutes=period_minutes,
            stat=stat,
            namespace_override=self.namespace,
        )

        self.metrics["queries_executed"] += 1
        self.data_sources_used.append({
            "type": "cloudwatch_metrics",
            "query": metric_key,
            "parameters": {"period_minutes": period_minutes, "stat": stat},
            "result_count": 1 if result.get("summary") else 0,
            "from_cache": False,
        })

        return result

    def _query_k8s(self, tool_name: str, **kwargs) -> dict:
        """Execute a K8s resource query."""
        from server import tool_get_pod_status, tool_list_events, tool_get_deployment_status

        tools = {
            "get_pod_status": tool_get_pod_status,
            "list_events": tool_list_events,
            "get_deployment_status": tool_get_deployment_status,
        }

        tool_fn = tools.get(tool_name)
        if not tool_fn:
            return {"error": f"Unknown tool: {tool_name}"}

        result = tool_fn(namespace=self.namespace, **kwargs)

        self.metrics["queries_executed"] += 1
        self.data_sources_used.append({
            "type": "kubernetes",
            "query": tool_name,
            "parameters": {"namespace": self.namespace, **kwargs},
            "result_count": result.get("count", 0),
            "from_cache": False,
        })

        return result

    def _gather_relevant_data(self, trigger_type: str) -> dict:
        """
        Smart data gathering — only query what's relevant to the trigger type.
        This is the key difference from naive: we don't dump everything.
        """
        data = {}

        # Always get: error summary + pod status + events
        data["errors"] = self._query_logs("error-summary")
        data["pod_status"] = self._query_k8s("get_pod_status")
        data["events"] = self._query_k8s("list_events", event_type="Warning")

        # Conditional queries based on trigger signal
        if trigger_type in ("oom", "memory", "restart", "crash"):
            data["restarts"] = self._query_logs("pod-restart-analysis")
            data["memory"] = self._query_metrics("pod_memory_utilization", period_minutes=60, stat="Maximum")

        if trigger_type in ("latency", "slow", "timeout"):
            data["latency"] = self._query_logs("latency-breakdown")
            data["cpu"] = self._query_metrics("pod_cpu_utilization", period_minutes=15)

        if trigger_type in ("resource", "pressure", "throttle"):
            data["resource_pressure"] = self._query_logs("resource-pressure")
            data["cpu"] = self._query_metrics("pod_cpu_utilization")
            data["memory"] = self._query_metrics("pod_memory_utilization")

        return data

    def _preprocess_data(self, raw_data: dict) -> dict:
        """Apply pre-processing pipeline to reduce token consumption."""
        processed = {}
        for key, value in raw_data.items():
            if isinstance(value, dict) and "results" in value:
                processed[key] = {
                    **{k: v for k, v in value.items() if k != "results"},
                    "results": self.pipeline(value["results"]),
                }
            else:
                processed[key] = value
        return processed

    def build_prompt(self, trigger_description: str, processed_data: dict) -> str:
        """
        Structured prompt — focused, with clear output schema requirement.
        Data is already pre-processed and minimal.
        """
        data_section = json.dumps(processed_data, indent=2, default=str)

        return f"""You are a Kubernetes DevOps agent. Diagnose the following issue using ONLY the provided data.

## Alert
{trigger_description}

## Cluster Context
- Cluster: {self.cluster_name}
- Namespace: {self.namespace}
- Region: {self.region}

## Pre-Processed Operational Data
{data_section}

## Instructions
1. Identify the root cause based on the evidence above
2. Map the causal chain (what caused what)
3. Rate each finding by severity (critical/warning/info)
4. Provide specific remediation steps
5. State your confidence level (0.0-1.0) based on data completeness

## Required Output Format (JSON)
{{
  "summary": "<1-2 sentence root cause>",
  "findings": [
    {{
      "severity": "critical|warning|info",
      "component": "<affected component>",
      "observation": "<what you observed>",
      "evidence": "<specific data reference>",
      "recommendation": "<fix>"
    }}
  ],
  "causal_chain": ["<step 1>", "<step 2>", "..."],
  "confidence": 0.0-1.0,
  "data_gaps": ["<what data would increase confidence>"]
}}

IMPORTANT: Only state facts supported by the data above. If data is missing, say so.
"""

    def diagnose(self, trigger_description: str, trigger_type: str = "unknown") -> dict:
        """
        Run the structured agent against a scenario.
        Multi-phase: gather → preprocess → prompt → (LLM) → validate
        """
        self.metrics["start_time"] = time.time()

        # Phase 1: Deterministic data gathering
        gather_start = time.time()
        raw_data = self._gather_relevant_data(trigger_type)
        gather_end = time.time()
        self.metrics["data_gathering_ms"] = int((gather_end - gather_start) * 1000)

        # Phase 2: Pre-processing (filter, dedup, summarize)
        preprocess_start = time.time()
        processed_data = self._preprocess_data(raw_data)
        preprocess_end = time.time()
        self.metrics["preprocessing_ms"] = int((preprocess_end - preprocess_start) * 1000)

        # Phase 3: Build focused prompt
        prompt = self.build_prompt(trigger_description, processed_data)
        self.metrics["input_tokens"] = len(prompt) // 4  # Rough estimate

        # Phase 4: LLM call
        llm_start = time.time()

        # ---- LLM CALL WOULD GO HERE ----
        # response = bedrock.invoke_model(prompt=prompt, ...)
        # validated_response = validate_against_schema(response, operations_format_schema)
        # ---- END LLM CALL ----

        llm_end = time.time()
        self.metrics["llm_call_ms"] = int((llm_end - llm_start) * 1000)
        self.metrics["end_time"] = time.time()
        self.metrics["total_ms"] = int((self.metrics["end_time"] - self.metrics["start_time"]) * 1000)

        return {
            "agent_type": "structured",
            "prompt": prompt,
            "prompt_length_chars": len(prompt),
            "estimated_input_tokens": self.metrics["input_tokens"],
            "data_sources_used": self.data_sources_used,
            "metrics": self.metrics,
            "response": None,  # Filled by benchmark runner after LLM call
        }
