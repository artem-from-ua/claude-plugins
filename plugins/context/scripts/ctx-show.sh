#!/usr/bin/env bash
# ctx-show.sh — assemble full Claude Code session context in load order
# Usage: ctx-show.sh [--file|--stdout]
#
# Sources (in load order):
#   1. ~/.claude/CLAUDE.md              — global user instructions
#   2. {project}/CLAUDE.md              — project instructions
#   3. ~/.claude/projects/{hash}/memory/MEMORY.md — auto-memory
#   4. Global SessionStart hooks        — from ~/.claude/settings.json
#   5. Project SessionStart hooks       — from {project}/.claude/settings.json
#   6. Plugin SessionStart hooks        — enabled plugins in cache
#   7. Skills                           — SKILL.md listings (user, plugin, project)
#
# Summary table is printed to stderr after content output.

set -euo pipefail

MODE="${1:---file}"
CLAUDE_DIR="${HOME}/.claude"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
OUTPUT=""
# Auto-detect context window: 1M for known 1M-capable models, 200K fallback
if [ -z "${CTX_CONTEXT_WINDOW:-}" ]; then
  _model="${CLAUDE_MODEL:-${ANTHROPIC_MODEL:-}}"
  case "$_model" in
    *"[1m]"*|*"-1m-"*) CTX_CONTEXT_WINDOW=1000000 ;;
    *) CTX_CONTEXT_WINDOW=200000 ;;
  esac
fi
CTX_WARN_THRESHOLD="${CTX_WARN_THRESHOLD:-$(( CTX_CONTEXT_WINDOW * 3 / 100 ))}"

# ── API token counting ──────────────────────────────────────────────────────
USE_API=0
CTX_TOKEN_MODEL="${CTX_TOKEN_MODEL:-claude-sonnet-4-6}"
if [ -n "${ANTHROPIC_API_KEY:-}" ] && command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  USE_API=1
fi

# ── metadata arrays ───────────────────────────────────────────────────────────
# Parallel arrays (bash 3.2 compatible — no associative arrays)
TBL_SCOPE=()    # "User" or "Project"
TBL_TYPE=()     # "CLAUDE.md", "Memory", "Plugin hook", "Playbook Preset"
TBL_SOURCE=()   # display identifier (full shortened path or plugin id)
TBL_STATUS=()   # "ok", "missing", "empty", "failed"
TBL_LINES=()    # integer
TBL_BYTES=()    # integer (byte count for heuristic estimation)
TBL_CONTENT=()  # raw text for API token counting

# ── helpers ───────────────────────────────────────────────────────────────────

# shorten_path: replace $PROJECT_DIR/ → ./  and $HOME/ → ~/  (no truncation)
# Note: PROJECT_DIR check must come before HOME check — PROJECT_DIR is inside HOME,
# so checking HOME first would turn it into ~/rel/path which no longer matches PROJECT_DIR.
shorten_path() {
  local path="$1"
  # Replace PROJECT_DIR prefix first (more specific)
  if [[ "$path" == "$PROJECT_DIR/"* ]]; then
    path="./${path#$PROJECT_DIR/}"
  # Replace HOME prefix only if not already a project-relative path
  elif [[ "$path" == "$HOME/"* ]]; then
    path="~/${path#$HOME/}"
  fi
  echo "$path"
}

count_lines() {
  local content="$1"
  if [ -z "$content" ]; then
    echo 0
  else
    echo "$content" | wc -l | tr -d ' '
  fi
}

count_tokens_api() {
  local content="$1"
  local json response token_count
  json=$(jq -n --arg text "$content" --arg model "$CTX_TOKEN_MODEL" \
    '{model: $model, messages: [{role: "user", content: $text}]}') || return 1
  response=$(curl -s --connect-timeout 2 --max-time 5 \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "content-type: application/json" \
    -H "anthropic-version: 2023-06-01" \
    -d "$json" \
    "https://api.anthropic.com/v1/messages/count_tokens" 2>/dev/null) || return 1
  token_count=$(echo "$response" | jq -r '.input_tokens // empty' 2>/dev/null) || return 1
  [ -n "$token_count" ] && echo "$token_count" || return 1
}

record_meta() {
  local scope="$1"
  local type="$2"
  local source="$3"
  local status="$4"
  local content="$5"
  local lines byte_count
  lines=$(count_lines "$content")
  byte_count=$(printf '%s' "$content" | wc -c | tr -d ' ')
  TBL_SCOPE+=("$scope")
  TBL_TYPE+=("$type")
  TBL_SOURCE+=("$source")
  TBL_STATUS+=("$status")
  TBL_LINES+=("$lines")
  TBL_BYTES+=("$byte_count")
  TBL_CONTENT+=("$content")
}

extract_skill_meta() {
  local skill_md="$1"
  awk '
    /^---$/ { fm++; next }
    fm == 1 && /^name:/ { gsub(/^name: */, ""); name = $0 }
    fm == 1 && /^description:/ {
      gsub(/^description: *>? */, "")
      if ($0 != "") desc = $0
      indesc = 1; next
    }
    fm == 1 && indesc && /^  / { gsub(/^  +/, ""); desc = desc " " $0; next }
    fm == 1 && indesc && !/^  / { indesc = 0 }
    fm == 2 { exit }
    END { printf "%s|%s", name, desc }
  ' "$skill_md"
}

append_source() {
  local label="$1"
  local path="$2"
  local scope="$3"
  local type="$4"
  local short_path
  short_path=$(shorten_path "$path")

  OUTPUT+=$'\n'"<!-- Source: ${label} -->"$'\n'
  if [ -f "$path" ]; then
    local content
    content=$(cat "$path")
    OUTPUT+=$'\n'"${content}"$'\n'
    record_meta "$scope" "$type" "$short_path" "ok" "$content"
  else
    OUTPUT+="<!-- (not found: ${path}) -->"$'\n'
    record_meta "$scope" "$type" "$short_path" "missing" ""
  fi
}

# append_command_output: run a command and capture its output.
# If output contains <!-- Source: Plugin playbook@... Preset NAME --> markers,
# split into individual preset rows. Otherwise record as a single hook row.
# Args: label cmd plugin_id scope hook_type
append_command_output() {
  local label="$1"
  local cmd="$2"
  local plugin_id="$3"   # e.g. "plantuml@tribe-coding (v1.6.0)"
  local scope="${4:-Project}"
  local hook_type="${5:-Plugin hook}"

  OUTPUT+=$'\n'"<!-- Source: ${label} -->"$'\n'
  local result exit_code
  exit_code=0
  result=$(eval "$cmd" 2>&1) || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    OUTPUT+="<!-- (command failed: ${cmd}) -->"$'\n'
    record_meta "$scope" "$hook_type" "$plugin_id" "failed" ""
    return
  fi

  if [ -z "$result" ]; then
    OUTPUT+="<!-- (no output) -->"$'\n'
    record_meta "$scope" "$hook_type" "$plugin_id" "empty" ""
    return
  fi

  OUTPUT+=$'\n'"${result}"$'\n'

  # Check for playbook preset markers in output
  # Marker format: <!-- Source: Plugin playbook@tribe-coding (vX.Y.Z) Preset NAME -->
  if echo "$result" | grep -q '<!-- Source: Plugin playbook@[^ ]* (v[^)]*) Preset '; then
    # Split output by preset markers and record each preset separately
    local current_name=""
    local current_content=""
    local playbook_id=""

    while IFS= read -r line; do
      local preset_name
      preset_name=$(echo "$line" | sed -n 's/.*Preset \([^ ]*\) -->.*/\1/p')
      local pid
      pid=$(echo "$line" | sed -n 's/.*Plugin \([^ ]* ([^)]*)\) Preset.*/\1/p')

      if [ -n "$preset_name" ]; then
        # Save previous preset if any
        if [ -n "$current_name" ] && [ -n "$playbook_id" ]; then
          record_meta "Project" "Playbook Preset" "${playbook_id} · ${current_name}" "ok" "$current_content"
        fi
        current_name="$preset_name"
        current_content=""
        playbook_id="$pid"
      else
        if [ -n "$current_name" ]; then
          current_content+="${line}"$'\n'
        fi
      fi
    done <<< "$result"

    # Save last preset
    if [ -n "$current_name" ] && [ -n "$playbook_id" ]; then
      record_meta "Project" "Playbook Preset" "${playbook_id} · ${current_name}" "ok" "$current_content"
    fi
  else
    # Regular hook — record as single row
    record_meta "$scope" "$hook_type" "$plugin_id" "ok" "$result"
  fi
}

# ── print_table — markdown format ────────────────────────────────────────────
print_table() {
  local total_tokens=0
  local total_lines=0
  local -a tokens=()
  local i
  local api_failed=0
  local token_mode="heuristic"

  if [ "$USE_API" -eq 1 ]; then
    token_mode="api"
  fi

  for i in "${!TBL_BYTES[@]}"; do
    local t
    if [ "$token_mode" = "api" ] && [ "$api_failed" -eq 0 ] && [ "${TBL_STATUS[i]}" = "ok" ] && [ "${TBL_BYTES[i]}" -gt 0 ]; then
      if t=$(count_tokens_api "${TBL_CONTENT[i]}"); then
        tokens+=("$t")
      else
        api_failed=1
        token_mode="api_failed"
        t=$(( TBL_BYTES[i] * 10 / 38 ))
        tokens+=("$t")
      fi
    else
      t=$(( TBL_BYTES[i] * 10 / 38 ))
      tokens+=("$t")
    fi
    total_tokens=$(( total_tokens + t ))
    total_lines=$(( total_lines + TBL_LINES[i] ))
  done

  local token_header="~Tokens"
  if [ "$token_mode" = "api" ]; then
    token_header="Tokens"
  fi

  printf '| Scope | Type | Source/ID | Lines | %s | Context%% |\n' "$token_header"
  printf '|-------|------|-----------|------:|--------:|---------:|\n'

  local has_skills=0

  for i in "${!TBL_SCOPE[@]}"; do
    local scope_label type_label ctx_pct lines_cell tokens_cell ctx_cell
    local scope="${TBL_SCOPE[i]}"
    local type="${TBL_TYPE[i]}"
    local source="${TBL_SOURCE[i]}"
    local status="${TBL_STATUS[i]}"
    local lines="${TBL_LINES[i]}"
    local tok="${tokens[i]}"

    # Skip hooks/skills that produced no output (empty or missing — not errors)
    if { [ "$type" = "Plugin hook" ] || [ "$type" = "User hook" ] || [ "$type" = "Project hook" ] || [ "$type" = "Skill" ]; } && \
       { [ "$status" = "empty" ] || [ "$status" = "missing" ]; }; then
      continue
    fi

    case "$scope" in
      User)    scope_label="User" ;;
      Project) scope_label="Project" ;;
      *)       scope_label="$scope" ;;
    esac

    case "$type" in
      "CLAUDE.md")       type_label="CLAUDE.md" ;;
      "Memory")          type_label="Memory" ;;
      "Plugin hook")     type_label="Plugin hook" ;;
      "User hook")       type_label="User hook" ;;
      "Project hook")    type_label="Project hook" ;;
      "Playbook Preset") type_label="Playbook Preset" ;;
      "Skill")           type_label="Skill"; has_skills=1 ;;
      *)                 type_label="$type" ;;
    esac

    # Lines / Tokens / Context% columns
    case "$status" in
      ok)
        if [ "$total_tokens" -gt 0 ]; then
          ctx_pct=$(( 100 * tok / total_tokens ))
        else
          ctx_pct=0
        fi
        lines_cell="$lines"
        tokens_cell="$tok"
        ctx_cell="${ctx_pct}%"
        ;;
      missing)
        lines_cell="no file"
        tokens_cell=""
        ctx_cell=""
        ;;
      failed)
        lines_cell="script error"
        tokens_cell=""
        ctx_cell=""
        ;;
      *)
        lines_cell="$lines"
        tokens_cell="$tok"
        ctx_cell=""
        ;;
    esac

    printf '| %s | %s | %s | %s | %s | %s |\n' \
      "$scope_label" "$type_label" "$source" "$lines_cell" "$tokens_cell" "$ctx_cell"
  done

  printf '| | **TOTAL** | | **%d** | **%d** | **100%%** |\n' \
    "$total_lines" "$total_tokens"

  if [ "$total_tokens" -gt "$CTX_WARN_THRESHOLD" ]; then
    printf '\n⚠️  Context load (%d tokens) exceeds threshold (%d tokens = %d%% of %dk context window)\n' \
      "$total_tokens" "$CTX_WARN_THRESHOLD" \
      "$(( 100 * CTX_WARN_THRESHOLD / CTX_CONTEXT_WINDOW ))" \
      "$(( CTX_CONTEXT_WINDOW / 1000 ))"
  fi

  if [ "$has_skills" -eq 1 ]; then
    printf '\nSkills: names + descriptions loaded at session start (full SKILL.md on-demand)\n'
  fi

  case "$token_mode" in
    api)
      printf '\nToken counts: exact (Anthropic count_tokens API)\n'
      ;;
    api_failed)
      printf '\nToken counts: estimated (API error, fell back to bytes/3.8)\n'
      ;;
    heuristic)
      printf '\nToken counts: estimated (bytes/3.8; set ANTHROPIC_API_KEY for exact)\n'
      ;;
  esac
}

# ── 1. Global CLAUDE.md ───────────────────────────────────────────────────────

append_source "~/.claude/CLAUDE.md (global user instructions)" \
  "${CLAUDE_DIR}/CLAUDE.md" \
  "User" "CLAUDE.md"

# ── 2. Project CLAUDE.md ─────────────────────────────────────────────────────

PROJECT_CLAUDE="${PROJECT_DIR}/CLAUDE.md"
append_source "${PROJECT_DIR}/CLAUDE.md (project instructions)" \
  "${PROJECT_CLAUDE}" \
  "Project" "CLAUDE.md"

# ── 3. Auto-memory MEMORY.md ─────────────────────────────────────────────────

# Project path hash: replace / with - (same encoding Claude Code uses)
# Note: leading slash becomes leading dash — do NOT strip it (Claude Code keeps it)
PROJECT_HASH=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
MEMORY_FILE="${CLAUDE_DIR}/projects/${PROJECT_HASH}/memory/MEMORY.md"
append_source "~/.claude/projects/${PROJECT_HASH}/memory/MEMORY.md (auto-memory)" \
  "${MEMORY_FILE}" \
  "Project" "Memory"

# ── 4. Global SessionStart hooks from settings.json ──────────────────────────

SETTINGS="${CLAUDE_DIR}/settings.json"
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  # Extract SessionStart hook commands from global settings
  HOOK_COMMANDS=$(jq -r '
    .hooks.SessionStart[]?.hooks[]?
    | select(.type == "command")
    | .command
  ' "$SETTINGS" 2>/dev/null || true)

  if [ -n "$HOOK_COMMANDS" ]; then
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      # Expand common variables
      cmd_expanded="${cmd/\${HOME}/$HOME}"
      cmd_expanded="${cmd_expanded/\~/$HOME}"
      # Source/ID: settings.json path · script name
      hook_script=$(echo "$cmd_expanded" | grep -oE '[^/ ]+\.(py|sh)' | tail -1)
      local_id="~/.claude/settings.json · ${hook_script}"
      append_command_output "Global SessionStart hook: ${cmd}" "${cmd_expanded}" "$local_id" "User" "User hook"
    done <<< "$HOOK_COMMANDS"
  else
    OUTPUT+=$'\n'"<!-- Source: Global SessionStart hooks -->"$'\n'"<!-- (none configured in ${SETTINGS}) -->"$'\n'
  fi
else
  OUTPUT+=$'\n'"<!-- Source: Global SessionStart hooks -->"$'\n'"<!-- (settings.json not found or jq not available) -->"$'\n'
fi

# ── 5. Project SessionStart hooks from .claude/settings.json ─────────────────

PROJECT_SETTINGS="${PROJECT_DIR}/.claude/settings.json"
if [ -f "$PROJECT_SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  PROJ_HOOK_COMMANDS=$(jq -r '
    .hooks.SessionStart[]?.hooks[]?
    | select(.type == "command")
    | .command
  ' "$PROJECT_SETTINGS" 2>/dev/null || true)

  if [ -n "$PROJ_HOOK_COMMANDS" ]; then
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      cmd_expanded="${cmd/\${HOME}/$HOME}"
      cmd_expanded="${cmd_expanded/\~/$HOME}"
      hook_script=$(echo "$cmd_expanded" | grep -oE '[^/ ]+\.(py|sh)' | tail -1)
      proj_id="./.claude/settings.json · ${hook_script}"
      append_command_output "Project SessionStart hook: ${cmd}" "${cmd_expanded}" "$proj_id" "Project" "Project hook"
    done <<< "$PROJ_HOOK_COMMANDS"
  else
    OUTPUT+=$'\n'"<!-- Source: Project SessionStart hooks -->"$'\n'"<!-- (none configured in ${PROJECT_SETTINGS}) -->"$'\n'
  fi
else
  OUTPUT+=$'\n'"<!-- Source: Project SessionStart hooks -->"$'\n'"<!-- (.claude/settings.json not found in project) -->"$'\n'
fi

# ── 6. Plugin SessionStart hooks ─────────────────────────────────────────────

CACHE_DIR="${CLAUDE_DIR}/plugins/cache"

if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1 && [ -d "$CACHE_DIR" ]; then
  # Get enabled plugins: keys of enabledPlugins where value is true
  ENABLED_PLUGINS=$(jq -r '
    .enabledPlugins // {} | to_entries[]
    | select(.value == true)
    | .key
  ' "$SETTINGS" 2>/dev/null || true)

  if [ -n "$ENABLED_PLUGINS" ]; then
    while IFS= read -r plugin_key; do
      [ -z "$plugin_key" ] && continue

      # plugin_key format: "pluginname@marketplace"
      PLUGIN_NAME="${plugin_key%%@*}"
      MARKETPLACE="${plugin_key##*@}"

      PLUGIN_CACHE="${CACHE_DIR}/${MARKETPLACE}/${PLUGIN_NAME}"
      if [ ! -d "$PLUGIN_CACHE" ]; then
        OUTPUT+=$'\n'"<!-- Source: Plugin ${plugin_key} SessionStart hooks -->"$'\n'"<!-- (cache directory not found: ${PLUGIN_CACHE}) -->"$'\n'
        record_meta "Project" "Plugin hook" "${plugin_key}" "missing" ""
        continue
      fi

      # Find highest semver version directory
      LATEST_VERSION=$(ls "$PLUGIN_CACHE" 2>/dev/null \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -t. -k1,1n -k2,2n -k3,3n \
        | tail -1)

      if [ -z "$LATEST_VERSION" ]; then
        OUTPUT+=$'\n'"<!-- Source: Plugin ${plugin_key} SessionStart hooks -->"$'\n'"<!-- (no versioned cache found in ${PLUGIN_CACHE}) -->"$'\n'
        record_meta "Project" "Plugin hook" "${plugin_key}" "missing" ""
        continue
      fi

      PLUGIN_ROOT="${PLUGIN_CACHE}/${LATEST_VERSION}"
      HOOKS_FILE="${PLUGIN_ROOT}/hooks/hooks.json"
      PLUGIN_ID="${PLUGIN_NAME}@${MARKETPLACE} (v${LATEST_VERSION})"

      if [ ! -f "$HOOKS_FILE" ]; then
        OUTPUT+=$'\n'"<!-- Source: Plugin ${plugin_key} (v${LATEST_VERSION}) SessionStart hooks -->"$'\n'"<!-- (no hooks.json found) -->"$'\n'
        record_meta "Project" "Plugin hook" "$PLUGIN_ID" "missing" ""
        continue
      fi

      # Extract SessionStart hook commands
      PLUGIN_HOOKS=$(jq -r '
        .hooks.SessionStart[]?.hooks[]?
        | select(.type == "command")
        | .command
      ' "$HOOKS_FILE" 2>/dev/null || true)

      if [ -z "$PLUGIN_HOOKS" ]; then
        OUTPUT+=$'\n'"<!-- Source: Plugin ${plugin_key} (v${LATEST_VERSION}) SessionStart hooks -->"$'\n'"<!-- (no SessionStart hooks) -->"$'\n'
        record_meta "Project" "Plugin hook" "$PLUGIN_ID" "empty" ""
        continue
      fi

      while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        # Replace ${CLAUDE_PLUGIN_ROOT} with actual plugin root
        cmd_expanded="${cmd/\$\{CLAUDE_PLUGIN_ROOT\}/$PLUGIN_ROOT}"
        # Include script basename in ID so multiple hooks from same plugin are distinguishable
        # Extract the .sh filename from the command (handles quoted paths)
        HOOK_SCRIPT=$(echo "$cmd_expanded" | sed 's/.*\/\([^/]*\)\.sh.*/\1/')
        HOOK_ID="${PLUGIN_NAME}@${MARKETPLACE} (v${LATEST_VERSION}) · ${HOOK_SCRIPT}"
        append_command_output \
          "Plugin ${plugin_key} (v${LATEST_VERSION}) SessionStart: ${cmd}" \
          "${cmd_expanded}" \
          "$HOOK_ID"
      done <<< "$PLUGIN_HOOKS"

    done <<< "$ENABLED_PLUGINS"
  else
    OUTPUT+=$'\n'"<!-- Source: Plugin SessionStart hooks -->"$'\n'"<!-- (no enabled plugins) -->"$'\n'
  fi
else
  OUTPUT+=$'\n'"<!-- Source: Plugin SessionStart hooks -->"$'\n'"<!-- (settings.json not found, jq not available, or cache directory missing) -->"$'\n'
fi

# ── 7. Skill listings ─────────────────────────────────────────────────────────
# Skills are loaded at session start as a compact listing (name + description).
# We approximate that listing for token counting.

SEEN_SKILLS=""  # track absolute paths to avoid duplicates

record_skill() {
  local skill_md="$1"
  local scope="$2"
  local source_id="$3"

  # Deduplicate by absolute path
  local abs_path
  abs_path=$(cd "$(dirname "$skill_md")" && pwd)/$(basename "$skill_md") 2>/dev/null || return
  case "$SEEN_SKILLS" in
    *"|${abs_path}|"*) return ;;
  esac
  SEEN_SKILLS+="|${abs_path}|"

  local meta name desc listing
  meta=$(extract_skill_meta "$skill_md")
  name="${meta%%|*}"
  desc="${meta#*|}"

  # Skip if name is empty (malformed SKILL.md)
  [ -z "$name" ] && return

  listing="- ${name}: ${desc}"
  record_meta "$scope" "Skill" "$source_id" "ok" "$listing"
}

# 7a. User skills — ~/.claude/commands/ and ~/.claude/skills/
for user_skill_dir in "${CLAUDE_DIR}/commands" "${CLAUDE_DIR}/skills"; do
  if [ -d "$user_skill_dir" ]; then
    SKILL_LIST=$(find "$user_skill_dir" -maxdepth 2 -name "SKILL.md" 2>/dev/null | sort || true)
    if [ -n "$SKILL_LIST" ]; then
      while IFS= read -r skill_md; do
        [ -z "$skill_md" ] && continue
        local_name=$(basename "$(dirname "$skill_md")")
        record_skill "$skill_md" "User" "$local_name"
      done <<< "$SKILL_LIST"
    fi
  fi
done

# 7b. Plugin commands + skills (from enabled plugins in enabledPlugins order)
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1 && [ -d "$CACHE_DIR" ]; then
  ENABLED_PLUGINS_SKILLS=$(jq -r '
    .enabledPlugins // {} | to_entries[]
    | select(.value == true)
    | .key
  ' "$SETTINGS" 2>/dev/null || true)

  if [ -n "$ENABLED_PLUGINS_SKILLS" ]; then
    while IFS= read -r plugin_key; do
      [ -z "$plugin_key" ] && continue

      PLUGIN_NAME="${plugin_key%%@*}"
      MARKETPLACE="${plugin_key##*@}"
      PLUGIN_CACHE="${CACHE_DIR}/${MARKETPLACE}/${PLUGIN_NAME}"
      [ ! -d "$PLUGIN_CACHE" ] && continue

      LATEST_VERSION=$(ls "$PLUGIN_CACHE" 2>/dev/null \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -t. -k1,1n -k2,2n -k3,3n \
        | tail -1)
      [ -z "$LATEST_VERSION" ] && continue

      PLUGIN_ROOT="${PLUGIN_CACHE}/${LATEST_VERSION}"
      PLUGIN_JSON="${PLUGIN_ROOT}/.claude-plugin/plugin.json"
      [ ! -f "$PLUGIN_JSON" ] && continue

      # Iterate commands dirs first, then skills dirs (matches Claude Code load order)
      for dir_type in commands skills; do
        DIRS=$(jq -r ".${dir_type}[]? // empty" "$PLUGIN_JSON" 2>/dev/null || true)
        if [ -n "$DIRS" ]; then
          while IFS= read -r rel_dir; do
            [ -z "$rel_dir" ] && continue
            full_dir="${PLUGIN_ROOT}/${rel_dir}"
            [ ! -d "$full_dir" ] && continue
            SKILL_LIST=$(find "$full_dir" -maxdepth 2 -name "SKILL.md" 2>/dev/null | sort || true)
            if [ -n "$SKILL_LIST" ]; then
              while IFS= read -r skill_md; do
                [ -z "$skill_md" ] && continue
                local_name=$(basename "$(dirname "$skill_md")")
                record_skill "$skill_md" "Project" "${PLUGIN_NAME}@${MARKETPLACE} (v${LATEST_VERSION}) · ${local_name}"
              done <<< "$SKILL_LIST"
            fi
          done <<< "$DIRS"
        fi
      done

    done <<< "$ENABLED_PLUGINS_SKILLS"
  fi
fi

# 7c. Project commands — {project}/.claude/commands/
PROJECT_COMMANDS_DIR="${PROJECT_DIR}/.claude/commands"
if [ -d "$PROJECT_COMMANDS_DIR" ]; then
  SKILL_LIST=$(find "$PROJECT_COMMANDS_DIR" -maxdepth 2 -name "SKILL.md" 2>/dev/null | sort || true)
  if [ -n "$SKILL_LIST" ]; then
    while IFS= read -r skill_md; do
      [ -z "$skill_md" ] && continue
      local_name=$(basename "$(dirname "$skill_md")")
      record_skill "$skill_md" "Project" "./.claude/commands/${local_name}"
    done <<< "$SKILL_LIST"
  fi
fi

# ── Output ────────────────────────────────────────────────────────────────────

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TABLE_FILE="/tmp/claude-ctx-table-${TIMESTAMP}.txt"

if [ "$MODE" = "--stdout" ]; then
  echo "$OUTPUT"
else
  OUTFILE="/tmp/claude-context-${TIMESTAMP}.md"
  echo "$OUTPUT" > "$OUTFILE"
  echo "$OUTFILE"
fi

# ── Summary table — write to file, print path on stdout ──────────────────────

print_table > "$TABLE_FILE"
echo "$TABLE_FILE"
