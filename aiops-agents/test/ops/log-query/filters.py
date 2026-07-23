"""
Pre-processing filters for log query results.
Reduces token consumption by deduplicating, summarizing, and ranking before agent consumption.
"""
import re
from collections import Counter
from datetime import datetime


def dedup_logs(results: list[dict], window_key: str = "@message", threshold: int = 3) -> list[dict]:
    """
    Deduplicate similar log messages.
    Groups messages that appear >= threshold times into a single entry with count.
    """
    message_counts = Counter()
    message_samples = {}

    for row in results:
        msg = row.get(window_key, "")
        # Normalize: strip timestamps, UUIDs, numbers for grouping
        normalized = re.sub(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b", "<UUID>", msg)
        normalized = re.sub(r"\b\d{10,13}\b", "<TIMESTAMP>", normalized)
        normalized = re.sub(r"\b\d+\.\d+\.\d+\.\d+\b", "<IP>", normalized)

        message_counts[normalized] += 1
        if normalized not in message_samples:
            message_samples[normalized] = row

    deduped = []
    for normalized, count in message_counts.most_common():
        entry = message_samples[normalized].copy()
        if count >= threshold:
            entry["_occurrence_count"] = count
            entry["_deduplicated"] = True
        deduped.append(entry)

    return deduped


def truncate_stack_traces(results: list[dict], max_lines: int = 5, message_key: str = "@message") -> list[dict]:
    """
    Truncate stack traces to keep first and last N lines.
    Dramatically reduces token usage for Java/Python exceptions.
    """
    truncated = []
    for row in results:
        msg = row.get(message_key, "")
        lines = msg.split("\n")
        if len(lines) > max_lines * 2:
            kept = lines[:max_lines] + [f"  ... ({len(lines) - max_lines*2} lines truncated) ..."] + lines[-max_lines:]
            row = row.copy()
            row[message_key] = "\n".join(kept)
        truncated.append(row)
    return truncated


def filter_by_severity(results: list[dict], min_severity: str = "warning") -> list[dict]:
    """
    Filter log entries by severity level.
    """
    severity_order = {"debug": 0, "info": 1, "warning": 2, "warn": 2, "error": 3, "critical": 4, "fatal": 4}
    min_level = severity_order.get(min_severity.lower(), 0)

    filtered = []
    for row in results:
        msg = row.get("@message", "").lower()
        level = row.get("level", "")

        # Try to detect severity from message
        if not level:
            for sev in ["fatal", "critical", "error", "warn", "warning", "info", "debug"]:
                if sev in msg:
                    level = sev
                    break

        if severity_order.get(level.lower(), 0) >= min_level:
            filtered.append(row)

    return filtered


def summarize_for_agent(results: list[dict], max_entries: int = 20, max_message_length: int = 200) -> list[dict]:
    """
    Final summarization pass: truncate messages and limit entries.
    Optimized for agent context window.
    """
    summarized = []
    for row in results[:max_entries]:
        entry = {}
        for key, value in row.items():
            if isinstance(value, str) and len(value) > max_message_length:
                entry[key] = value[:max_message_length] + "..."
            else:
                entry[key] = value
        summarized.append(entry)

    return summarized


def build_pipeline(*filters):
    """
    Compose filters into a processing pipeline.

    Usage:
        pipeline = build_pipeline(
            lambda r: dedup_logs(r, threshold=3),
            lambda r: truncate_stack_traces(r, max_lines=3),
            lambda r: filter_by_severity(r, min_severity="warning"),
            lambda r: summarize_for_agent(r, max_entries=15),
        )
        processed = pipeline(raw_results)
    """
    def pipeline(results):
        for f in filters:
            results = f(results)
        return results
    return pipeline
