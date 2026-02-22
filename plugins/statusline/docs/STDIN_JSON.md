# Statusline stdin JSON Reference

Claude Code pipes JSON to `statusline.sh` via stdin after every assistant message. This document describes all available fields.

**Source:** [Official Claude Code documentation](https://code.claude.com/docs/en/statusline)

## JSON Structure

```json
{
  "session_id": "0f860c2c-8864-42ee-896c-702d4c8f587b",
  "transcript_path": "/home/user/.claude/projects/.../session.jsonl",
  "cwd": "/home/user/devel/my-project",
  "version": "2.1.49",
  "output_style": { "name": "default" },
  "model": {
    "id": "claude-sonnet-4-6",
    "display_name": "Sonnet 4.6"
  },
  "workspace": {
    "current_dir": "/home/user/devel/my-project",
    "project_dir": "/home/user/devel/my-project",
    "added_dirs": []
  },
  "cost": {
    "total_cost_usd": 0.913,
    "total_duration_ms": 2565946,
    "total_api_duration_ms": 87270,
    "total_lines_added": 1,
    "total_lines_removed": 0
  },
  "context_window": {
    "context_window_size": 200000,
    "used_percentage": 34,
    "remaining_percentage": 66,
    "total_input_tokens": 6100,
    "total_output_tokens": 2992,
    "current_usage": {
      "input_tokens": 3,
      "output_tokens": 90,
      "cache_creation_input_tokens": 48,
      "cache_read_input_tokens": 68222
    }
  },
  "exceeds_200k_tokens": false
}
```

## Fields

### General

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Unique session identifier |
| `transcript_path` | string | Path to the session transcript `.jsonl` file |
| `cwd` | string | Current working directory (same as `workspace.current_dir`) |
| `version` | string | Claude Code version |
| `output_style.name` | string | Current output style name |

### `model`

| Field | Type | Description |
|-------|------|-------------|
| `model.id` | string | Model identifier (e.g. `claude-sonnet-4-6`) |
| `model.display_name` | string | Display name (e.g. `Sonnet 4.6`) |

### `workspace`

| Field | Type | Description |
|-------|------|-------------|
| `workspace.current_dir` | string | Current working directory. May change during a session |
| `workspace.project_dir` | string | Directory where Claude Code was launched. Stays constant throughout the session |
| `workspace.added_dirs` | array | Directories added via `/add-dir` |

### `cost`

| Field | Type | Description |
|-------|------|-------------|
| `cost.total_cost_usd` | float | Total session cost in USD (cumulative) |
| `cost.total_duration_ms` | int | Total wall-clock time since session start in ms (includes idle time between messages) |
| `cost.total_api_duration_ms` | int | Total time spent waiting for API responses in ms |
| `cost.total_lines_added` | int | Lines of code added during the session (via Write/Edit) |
| `cost.total_lines_removed` | int | Lines of code removed during the session |

### `context_window`

| Field | Type | Description |
|-------|------|-------------|
| `context_window.context_window_size` | int | Maximum context window size in tokens. `200000` for standard models, `1000000` for extended context |
| `context_window.used_percentage` | int\|null | Pre-calculated context usage percentage. `null` before the first API call |
| `context_window.remaining_percentage` | int\|null | Remaining context percentage. `null` before the first API call |
| `context_window.total_input_tokens` | int | Cumulative input token count across the entire session. **May exceed `context_window_size`** — do not use for current context state |
| `context_window.total_output_tokens` | int | Cumulative output token count across the entire session |
| `context_window.current_usage` | object\|null | Token counts from the **most recent** API call. `null` before the first call |
| `context_window.current_usage.input_tokens` | int | Input tokens in the last request |
| `context_window.current_usage.output_tokens` | int | Output tokens in the last request |
| `context_window.current_usage.cache_creation_input_tokens` | int | Tokens written to prompt cache in the last request |
| `context_window.current_usage.cache_read_input_tokens` | int | Tokens read from prompt cache in the last request |

**`used_percentage` formula:**
```
used = input_tokens + cache_creation_input_tokens + cache_read_input_tokens
used_percentage = used / context_window_size * 100
```
Output tokens are **not included**. Use the same formula when calculating manually.

### `exceeds_200k_tokens`

| Field | Type | Description |
|-------|------|-------------|
| `exceeds_200k_tokens` | bool | Whether the total token count (input + cache + output) from the most recent API response exceeds **200,000**. Fixed threshold regardless of the model's actual context window size |

## Conditionally present fields

Some fields only appear under specific conditions:

| Field | Condition |
|-------|-----------|
| `vim.mode` | Only when vim mode is enabled (`NORMAL` or `INSERT`) |
| `agent.name` | Only when running with `--agent` flag or agent settings configured |

## Update timing

The script runs after each assistant message, when permission mode changes, or when vim mode toggles. Updates are debounced at 300ms. If a new update triggers while the script is still running, the in-flight execution is cancelled.
