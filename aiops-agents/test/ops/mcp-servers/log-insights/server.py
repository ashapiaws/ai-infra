"""
CloudWatch Log Insights MCP Server
Executes parameterized query templates — the LLM selects templates, not writes queries.
"""
import os
import sys
import json

# Add parent path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "log-query"))

from runner import run_template, load_template
from filters import build_pipeline, dedup_logs, truncate_stack_traces, filter_by_severity, summarize_for_agent
from pathlib import Path

TEMPLATES_DIR = Path(os.environ.get("TEMPLATES_DIR", os.path.join(os.path.dirname(__file__), "..", "..", "log-query", "templates")))
REGION = os.environ.get("AWS_REGION", "us-west-2")
CLUSTER_NAME = os.environ.get("CLUSTER_NAME", "aiops-test-cluster")


# Pre-processing pipeline for agent consumption
AGENT_PIPELINE = build_pipeline(
    lambda r: dedup_logs(r, threshold=3),
    lambda r: truncate_stack_traces(r, max_lines=3),
    lambda r: filter_by_severity(r, min_severity="warning"),
    lambda r: summarize_for_agent(r, max_entries=15, max_message_length=150),
)


def tool_run_log_query(template_name: str, parameters: dict | None = None) -> dict:
    """
    MCP Tool: Run a named log query template.

    The agent provides:
    - template_name: One of the pre-defined templates
    - parameters: Override defaults (namespace, time_range, etc.)

    Returns filtered, deduplicated results optimized for agent consumption.
    """
    params = {
        "cluster_name": CLUSTER_NAME,
        **(parameters or {}),
    }

    result = run_template(
        template_name=template_name,
        params=params,
        use_cache=True,
        region=REGION,
    )

    if result["status"] != "complete":
        return result

    # Apply pre-processing pipeline
    raw_results = result.get("results", [])
    processed = AGENT_PIPELINE(raw_results)

    return {
        "status": "complete",
        "template": template_name,
        "parameters": params,
        "result_count_raw": len(raw_results),
        "result_count_processed": len(processed),
        "results": processed,
        "token_savings_estimate": f"{(1 - len(processed)/max(len(raw_results),1))*100:.0f}%",
    }


def tool_list_templates(category: str | None = None) -> dict:
    """
    MCP Tool: List available query templates.
    Agent uses this to discover what queries are available.
    """
    templates = []
    for f in TEMPLATES_DIR.glob("*.json"):
        try:
            tmpl = json.loads(f.read_text())
            templates.append({
                "name": tmpl["name"],
                "description": tmpl["description"],
                "parameters": list(tmpl.get("parameters", {}).keys()),
            })
        except Exception:
            continue

    return {"templates": templates, "count": len(templates)}


# MCP Server interface
TOOLS = {
    "run_log_query": {
        "function": tool_run_log_query,
        "description": "Execute a pre-defined log query template. Returns filtered results.",
        "parameters": {
            "template_name": {"type": "string", "required": True, "description": "Name of the query template"},
            "parameters": {"type": "object", "required": False, "description": "Parameter overrides"},
        },
    },
    "list_templates": {
        "function": tool_list_templates,
        "description": "List available log query templates",
        "parameters": {
            "category": {"type": "string", "required": False},
        },
    },
}

if __name__ == "__main__":
    print("Log Insights MCP Server - Available tools:")
    for name, tool in TOOLS.items():
        print(f"  {name}: {tool['description']}")
    print("\nAvailable templates:")
    print(json.dumps(tool_list_templates(), indent=2))
