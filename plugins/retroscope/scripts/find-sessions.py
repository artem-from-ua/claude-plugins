#!/usr/bin/env python3
"""
find-sessions.py — Session discovery and content extraction for retroscope.

Modes:
  List mode:    find-sessions.py <today|yesterday|YYYY-MM-DD|YYYY-MM-DD:YYYY-MM-DD> [--project-dir DIR] [--tz TIMEZONE]
  Extract mode: find-sessions.py --extract <session.jsonl> [--date YYYY-MM-DD]
  Stats mode:   find-sessions.py --stats <session.jsonl>
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.request
from datetime import datetime, date, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_timezone(tz_name: str | None) -> timezone:
    """Return a timezone object, falling back to local system timezone."""
    if not tz_name:
        return datetime.now(timezone.utc).astimezone().tzinfo
    try:
        return ZoneInfo(tz_name)
    except (ZoneInfoNotFoundError, Exception):
        sys.stderr.write(f"Warning: unknown timezone '{tz_name}', using UTC\n")
        return timezone.utc


def encode_project_path(project_dir: str) -> str:
    """
    Encode project directory path to Claude's storage format.
    Example: /Users/artem/devel/foo -> -Users-artem-devel-foo
    """
    path = os.path.abspath(project_dir)
    # Replace leading / with -, then all / with -
    encoded = path.replace(os.sep, "-")
    if encoded.startswith("-"):
        pass  # already starts with dash from leading /
    else:
        encoded = "-" + encoded
    return encoded


def get_claude_projects_dir() -> Path:
    """Return ~/.claude/projects/ directory."""
    return Path.home() / ".claude" / "projects"


def parse_date_arg(date_str: str, tz) -> tuple[date, date]:
    """
    Parse date argument. Returns (start_date, end_date) tuple (inclusive).
    Supports: today, yesterday, YYYY-MM-DD, YYYY-MM-DD:YYYY-MM-DD
    """
    today = datetime.now(tz=tz).date()
    if date_str == "today":
        return today, today
    elif date_str == "yesterday":
        yesterday = today - timedelta(days=1)
        return yesterday, yesterday
    elif ":" in date_str:
        parts = date_str.split(":", 1)
        start = date.fromisoformat(parts[0])
        end = date.fromisoformat(parts[1])
        return start, end
    else:
        d = date.fromisoformat(date_str)
        return d, d


def parse_timestamp(ts_str: str, tz) -> datetime | None:
    """Parse ISO timestamp string to timezone-aware datetime."""
    if not ts_str:
        return None
    try:
        dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        return dt.astimezone(tz)
    except Exception:
        return None


# ---------------------------------------------------------------------------
# List mode
# ---------------------------------------------------------------------------

def find_sessions(date_str: str, project_dir: str | None, tz_name: str | None):
    """
    Find session files matching the given date range for the given project.
    Prints one file path per line.
    """
    tz = get_timezone(tz_name)

    # Resolve project directory
    if project_dir:
        proj_dir = os.path.abspath(project_dir)
    else:
        proj_dir = os.getcwd()

    start_date, end_date = parse_date_arg(date_str, tz)

    # Find the encoded project path directory
    encoded = encode_project_path(proj_dir)
    projects_base = get_claude_projects_dir()
    session_dir = projects_base / encoded

    if not session_dir.exists():
        # Also try without leading dash (edge case)
        alt_encoded = encoded.lstrip("-")
        alt_dir = projects_base / alt_encoded
        if alt_dir.exists():
            session_dir = alt_dir
        else:
            sys.stderr.write(f"No session directory found for: {proj_dir}\n")
            sys.stderr.write(f"Expected: {session_dir}\n")
            return

    jsonl_files = sorted(session_dir.glob("*.jsonl"))
    if not jsonl_files:
        sys.stderr.write(f"No session files in: {session_dir}\n")
        return

    # Date window: from start of start_date to end of end_date in local tz
    start_dt = datetime(start_date.year, start_date.month, start_date.day, 0, 0, 0, tzinfo=tz)
    end_dt = datetime(end_date.year, end_date.month, end_date.day, 23, 59, 59, 999999, tzinfo=tz)

    for jsonl_file in jsonl_files:
        # Quick filter: check file mtime
        mtime = jsonl_file.stat().st_mtime
        mtime_dt = datetime.fromtimestamp(mtime, tz=timezone.utc).astimezone(tz)
        if mtime_dt < start_dt:
            continue

        # Read first and last lines with timestamps to determine actual range
        session_start, session_end = get_session_time_range(jsonl_file, tz)
        if session_start is None and session_end is None:
            continue

        # Check overlap: session overlaps [start_dt, end_dt] if session_start <= end_dt AND session_end >= start_dt
        effective_start = session_start or mtime_dt
        effective_end = session_end or mtime_dt

        if effective_start <= end_dt and effective_end >= start_dt:
            print(str(jsonl_file))


def get_session_time_range(jsonl_file: Path, tz) -> tuple:
    """Return (first_timestamp, last_timestamp) for a session file."""
    first_ts = None
    last_ts = None

    try:
        with open(jsonl_file, errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                    ts = parse_timestamp(obj.get("timestamp"), tz)
                    if ts:
                        if first_ts is None:
                            first_ts = ts
                        last_ts = ts
                except json.JSONDecodeError:
                    continue
    except OSError:
        pass

    return first_ts, last_ts


# ---------------------------------------------------------------------------
# Extract mode
# ---------------------------------------------------------------------------

def extract_session(jsonl_file: str, date_filter: str | None):
    """
    Extract human-readable conversation from session JSONL.
    Outputs: [TIMESTAMP | role | tools: X,Y]\ntext\n\n
    Filters to user text and assistant text only (skips tool_result, tool_use, progress).
    """
    tz = get_timezone(None)

    date_obj = None
    if date_filter:
        date_obj = date.fromisoformat(date_filter)

    try:
        with open(jsonl_file, errors="ignore") as f:
            lines = f.readlines()
    except OSError as e:
        sys.stderr.write(f"Error reading {jsonl_file}: {e}\n")
        return

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = obj.get("type")
        if msg_type not in ("user", "assistant"):
            continue

        ts_str = obj.get("timestamp", "")
        ts = parse_timestamp(ts_str, tz)

        # Date filter
        if date_obj and ts:
            if ts.date() != date_obj:
                continue

        message = obj.get("message", {})
        role = message.get("role", msg_type)
        content = message.get("content", "")

        if msg_type == "user":
            text, _ = extract_user_text(content)
        else:  # assistant
            text, tools = extract_assistant_text(content)

        if not text:
            continue

        ts_display = ts.strftime("%Y-%m-%dT%H:%M") if ts else "unknown"

        tool_list = []
        if msg_type == "assistant":
            _, tools = extract_assistant_text(content)
            tool_list = tools

        header = f"[{ts_display} | {role}"
        if tool_list:
            header += f" | tools: {', '.join(tool_list)}"
        header += "]"

        print(header)
        print(text)
        print()


def extract_user_text(content) -> tuple[str, list]:
    """Extract text from user message content."""
    if isinstance(content, str):
        return content.strip(), []

    if isinstance(content, list):
        texts = []
        for block in content:
            if not isinstance(block, dict):
                continue
            block_type = block.get("type", "")
            if block_type == "text":
                txt = block.get("text", "").strip()
                if txt:
                    texts.append(txt)
            elif block_type == "tool_result":
                # Skip tool results — they are internal, not user text
                pass
            # Skip other types (file contents, images, etc.)
        return "\n\n".join(texts), []

    return "", []


def extract_assistant_text(content) -> tuple[str, list]:
    """Extract text and list of tool names from assistant message content."""
    if isinstance(content, str):
        return content.strip(), []

    texts = []
    tools = []

    if isinstance(content, list):
        for block in content:
            if not isinstance(block, dict):
                continue
            block_type = block.get("type", "")
            if block_type == "text":
                txt = block.get("text", "").strip()
                if txt:
                    texts.append(txt)
            elif block_type == "tool_use":
                tool_name = block.get("name", "unknown")
                if tool_name not in tools:
                    tools.append(tool_name)
            # Skip other types

    return "\n\n".join(texts), tools


# ---------------------------------------------------------------------------
# Stats mode — pricing
# ---------------------------------------------------------------------------

_PRICING_URL = "https://platform.claude.com/docs/en/docs/about-claude/pricing"
_PRICING_CACHE_FILE = f"/tmp/claude-model-pricing-{os.getuid()}.json"
_PRICING_CACHE_TTL = 86400  # 24 hours

# Fallback pricing per 1M tokens: {key: {"input", "output", "cache_write", "cache_read"}}
# Used only when both fetch and cache fail.
# Source: https://platform.claude.com/docs/en/docs/about-claude/pricing (Feb 2026)
FALLBACK_PRICING = {
    "opus-4.6":   {"input": 5.0,  "output": 25.0, "cache_write": 6.25,  "cache_read": 0.50},
    "opus-4.5":   {"input": 5.0,  "output": 25.0, "cache_write": 6.25,  "cache_read": 0.50},
    "sonnet-4.6": {"input": 3.0,  "output": 15.0, "cache_write": 3.75,  "cache_read": 0.30},
    "sonnet-4.5": {"input": 3.0,  "output": 15.0, "cache_write": 3.75,  "cache_read": 0.30},
    "haiku-4.5":  {"input": 1.0,  "output": 5.0,  "cache_write": 1.25,  "cache_read": 0.10},
    # Claude 3.x legacy
    "opus-3":     {"input": 15.0, "output": 75.0, "cache_write": 18.75, "cache_read": 1.50},
    "sonnet-3":   {"input": 3.0,  "output": 15.0, "cache_write": 3.75,  "cache_read": 0.30},
    "haiku-3":    {"input": 0.25, "output": 1.25,  "cache_write": 0.30,  "cache_read": 0.03},
}


def fetch_pricing() -> dict | None:
    """Fetch pricing from platform.claude.com pricing page (SSR HTML).

    Parses the HTML table with columns:
      Model | Base Input | 5m Cache Writes | 1h Cache Writes | Cache Hits | Output
    Returns dict like FALLBACK_PRICING, or None on failure.
    """
    try:
        req = urllib.request.Request(
            _PRICING_URL,
            headers={"User-Agent": "retroscope-find-sessions/1.0"},
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            html = resp.read().decode("utf-8", errors="replace")
    except Exception:
        return None

    row_re = re.compile(r"<tr[^>]*>(.*?)</tr>", re.DOTALL)
    td_re = re.compile(r"<td[^>]*>(.*?)</td>", re.DOTALL)
    tag_re = re.compile(r"<[^>]+>")
    price_re = re.compile(r"\$([0-9.]+)\s*/\s*MTok")

    pricing = {}
    for row_match in row_re.finditer(html):
        row_html = row_match.group(1)
        cells = td_re.findall(row_html)
        if len(cells) < 6:
            continue

        cells_text = [tag_re.sub("", c).strip() for c in cells]
        model_cell = cells_text[0]
        if not model_cell.startswith("Claude "):
            continue

        prices = []
        for cell in cells_text[1:6]:
            m = price_re.search(cell)
            prices.append(float(m.group(1)) if m else None)

        if len(prices) < 5 or None in prices:
            continue

        # "Claude Opus 4.6" -> "opus-4.6"; "Claude Opus 4" -> "opus-4"
        name_match = re.match(r"Claude\s+(\w+)\s+([\d.]+)", model_cell)
        if not name_match:
            continue
        key = f"{name_match.group(1).lower()}-{name_match.group(2)}"

        # Columns: Base Input | 5m Cache Writes | 1h Cache Writes | Cache Hits | Output
        pricing[key] = {
            "input": prices[0],
            "cache_write": prices[1],
            "cache_read": prices[3],
            "output": prices[4],
        }

    return pricing if pricing else None


def load_pricing() -> tuple[dict, str]:
    """Load pricing: try cache → fetch from web → fall back to hardcoded.

    Returns (pricing_dict, source) where source is "cached", "fetched", or "static".
    """
    # 1. Check cache file (valid for 24h)
    try:
        if os.path.exists(_PRICING_CACHE_FILE):
            mtime = os.stat(_PRICING_CACHE_FILE).st_mtime
            if time.time() - mtime < _PRICING_CACHE_TTL:
                with open(_PRICING_CACHE_FILE) as f:
                    cached = json.load(f)
                if isinstance(cached.get("models"), dict) and cached["models"]:
                    return cached["models"], "cached"
    except (OSError, json.JSONDecodeError) as e:
        # Cache read failure is non-fatal; we'll fall back to fetching or static pricing.
        print(f"Warning: failed to read pricing cache '{_PRICING_CACHE_FILE}': {e}", file=sys.stderr)

    # 2. Fetch fresh pricing from Anthropic docs
    fetched = fetch_pricing()
    if fetched:
        try:
            with open(_PRICING_CACHE_FILE, "w") as f:
                json.dump({
                    "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "models": fetched,
                }, f)
        except Exception:
            pass  # cache write failure is non-fatal
        return fetched, "fetched"

    # 3. Hardcoded fallback
    return FALLBACK_PRICING, "static"


def match_model_to_pricing(model_id: str, pricing: dict) -> tuple[dict | None, str]:
    """Match a full model ID to the best pricing entry.

    model_id examples: "claude-sonnet-4-6-20250514", "claude-opus-4-6"
    pricing keys: "sonnet-4.6", "opus-4.6", "haiku-4.5", etc.

    Returns (pricing_entry, matched_key) or (None, "") if no match.
    """
    model_lower = model_id.lower()

    # Extract family and version from model ID
    # Patterns: claude-{family}-{major}-{minor}[-date] or claude-{family}-{major}
    family_match = re.search(r"claude-(opus|sonnet|haiku)-(\d+)-?(\d+)?", model_lower)
    if family_match:
        family = family_match.group(1)
        major = family_match.group(2)
        minor = family_match.group(3)
        if minor:
            # Try exact version match first
            key = f"{family}-{major}.{minor}"
            if key in pricing:
                return pricing[key], key
        # Try major-only match (e.g. "sonnet-4" matches "sonnet-4.6")
        prefix = f"{family}-{major}."
        candidates = [k for k in pricing if k.startswith(prefix)]
        if candidates:
            # Pick highest version
            best = sorted(candidates, key=lambda k: float(k.split("-")[1]))[-1]
            return pricing[best], best

    # Fallback: family keyword match
    for family in ("opus", "sonnet", "haiku"):
        if family in model_lower:
            candidates = [k for k in pricing if k.startswith(family + "-")]
            if candidates:
                best = sorted(candidates, key=lambda k: float(k.split("-")[1]))[-1]
                return pricing[best], best

    return None, ""


def get_stats(jsonl_file: str):
    """
    Compute session statistics and output as JSON.
    Returns: message_counts, token_usage, tool_counts, time_range, branches, models
    """
    tz = get_timezone(None)

    stats = {
        "file": jsonl_file,
        "session_id": None,
        "slug": None,
        "cwd": None,
        "branches": [],
        "models": [],
        "time_range": {"start": None, "end": None, "duration_minutes": None},
        "message_counts": {"user": 0, "assistant": 0, "progress": 0, "other": 0},
        "token_usage": {
            "input_tokens": 0,
            "output_tokens": 0,
            "cache_creation_input_tokens": 0,
            "cache_read_input_tokens": 0,
        },
        "tool_counts": {},
    }

    first_ts = None
    last_ts = None
    branches_set = set()
    models_set = set()

    try:
        with open(jsonl_file, errors="ignore") as f:
            lines = f.readlines()
    except OSError as e:
        sys.stderr.write(f"Error reading {jsonl_file}: {e}\n")
        print(json.dumps(stats))
        return

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        # Collect metadata from any record
        if not stats["session_id"] and obj.get("sessionId"):
            stats["session_id"] = obj["sessionId"]
        if not stats["slug"] and obj.get("slug"):
            stats["slug"] = obj["slug"]
        if not stats["cwd"] and obj.get("cwd"):
            stats["cwd"] = obj["cwd"]
        if obj.get("gitBranch"):
            branches_set.add(obj["gitBranch"])

        ts = parse_timestamp(obj.get("timestamp"), tz)
        if ts:
            if first_ts is None or ts < first_ts:
                first_ts = ts
            if last_ts is None or ts > last_ts:
                last_ts = ts

        msg_type = obj.get("type", "other")

        if msg_type == "user":
            stats["message_counts"]["user"] += 1

        elif msg_type == "assistant":
            stats["message_counts"]["assistant"] += 1

            message = obj.get("message", {})
            # Model
            model = message.get("model")
            if model:
                models_set.add(model)

            # Usage
            usage = message.get("usage", {})
            for key in ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"):
                val = usage.get(key, 0)
                if isinstance(val, (int, float)):
                    stats["token_usage"][key] += int(val)

            # Tool calls
            content = message.get("content", [])
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_use":
                        tool_name = block.get("name", "unknown")
                        stats["tool_counts"][tool_name] = stats["tool_counts"].get(tool_name, 0) + 1

        elif msg_type == "progress":
            stats["message_counts"]["progress"] += 1

        else:
            stats["message_counts"]["other"] += 1

    # Finalize
    stats["branches"] = sorted(branches_set)
    stats["models"] = sorted(models_set)

    if first_ts:
        stats["time_range"]["start"] = first_ts.isoformat()
    if last_ts:
        stats["time_range"]["end"] = last_ts.isoformat()
    if first_ts and last_ts:
        duration = (last_ts - first_ts).total_seconds() / 60
        stats["time_range"]["duration_minutes"] = round(duration, 1)

    # Estimate cost using dynamic pricing (fetched or cached), fallback to hardcoded
    pricing_dict, pricing_source = load_pricing()

    # Per-message per-model cost: re-read file for accurate weighted calculation
    actual_cost = 0.0
    naive_cost = 0.0  # Claude Code style: all input tokens at full input rate
    cost_model_used = ""
    try:
        with open(jsonl_file, errors="ignore") as f2:
            for line2 in f2:
                line2 = line2.strip()
                if not line2:
                    continue
                try:
                    obj2 = json.loads(line2)
                except json.JSONDecodeError:
                    continue
                msg2 = obj2.get("message", {})
                model2 = msg2.get("model", "")
                usage2 = msg2.get("usage", {})
                if not model2 or not usage2:
                    continue

                entry, key = match_model_to_pricing(model2, pricing_dict)
                if entry is None:
                    continue
                if not cost_model_used:
                    cost_model_used = key

                inp = usage2.get("input_tokens", 0)
                out = usage2.get("output_tokens", 0)
                cw = usage2.get("cache_creation_input_tokens", 0)
                cr = usage2.get("cache_read_input_tokens", 0)

                # Actual cost: each token type at its real rate
                actual_cost += (
                    inp * entry["input"]       / 1_000_000
                    + out * entry["output"]    / 1_000_000
                    + cw * entry["cache_write"] / 1_000_000
                    + cr * entry["cache_read"]  / 1_000_000
                )
                # Naive cost: all input tokens at full input rate (no cache discount)
                naive_cost += (
                    (inp + cw + cr) * entry["input"] / 1_000_000
                    + out * entry["output"]           / 1_000_000
                )
    except OSError:
        pass

    stats["estimated_cost_usd"] = round(actual_cost, 4)
    stats["naive_cost_usd"] = round(naive_cost, 4)
    stats["pricing_model"] = cost_model_used or "unknown"
    stats["pricing_source"] = pricing_source

    print(json.dumps(stats, indent=2))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Session discovery and content extraction for retroscope"
    )

    # Mutually exclusive modes
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        "--extract",
        metavar="SESSION_FILE",
        help="Extract text from session JSONL file"
    )
    mode_group.add_argument(
        "--stats",
        metavar="SESSION_FILE",
        help="Compute session statistics (JSON output)"
    )

    # List mode positional
    parser.add_argument(
        "date",
        nargs="?",
        help="Date filter: today, yesterday, YYYY-MM-DD, or YYYY-MM-DD:YYYY-MM-DD"
    )

    # Common options
    parser.add_argument("--project-dir", help="Project directory (default: cwd)")
    parser.add_argument("--tz", help="Timezone name (default: system timezone)")
    parser.add_argument("--date", dest="date_filter", help="Date filter for --extract mode (YYYY-MM-DD)")

    args = parser.parse_args()

    if args.extract:
        extract_session(args.extract, args.date_filter)
    elif args.stats:
        get_stats(args.stats)
    elif args.date:
        find_sessions(args.date, args.project_dir, args.tz)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
