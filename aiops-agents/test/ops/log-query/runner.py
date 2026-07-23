"""
Deterministic Log Query Runner
Executes parameterized CloudWatch Insights queries with caching and filtering.
No LLM-generated queries — all queries come from version-controlled templates.
"""
import os
import sys
import json
import time
import hashlib
import argparse
from pathlib import Path
from datetime import datetime, timedelta
from string import Template

import boto3

TEMPLATES_DIR = Path(__file__).parent / "templates"
CACHE_DIR = Path(__file__).parent / ".cache"
CACHE_DIR.mkdir(exist_ok=True)

DEFAULT_REGION = os.environ.get("AWS_REGION", "us-west-2")
DEFAULT_CLUSTER = os.environ.get("CLUSTER_NAME", "aiops-test-cluster")


def load_template(name: str) -> dict:
    """Load a query template by name."""
    template_path = TEMPLATES_DIR / f"{name}.json"
    if not template_path.exists():
        available = [f.stem for f in TEMPLATES_DIR.glob("*.json")]
        raise ValueError(f"Template '{name}' not found. Available: {available}")
    with open(template_path) as f:
        return json.load(f)


def resolve_parameters(template: dict, overrides: dict) -> dict:
    """Resolve template parameters with defaults and overrides."""
    params = {}
    for key, spec in template.get("parameters", {}).items():
        if key in overrides:
            params[key] = overrides[key]
        elif "default" in spec:
            params[key] = spec["default"]
        elif spec.get("required"):
            raise ValueError(f"Required parameter '{key}' not provided")
    return params


def render_query(template: dict, params: dict) -> tuple[str, str]:
    """Render the query string and log group with parameter substitution."""
    query = Template(template["query"]).safe_substitute(params)
    log_group = Template(template["log_group"]).safe_substitute(params)
    return query, log_group


def get_cache_key(query: str, log_group: str, time_range: int) -> str:
    """Generate cache key for query results."""
    content = f"{query}|{log_group}|{time_range}"
    return hashlib.md5(content.encode()).hexdigest()


def check_cache(cache_key: str, max_age_seconds: int = 300) -> dict | None:
    """Check if cached results exist and are fresh."""
    cache_file = CACHE_DIR / f"{cache_key}.json"
    if cache_file.exists():
        data = json.loads(cache_file.read_text())
        cached_at = data.get("cached_at", 0)
        if time.time() - cached_at < max_age_seconds:
            return data
    return None


def save_cache(cache_key: str, data: dict):
    """Save query results to cache."""
    data["cached_at"] = time.time()
    cache_file = CACHE_DIR / f"{cache_key}.json"
    cache_file.write_text(json.dumps(data, indent=2, default=str))


def execute_query(
    query: str,
    log_group: str,
    time_range_minutes: int,
    region: str = DEFAULT_REGION,
    max_results: int = 50,
) -> dict:
    """Execute a CloudWatch Insights query and return structured results."""
    client = boto3.client("logs", region_name=region)

    end_time = int(time.time())
    start_time = end_time - (time_range_minutes * 60)

    response = client.start_query(
        logGroupName=log_group,
        startTime=start_time,
        endTime=end_time,
        queryString=query,
        limit=max_results,
    )

    query_id = response["queryId"]

    # Poll for results
    for _ in range(30):
        result = client.get_query_results(queryId=query_id)
        if result["status"] in ("Complete", "Failed", "Cancelled"):
            break
        time.sleep(1)

    if result["status"] != "Complete":
        return {"status": "failed", "error": f"Query status: {result['status']}"}

    # Transform results to structured format
    rows = []
    for record in result.get("results", []):
        row = {field["field"]: field["value"] for field in record if not field["field"].startswith("@ptr")}
        rows.append(row)

    return {
        "status": "complete",
        "query": query,
        "log_group": log_group,
        "time_range_minutes": time_range_minutes,
        "result_count": len(rows),
        "results": rows,
        "statistics": result.get("statistics", {}),
    }


def run_template(
    template_name: str,
    params: dict | None = None,
    use_cache: bool = True,
    region: str = DEFAULT_REGION,
) -> dict:
    """Execute a named template with parameters."""
    template = load_template(template_name)
    resolved_params = resolve_parameters(template, params or {})
    query, log_group = render_query(template, resolved_params)

    time_range = resolved_params.get("time_range_minutes", 15)

    # Check cache
    if use_cache:
        cache_key = get_cache_key(query, log_group, time_range)
        cached = check_cache(cache_key)
        if cached:
            cached["from_cache"] = True
            return cached

    # Execute
    result = execute_query(query, log_group, time_range, region)

    # Cache result
    if use_cache and result["status"] == "complete":
        cache_key = get_cache_key(query, log_group, time_range)
        save_cache(cache_key, result)

    result["template"] = template_name
    result["parameters"] = resolved_params
    return result


def main():
    parser = argparse.ArgumentParser(description="Run deterministic log queries")
    parser.add_argument("--template", "-t", required=True, help="Template name to execute")
    parser.add_argument("--cluster", "-c", default=DEFAULT_CLUSTER, help="Cluster name")
    parser.add_argument("--namespace", "-n", default="aiops-app", help="Kubernetes namespace")
    parser.add_argument("--time-range", type=int, default=15, help="Time range in minutes")
    parser.add_argument("--no-cache", action="store_true", help="Skip cache")
    parser.add_argument("--region", default=DEFAULT_REGION, help="AWS region")
    parser.add_argument("--output", choices=["json", "summary"], default="json")

    args = parser.parse_args()

    params = {
        "cluster_name": args.cluster,
        "namespace": args.namespace,
        "time_range_minutes": args.time_range,
    }

    result = run_template(
        template_name=args.template,
        params=params,
        use_cache=not args.no_cache,
        region=args.region,
    )

    if args.output == "json":
        print(json.dumps(result, indent=2, default=str))
    else:
        print(f"\n{'='*60}")
        print(f"Template: {args.template}")
        print(f"Status: {result['status']}")
        print(f"Results: {result.get('result_count', 0)}")
        print(f"Cached: {result.get('from_cache', False)}")
        print(f"{'='*60}")
        for row in result.get("results", [])[:10]:
            print(json.dumps(row, default=str))


if __name__ == "__main__":
    main()
