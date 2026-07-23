"""
Benchmark Runner — Executes both agent approaches against the same scenario
and records results for evaluation.

Usage:
    python runner.py --scenario oom-cascade --model anthropic.claude-3-sonnet
    python runner.py --scenario all --model anthropic.claude-3-sonnet
"""
import os
import sys
import json
import time
import hashlib
import argparse
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent / "scenarios"))
sys.path.insert(0, str(Path(__file__).parent / "agents"))

from definitions import SCENARIOS
from naive_agent import NaiveAgent
from structured_agent import StructuredAgent

RESULTS_DIR = Path(__file__).parent / "results"
RESULTS_DIR.mkdir(exist_ok=True)

CLUSTER_NAME = os.environ.get("CLUSTER_NAME", "aiops-test-cluster")
REGION = os.environ.get("AWS_REGION", "us-west-2")
NAMESPACE = os.environ.get("APP_NAMESPACE", "aiops-app")


def call_llm(prompt: str, model_id: str = "anthropic.claude-3-sonnet-20240229-v1:0") -> dict:
    """
    Call the LLM (Bedrock) with the given prompt.
    Returns response text and token usage.
    """
    import boto3

    bedrock = boto3.client("bedrock-runtime", region_name=REGION)

    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 2000,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1,  # Low temp for deterministic comparison
    })

    start = time.time()
    response = bedrock.invoke_model(
        modelId=model_id,
        body=body,
        contentType="application/json",
    )
    latency_ms = int((time.time() - start) * 1000)

    result = json.loads(response["body"].read())

    return {
        "text": result["content"][0]["text"],
        "input_tokens": result["usage"]["input_tokens"],
        "output_tokens": result["usage"]["output_tokens"],
        "latency_ms": latency_ms,
        "model_id": model_id,
    }


def run_naive(scenario_key: str, model_id: str, dry_run: bool = False) -> dict:
    """Run the naive agent against a scenario."""
    scenario = SCENARIOS[scenario_key]

    agent = NaiveAgent(cluster_name=CLUSTER_NAME, region=REGION, namespace=NAMESPACE)
    result = agent.diagnose(trigger_description=scenario["description"])

    if not dry_run:
        llm_response = call_llm(result["prompt"], model_id)
        result["response"] = llm_response
        result["metrics"]["llm_call_ms"] = llm_response["latency_ms"]
        result["metrics"]["input_tokens"] = llm_response["input_tokens"]
        result["metrics"]["output_tokens"] = llm_response["output_tokens"]
        result["metrics"]["total_ms"] += llm_response["latency_ms"]
    else:
        result["response"] = {"text": "[DRY RUN - no LLM call]", "input_tokens": result["estimated_input_tokens"]}

    result["scenario"] = scenario_key
    result["timestamp"] = datetime.utcnow().isoformat() + "Z"
    return result


def run_structured(scenario_key: str, model_id: str, dry_run: bool = False) -> dict:
    """Run the structured agent against a scenario."""
    scenario = SCENARIOS[scenario_key]

    # Determine trigger type from scenario injection type
    trigger_type_map = {
        "resource_pressure": "memory",
        "load_test": "latency",
        "storage_fill": "resource",
        "network": "unknown",
        "misconfiguration": "restart",
    }
    trigger_type = trigger_type_map.get(scenario["injection"]["type"], "unknown")

    agent = StructuredAgent(cluster_name=CLUSTER_NAME, region=REGION, namespace=NAMESPACE)
    result = agent.diagnose(trigger_description=scenario["description"], trigger_type=trigger_type)

    if not dry_run:
        llm_response = call_llm(result["prompt"], model_id)
        result["response"] = llm_response
        result["metrics"]["llm_call_ms"] = llm_response["latency_ms"]
        result["metrics"]["input_tokens"] = llm_response["input_tokens"]
        result["metrics"]["output_tokens"] = llm_response["output_tokens"]
        result["metrics"]["total_ms"] += llm_response["latency_ms"]
    else:
        result["response"] = {"text": "[DRY RUN - no LLM call]", "input_tokens": result["estimated_input_tokens"]}

    result["scenario"] = scenario_key
    result["timestamp"] = datetime.utcnow().isoformat() + "Z"
    return result


def save_result(result: dict, scenario_key: str):
    """Save benchmark result to file."""
    agent_type = result["agent_type"]
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filename = f"{scenario_key}_{agent_type}_{timestamp}.json"
    output_path = RESULTS_DIR / filename
    output_path.write_text(json.dumps(result, indent=2, default=str))
    print(f"  Result saved: {output_path}")
    return output_path


def main():
    parser = argparse.ArgumentParser(description="Run DevOps Agent benchmarks")
    parser.add_argument("--scenario", "-s", required=True, help="Scenario key or 'all'")
    parser.add_argument("--mode", "-m", choices=["naive", "structured", "both"], default="both")
    parser.add_argument("--model", default="anthropic.claude-3-sonnet-20240229-v1:0")
    parser.add_argument("--dry-run", action="store_true", help="Skip LLM call, just measure data prep")
    parser.add_argument("--repeat", type=int, default=1, help="Number of times to repeat each run")

    args = parser.parse_args()

    scenarios = list(SCENARIOS.keys()) if args.scenario == "all" else [args.scenario]

    for scenario_key in scenarios:
        if scenario_key not in SCENARIOS:
            print(f"Unknown scenario: {scenario_key}")
            continue

        print(f"\n{'='*60}")
        print(f"Scenario: {scenario_key} — {SCENARIOS[scenario_key]['name']}")
        print(f"{'='*60}")

        for run_num in range(args.repeat):
            if args.repeat > 1:
                print(f"\n  --- Run {run_num + 1}/{args.repeat} ---")

            if args.mode in ("naive", "both"):
                print(f"\n  Running NAIVE agent...")
                naive_result = run_naive(scenario_key, args.model, args.dry_run)
                save_result(naive_result, scenario_key)
                print(f"  Naive: {naive_result['estimated_input_tokens']} est. tokens, "
                      f"{naive_result['metrics']['data_gathering_ms']}ms data gathering")

            if args.mode in ("structured", "both"):
                print(f"\n  Running STRUCTURED agent...")
                structured_result = run_structured(scenario_key, args.model, args.dry_run)
                save_result(structured_result, scenario_key)
                print(f"  Structured: {structured_result['estimated_input_tokens']} est. tokens, "
                      f"{structured_result['metrics']['data_gathering_ms']}ms data gathering, "
                      f"{structured_result['metrics']['preprocessing_ms']}ms preprocessing")

            if args.mode == "both" and not args.dry_run:
                # Quick comparison
                ratio = naive_result["estimated_input_tokens"] / max(structured_result["estimated_input_tokens"], 1)
                print(f"\n  Token ratio (naive/structured): {ratio:.1f}x")


if __name__ == "__main__":
    main()
