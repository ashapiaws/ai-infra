"""
Benchmark Evaluator — Scores agent responses against ground truth.

Scoring Domains:
1. Time to Diagnosis (TTD) — Total elapsed time
2. Root Cause Accuracy (RCA) — Did it identify the correct root cause?
3. Correlation Depth (CD) — How many causal links were correctly identified?
4. False Positives (FP) — Incorrect claims about system state
5. Evidence Grounding (EG) — Are claims backed by data references?
6. Token Efficiency (TE) — Total tokens consumed

Usage:
    python evaluate.py --scenario oom-cascade
    python evaluate.py --scenario all --format table
"""
import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent / "scenarios"))
from definitions import SCENARIOS

RESULTS_DIR = Path(__file__).parent / "results"


def load_latest_results(scenario_key: str) -> tuple[dict | None, dict | None]:
    """Load the most recent naive and structured results for a scenario."""
    naive_results = sorted(RESULTS_DIR.glob(f"{scenario_key}_naive_*.json"), reverse=True)
    structured_results = sorted(RESULTS_DIR.glob(f"{scenario_key}_structured_*.json"), reverse=True)

    naive = json.loads(naive_results[0].read_text()) if naive_results else None
    structured = json.loads(structured_results[0].read_text()) if structured_results else None

    return naive, structured


def score_root_cause_accuracy(response_text: str, expected_root_cause: str) -> dict:
    """
    Score how accurately the agent identified the root cause.
    Returns score 0-10 and reasoning.
    """
    if not response_text:
        return {"score": 0, "reason": "No response"}

    response_lower = response_text.lower()
    expected_lower = expected_root_cause.lower()

    # Extract key terms from expected root cause
    key_terms = [term for term in expected_lower.split() if len(term) > 3]
    matched_terms = sum(1 for term in key_terms if term in response_lower)
    term_coverage = matched_terms / max(len(key_terms), 1)

    # Check for specific indicators
    indicators = {
        "oomkill": any(w in response_lower for w in ["oomkill", "oom", "out of memory"]),
        "memory_limit": any(w in response_lower for w in ["memory limit", "512mi", "memory exceeded"]),
        "cpu_throttle": any(w in response_lower for w in ["cpu throttl", "cpu limit", "250m"]),
        "disk_full": any(w in response_lower for w in ["disk full", "no space", "enospc", "storage"]),
        "dns": any(w in response_lower for w in ["dns", "coredns", "resolution"]),
        "probe": any(w in response_lower for w in ["readiness probe", "healthz", "probe fail"]),
    }

    # Score based on coverage
    if term_coverage > 0.7:
        score = 9 if term_coverage > 0.85 else 8
    elif term_coverage > 0.5:
        score = 7
    elif term_coverage > 0.3:
        score = 5
    else:
        score = 3 if term_coverage > 0.1 else 1

    return {
        "score": score,
        "term_coverage": round(term_coverage, 2),
        "key_indicators_found": {k: v for k, v in indicators.items() if v},
    }


def score_correlation_depth(response_text: str, expected_chain: list[str]) -> dict:
    """
    Score how many causal chain links were correctly identified.
    """
    if not response_text:
        return {"score": 0, "links_found": 0, "links_expected": len(expected_chain)}

    response_lower = response_text.lower()
    links_found = 0

    matched_links = []
    for link in expected_chain:
        # Check if key concepts from this chain link appear in response
        link_terms = [t for t in link.lower().split() if len(t) > 3]
        link_matched = sum(1 for t in link_terms if t in response_lower) / max(len(link_terms), 1)
        if link_matched > 0.4:  # At least 40% of terms match
            links_found += 1
            matched_links.append(link)

    coverage = links_found / max(len(expected_chain), 1)
    score = min(10, int(coverage * 10))

    return {
        "score": score,
        "links_found": links_found,
        "links_expected": len(expected_chain),
        "coverage": round(coverage, 2),
        "matched_links": matched_links,
    }


def score_evidence_grounding(response_text: str) -> dict:
    """
    Score whether claims are backed by specific data references.
    Look for: timestamps, metric values, pod names, log excerpts, numbers.
    """
    if not response_text:
        return {"score": 0, "evidence_count": 0}

    import re

    evidence_patterns = [
        (r"\d+%", "percentage"),
        (r"\d+Mi|\d+Gi", "memory_value"),
        (r"\d+m\b", "cpu_value"),
        (r"\d{4}-\d{2}-\d{2}", "date"),
        (r"pod[-/]\w+", "pod_name"),
        (r"exit.code.\d+", "exit_code"),
        (r"p\d{2}=\d+", "percentile"),
        (r"count[=:]\s*\d+", "count"),
        (r"Error|error|ERROR", "error_ref"),
    ]

    evidence_count = 0
    evidence_types = set()
    for pattern, etype in evidence_patterns:
        matches = re.findall(pattern, response_text)
        if matches:
            evidence_count += len(matches)
            evidence_types.add(etype)

    # Score: more diverse evidence types = better grounding
    score = min(10, len(evidence_types) * 2 + min(evidence_count, 5))

    return {
        "score": score,
        "evidence_count": evidence_count,
        "evidence_types": list(evidence_types),
    }


def score_false_positives(response_text: str, scenario: dict) -> dict:
    """
    Detect incorrect claims about the system.
    Penalize for mentioning issues that aren't part of this scenario.
    """
    if not response_text:
        return {"score": 10, "false_positives": []}

    response_lower = response_text.lower()
    false_positives = []

    # Check for claims about issues NOT in this scenario
    unrelated_claims = {
        "oom-cascade": ["cpu throttl", "disk full", "dns fail", "probe misconfigur"],
        "cpu-throttle": ["oomkill", "disk full", "dns fail", "probe misconfigur", "out of memory"],
        "disk-pressure": ["oomkill", "cpu throttl", "dns fail", "probe misconfigur"],
        "dns-failure": ["oomkill", "cpu throttl", "disk full", "probe misconfigur"],
        "restart-loop": ["oomkill", "disk full", "dns fail", "cpu throttl"],
    }

    scenario_name = scenario.get("name", "").lower().replace(" ", "-")
    # Find matching key
    for key in unrelated_claims:
        if key in scenario_name or scenario_name in key:
            for claim in unrelated_claims[key]:
                if claim in response_lower:
                    false_positives.append(claim)
            break

    # More false positives = lower score
    penalty = len(false_positives) * 2
    score = max(0, 10 - penalty)

    return {
        "score": score,
        "false_positives": false_positives,
        "penalty": penalty,
    }


def evaluate_result(result: dict, scenario_key: str) -> dict:
    """Evaluate a single agent result against ground truth."""
    scenario = SCENARIOS[scenario_key]
    response_text = result.get("response", {}).get("text", "")

    scores = {
        "time_to_diagnosis_ms": result["metrics"]["total_ms"],
        "root_cause_accuracy": score_root_cause_accuracy(
            response_text, scenario["expected_root_cause"]
        ),
        "correlation_depth": score_correlation_depth(
            response_text, scenario["expected_causal_chain"]
        ),
        "evidence_grounding": score_evidence_grounding(response_text),
        "false_positives": score_false_positives(response_text, scenario),
        "token_efficiency": {
            "input_tokens": result["metrics"].get("input_tokens", 0),
            "output_tokens": result["metrics"].get("output_tokens", 0),
            "total_tokens": result["metrics"].get("input_tokens", 0) + result["metrics"].get("output_tokens", 0),
        },
    }

    # Composite score (weighted)
    weights = {
        "root_cause_accuracy": 0.30,
        "correlation_depth": 0.25,
        "evidence_grounding": 0.20,
        "false_positives": 0.15,
        "time_score": 0.10,
    }

    # Normalize time score (faster = better, cap at 30s)
    time_score = max(0, 10 - (scores["time_to_diagnosis_ms"] / 3000))
    scores["time_score"] = round(time_score, 1)

    composite = (
        scores["root_cause_accuracy"]["score"] * weights["root_cause_accuracy"]
        + scores["correlation_depth"]["score"] * weights["correlation_depth"]
        + scores["evidence_grounding"]["score"] * weights["evidence_grounding"]
        + scores["false_positives"]["score"] * weights["false_positives"]
        + scores["time_score"] * weights["time_score"]
    )
    scores["composite_score"] = round(composite, 2)

    return scores


def compare_results(scenario_key: str) -> dict:
    """Load and compare naive vs structured for a scenario."""
    naive, structured = load_latest_results(scenario_key)

    comparison = {
        "scenario": scenario_key,
        "scenario_name": SCENARIOS[scenario_key]["name"],
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }

    if naive:
        comparison["naive"] = evaluate_result(naive, scenario_key)
    if structured:
        comparison["structured"] = evaluate_result(structured, scenario_key)

    if naive and structured:
        # Compute deltas
        comparison["delta"] = {
            "composite_score": (
                comparison["structured"]["composite_score"]
                - comparison["naive"]["composite_score"]
            ),
            "token_savings_pct": round(
                (1 - comparison["structured"]["token_efficiency"]["total_tokens"]
                 / max(comparison["naive"]["token_efficiency"]["total_tokens"], 1)) * 100, 1
            ),
            "time_delta_ms": (
                comparison["naive"]["time_to_diagnosis_ms"]
                - comparison["structured"]["time_to_diagnosis_ms"]
            ),
            "rca_score_delta": (
                comparison["structured"]["root_cause_accuracy"]["score"]
                - comparison["naive"]["root_cause_accuracy"]["score"]
            ),
            "correlation_delta": (
                comparison["structured"]["correlation_depth"]["score"]
                - comparison["naive"]["correlation_depth"]["score"]
            ),
        }

    return comparison


def print_comparison(comparison: dict):
    """Pretty-print comparison results."""
    print(f"\n{'='*70}")
    print(f"  BENCHMARK: {comparison['scenario_name']}")
    print(f"{'='*70}")

    if "naive" not in comparison or "structured" not in comparison:
        print("  Missing results for comparison. Run both agents first.")
        return

    naive = comparison["naive"]
    structured = comparison["structured"]
    delta = comparison["delta"]

    print(f"\n  {'Metric':<30} {'Naive':>10} {'Structured':>12} {'Delta':>10}")
    print(f"  {'-'*62}")
    print(f"  {'Composite Score':<30} {naive['composite_score']:>10.2f} {structured['composite_score']:>12.2f} {delta['composite_score']:>+10.2f}")
    print(f"  {'Root Cause Accuracy':<30} {naive['root_cause_accuracy']['score']:>10}/10 {structured['root_cause_accuracy']['score']:>12}/10 {delta['rca_score_delta']:>+10}")
    print(f"  {'Correlation Depth':<30} {naive['correlation_depth']['score']:>10}/10 {structured['correlation_depth']['score']:>12}/10 {delta['correlation_delta']:>+10}")
    print(f"  {'Evidence Grounding':<30} {naive['evidence_grounding']['score']:>10}/10 {structured['evidence_grounding']['score']:>12}/10")
    print(f"  {'False Positives':<30} {naive['false_positives']['score']:>10}/10 {structured['false_positives']['score']:>12}/10")
    print(f"  {'Time (ms)':<30} {naive['time_to_diagnosis_ms']:>10} {structured['time_to_diagnosis_ms']:>12} {delta['time_delta_ms']:>+10}")
    print(f"  {'Total Tokens':<30} {naive['token_efficiency']['total_tokens']:>10} {structured['token_efficiency']['total_tokens']:>12} {delta['token_savings_pct']:>+9.1f}%")
    print(f"\n  Winner: {'STRUCTURED' if delta['composite_score'] > 0 else 'NAIVE' if delta['composite_score'] < 0 else 'TIE'}")
    print(f"  Token savings: {delta['token_savings_pct']:.1f}%")


def main():
    parser = argparse.ArgumentParser(description="Evaluate DevOps Agent benchmark results")
    parser.add_argument("--scenario", "-s", required=True, help="Scenario key or 'all'")
    parser.add_argument("--format", choices=["text", "json"], default="text")
    parser.add_argument("--output", "-o", help="Save evaluation to file")

    args = parser.parse_args()

    scenarios = list(SCENARIOS.keys()) if args.scenario == "all" else [args.scenario]

    all_comparisons = []
    for scenario_key in scenarios:
        if scenario_key not in SCENARIOS:
            print(f"Unknown scenario: {scenario_key}")
            continue

        comparison = compare_results(scenario_key)
        all_comparisons.append(comparison)

        if args.format == "text":
            print_comparison(comparison)

    if args.format == "json":
        output = json.dumps(all_comparisons, indent=2)
        if args.output:
            Path(args.output).write_text(output)
            print(f"Results saved to: {args.output}")
        else:
            print(output)

    # Summary across all scenarios
    if len(all_comparisons) > 1 and args.format == "text":
        print(f"\n\n{'='*70}")
        print(f"  AGGREGATE RESULTS ({len(all_comparisons)} scenarios)")
        print(f"{'='*70}")

        naive_scores = [c["naive"]["composite_score"] for c in all_comparisons if "naive" in c]
        structured_scores = [c["structured"]["composite_score"] for c in all_comparisons if "structured" in c]

        if naive_scores and structured_scores:
            print(f"\n  Average Composite Score:")
            print(f"    Naive:      {sum(naive_scores)/len(naive_scores):.2f}")
            print(f"    Structured: {sum(structured_scores)/len(structured_scores):.2f}")

            token_savings = [c["delta"]["token_savings_pct"] for c in all_comparisons if "delta" in c]
            if token_savings:
                print(f"\n  Average Token Savings: {sum(token_savings)/len(token_savings):.1f}%")


if __name__ == "__main__":
    main()
