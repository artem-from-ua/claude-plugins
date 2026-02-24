#!/usr/bin/env bash
# ctx-show.sh — assemble full Claude Code session context in load order
# Usage: ctx-show.sh [--file|--stdout]
#
# Sources (in load order):
#   1. ~/.claude/CLAUDE.md              — global user instructions
#   2. {project}/CLAUDE.md              — project instructions
#   3. ~/.claude/projects/{hash}/memory/MEMORY.md — auto-memory
#   4. Global SessionStart hooks        — from ~/.claude/settings.json
#   5. Plugin SessionStart hooks        — enabled plugins in cache

set -euo pipefail

MODE="${1:---file}"
CLAUDE_DIR="${HOME}/.claude"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
OUTPUT=""

# ── helpers ──────────────────────────────────────────────────────────────────

append_source() {
  local label="$1"
  local path="$2"
  OUTPUT+=$'\n'"<!-- Source: ${label} -->"$'\n'
  if [ -f "$path" ]; then
    OUTPUT+=$'\n'"$(cat "$path")"$'\n'
  else
    OUTPUT+="<!-- (not found: ${path}) -->"$'\n'
  fi
}

append_command_output() {
  local label="$1"
  local cmd="$2"
  OUTPUT+=$'\n'"<!-- Source: ${label} -->"$'\n'
  local result
  if result=$(eval "$cmd" 2>&1); then
    if [ -n "$result" ]; then
      OUTPUT+=$'\n'"${result}"$'\n'
    else
      OUTPUT+="<!-- (no output) -->"$'\n'
    fi
  else
    OUTPUT+="<!-- (command failed: ${cmd}) -->"$'\n'
  fi
}

# ── 1. Global CLAUDE.md ───────────────────────────────────────────────────────

append_source "~/.claude/CLAUDE.md (global user instructions)" "${CLAUDE_DIR}/CLAUDE.md"

# ── 2. Project CLAUDE.md ─────────────────────────────────────────────────────

# Claude Code looks for CLAUDE.md in the project root
PROJECT_CLAUDE="${PROJECT_DIR}/CLAUDE.md"
append_source "${PROJECT_DIR}/CLAUDE.md (project instructions)" "${PROJECT_CLAUDE}"

# ── 3. Auto-memory MEMORY.md ─────────────────────────────────────────────────

# Project path hash: replace / with - (same encoding Claude Code uses)
PROJECT_HASH=$(echo "$PROJECT_DIR" | sed 's|/|-|g' | sed 's|^-||')
MEMORY_FILE="${CLAUDE_DIR}/projects/${PROJECT_HASH}/memory/MEMORY.md"
append_source "~/.claude/projects/${PROJECT_HASH}/memory/MEMORY.md (auto-memory)" "${MEMORY_FILE}"

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
      append_command_output "Global SessionStart hook: ${cmd}" "${cmd_expanded}"
    done <<< "$HOOK_COMMANDS"
  else
    OUTPUT+=$'\n'"<!-- Source: Global SessionStart hooks -->"$'\n'"<!-- (none configured in ${SETTINGS}) -->"$'\n'
  fi
else
  OUTPUT+=$'\n'"<!-- Source: Global SessionStart hooks -->"$'\n'"<!-- (settings.json not found or jq not available) -->"$'\n'
fi

# ── 5. Plugin SessionStart hooks ─────────────────────────────────────────────

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
        continue
      fi

      # Find highest semver version directory
      LATEST_VERSION=$(ls "$PLUGIN_CACHE" 2>/dev/null \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -t. -k1,1n -k2,2n -k3,3n \
        | tail -1)

      if [ -z "$LATEST_VERSION" ]; then
        OUTPUT+=$'\n'"<!-- Source: Plugin ${plugin_key} SessionStart hooks -->"$'\n'"<!-- (no versioned cache found in ${PLUGIN_CACHE}) -->"$'\n'
        continue
      fi

      PLUGIN_ROOT="${PLUGIN_CACHE}/${LATEST_VERSION}"
      HOOKS_FILE="${PLUGIN_ROOT}/hooks/hooks.json"

      if [ ! -f "$HOOKS_FILE" ]; then
        OUTPUT+=$'\n'"<!-- Source: Plugin ${plugin_key} (v${LATEST_VERSION}) SessionStart hooks -->"$'\n'"<!-- (no hooks.json found) -->"$'\n'
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
        continue
      fi

      while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        # Replace ${CLAUDE_PLUGIN_ROOT} with actual plugin root
        cmd_expanded="${cmd/\$\{CLAUDE_PLUGIN_ROOT\}/$PLUGIN_ROOT}"
        append_command_output "Plugin ${plugin_key} (v${LATEST_VERSION}) SessionStart: ${cmd}" "${cmd_expanded}"
      done <<< "$PLUGIN_HOOKS"

    done <<< "$ENABLED_PLUGINS"
  else
    OUTPUT+=$'\n'"<!-- Source: Plugin SessionStart hooks -->"$'\n'"<!-- (no enabled plugins) -->"$'\n'
  fi
else
  OUTPUT+=$'\n'"<!-- Source: Plugin SessionStart hooks -->"$'\n'"<!-- (settings.json not found, jq not available, or cache directory missing) -->"$'\n'
fi

# ── Output ────────────────────────────────────────────────────────────────────

if [ "$MODE" = "--stdout" ]; then
  echo "$OUTPUT"
else
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  OUTFILE="/tmp/claude-context-${TIMESTAMP}.md"
  echo "$OUTPUT" > "$OUTFILE"
  echo "$OUTFILE"
fi
