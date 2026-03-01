#!/usr/bin/env python3
"""Aggregate Claude Code session metadata over a time window.

Usage: python3 aggregate-sessions.py [--days N] [--dir PATH]
Output: JSON to stdout

Reads session-meta/*.json from ~/.claude/usage-data/ by default.
Filters by start_time within the last N days (default: 7).
"""

import argparse
import json
import os
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path


def parse_iso(s):
    """Parse ISO 8601 timestamp string to datetime (UTC)."""
    # Handle Z suffix
    s = s.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(s)
    except (ValueError, TypeError):
        return None


def main():
    parser = argparse.ArgumentParser(description="Aggregate Claude Code session metadata")
    parser.add_argument("--days", type=int, default=7, help="Number of days to look back (default: 7)")
    parser.add_argument("--dir", type=str, default=None, help="Path to session-meta directory")
    args = parser.parse_args()

    # Determine session-meta directory
    if args.dir:
        meta_dir = Path(args.dir)
    else:
        meta_dir = Path.home() / ".claude" / "usage-data" / "session-meta"

    if not meta_dir.is_dir():
        print(f"Error: directory not found: {meta_dir}", file=sys.stderr)
        sys.exit(1)

    cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)

    # Aggregate counters
    sessions = []
    projects = Counter()
    tool_dist = Counter()
    lang_dist = Counter()
    total_lines_added = 0
    total_lines_removed = 0
    total_files_modified = 0
    total_messages_user = 0
    total_messages_assistant = 0
    total_duration = 0
    total_input_tokens = 0
    total_output_tokens = 0
    total_commits = 0
    total_pushes = 0
    total_tool_errors = 0
    tool_error_cats = Counter()
    uses_task_agent = 0
    uses_mcp = 0
    uses_web_search = 0
    uses_web_fetch = 0
    total_interruptions = 0
    hour_dist = Counter()
    first_prompts = []
    session_types = Counter()

    # Read facets for session types
    facets_dir = meta_dir.parent / "facets"
    facets = {}
    if facets_dir.is_dir():
        for fp in facets_dir.glob("*.json"):
            try:
                with open(fp, "r", encoding="utf-8") as f:
                    facet = json.load(f)
                    sid = facet.get("session_id")
                    if sid:
                        facets[sid] = facet
            except (json.JSONDecodeError, IOError):
                continue

    # Process session files
    json_files = list(meta_dir.glob("*.json"))
    for fp in json_files:
        try:
            with open(fp, "r", encoding="utf-8") as f:
                data = json.load(f)
        except (json.JSONDecodeError, IOError):
            continue

        start = parse_iso(data.get("start_time", ""))
        if not start or start < cutoff:
            continue

        sessions.append(data)

        # Project
        proj = data.get("project_path", "unknown")
        # Shorten to last 2 path components
        parts = proj.rstrip("/").split("/")
        short_proj = "/".join(parts[-2:]) if len(parts) >= 2 else proj
        projects[short_proj] += 1

        # Tools
        for tool, count in data.get("tool_counts", {}).items():
            tool_dist[tool] += count

        # Languages
        for lang, count in data.get("languages", {}).items():
            lang_dist[lang] += count

        # Numeric aggregates
        total_lines_added += data.get("lines_added", 0)
        total_lines_removed += data.get("lines_removed", 0)
        total_files_modified += data.get("files_modified", 0)
        total_messages_user += data.get("user_message_count", 0)
        total_messages_assistant += data.get("assistant_message_count", 0)
        total_duration += data.get("duration_minutes", 0)
        total_input_tokens += data.get("input_tokens", 0)
        total_output_tokens += data.get("output_tokens", 0)
        total_commits += data.get("git_commits", 0)
        total_pushes += data.get("git_pushes", 0)
        total_tool_errors += data.get("tool_errors", 0)
        total_interruptions += data.get("user_interruptions", 0)

        # Tool error categories
        for cat, cnt in data.get("tool_error_categories", {}).items():
            tool_error_cats[cat] += cnt

        # Feature usage booleans
        if data.get("uses_task_agent"):
            uses_task_agent += 1
        if data.get("uses_mcp"):
            uses_mcp += 1
        if data.get("uses_web_search"):
            uses_web_search += 1
        if data.get("uses_web_fetch"):
            uses_web_fetch += 1

        # Hour distribution
        for h in data.get("message_hours", []):
            hour_dist[h] += 1

        # First prompts
        fp_text = data.get("first_prompt", "")
        if fp_text:
            first_prompts.append(fp_text)

        # Session type from facets
        sid = data.get("session_id", "")
        if sid in facets:
            st = facets[sid].get("session_type", "unknown")
            session_types[st] += 1

    # Build result
    n = len(sessions)
    result = {
        "period_days": args.days,
        "sessions_total": n,
        "projects": [{"path": p, "sessions": c} for p, c in projects.most_common()],
        "tool_distribution": [{"tool": t, "count": c} for t, c in tool_dist.most_common()],
        "language_distribution": [{"language": l, "count": c} for l, c in lang_dist.most_common()],
        "session_types": dict(session_types) if session_types else {},
        "totals": {
            "user_messages": total_messages_user,
            "assistant_messages": total_messages_assistant,
            "duration_minutes": total_duration,
            "lines_added": total_lines_added,
            "lines_removed": total_lines_removed,
            "files_modified": total_files_modified,
            "git_commits": total_commits,
            "git_pushes": total_pushes,
            "input_tokens": total_input_tokens,
            "output_tokens": total_output_tokens,
            "tool_errors": total_tool_errors,
            "user_interruptions": total_interruptions,
        },
        "averages": {
            "messages_per_session": round(total_messages_user / n, 1) if n else 0,
            "duration_minutes": round(total_duration / n, 1) if n else 0,
            "lines_added_per_session": round(total_lines_added / n, 1) if n else 0,
            "files_per_session": round(total_files_modified / n, 1) if n else 0,
        },
        "complexity_indicators": {
            "task_agent_pct": round(uses_task_agent / n * 100, 1) if n else 0,
            "mcp_pct": round(uses_mcp / n * 100, 1) if n else 0,
            "web_search_pct": round(uses_web_search / n * 100, 1) if n else 0,
            "web_fetch_pct": round(uses_web_fetch / n * 100, 1) if n else 0,
        },
        "tool_error_categories": dict(tool_error_cats.most_common()),
        "time_distribution": {str(h): c for h, c in sorted(hour_dist.items())},
        "first_prompts": first_prompts[:50],  # cap to avoid huge output
    }

    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    print()


if __name__ == "__main__":
    main()
