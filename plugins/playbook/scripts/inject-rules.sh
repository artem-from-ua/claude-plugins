#!/bin/bash
# inject-rules.sh — SessionStart hook for playbook plugin
# Reads global + project config, merges presets, outputs RULES zones to stdout.
# Silent exit (zero output) when no config or no presets are enabled.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PRESETS_DIR="$PLUGIN_ROOT/presets"
VERSION=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "?")

GLOBAL_CONFIG="$HOME/.claude/playbook.json"
_new="${CLAUDE_PROJECT_DIR:-.}/.claude-plugin/playbook.json"
_old="${CLAUDE_PROJECT_DIR:-.}/.claude/playbook.json"
if [[ -f "$_new" ]]; then
  PROJECT_CONFIG="$_new"
elif [[ -f "$_old" ]]; then
  PROJECT_CONFIG="$_old"
else
  PROJECT_CONFIG="$_new"
fi

# Collect preset names from both configs
global_presets=""
project_presets=""
project_exclude=""

if [[ -f "$GLOBAL_CONFIG" ]]; then
  global_presets=$(jq -r '.presets // [] | .[]' "$GLOBAL_CONFIG" 2>/dev/null || true)
fi

if [[ -f "$PROJECT_CONFIG" ]]; then
  project_presets=$(jq -r '.presets // [] | .[]' "$PROJECT_CONFIG" 2>/dev/null || true)
  project_exclude=$(jq -r '.exclude // [] | .[]' "$PROJECT_CONFIG" 2>/dev/null || true)
fi

# Merge: union of global + project presets, minus project exclude
# Use newline-separated lists + grep for bash 3.2 compatibility (macOS)
all_presets=$(printf '%s\n%s' "$global_presets" "$project_presets" | sort -u | grep -v '^$' || true)

if [[ -z "$all_presets" ]]; then
  exit 0
fi

# Filter out excluded presets
enabled=""
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  if [[ -n "$project_exclude" ]] && printf '%s\n' "$project_exclude" | grep -qxF "$name"; then
    continue
  fi
  enabled="${enabled}${enabled:+$'\n'}${name}"
done <<< "$all_presets"

if [[ -z "$enabled" ]]; then
  exit 0
fi

# Extract and output RULES zone from each enabled preset
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  preset_file="$PRESETS_DIR/$name.md"
  if [[ -f "$preset_file" ]]; then
    printf '<!-- Source: Plugin playbook@artem-from-ua (v%s) Preset %s -->\n' "$VERSION" "$name"
    sed -n '/^<!-- RULES -->/,/^<!-- \/RULES -->/{/^<!-- /d; p;}' "$preset_file"
    printf '\n'
  fi
done <<< "$enabled"
