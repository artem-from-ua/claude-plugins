#!/bin/bash
# SessionEnd hook: suggest /retro session before exiting if configured.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Find config — project-level takes precedence
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
_new="${PROJECT_DIR}/.claude-plugin/retroscope.json"
_old="${PROJECT_DIR}/.claude/retroscope.json"
USER_CONFIG="${HOME}/.claude/retroscope.json"

CONFIG=""
if [ -f "$_new" ]; then
  CONFIG="$_new"
elif [ -f "$_old" ]; then
  CONFIG="$_old"
elif [ -f "$USER_CONFIG" ]; then
  CONFIG="$USER_CONFIG"
fi

# Default: suggest on exit
SUGGEST="true"

if [ -n "$CONFIG" ]; then
  # Read suggestRetroOnExit from config
  SUGGEST=$(python3 -c "
import json, sys
try:
    with open('$CONFIG') as f:
        cfg = json.load(f)
    print('true' if cfg.get('suggestRetroOnExit', True) else 'false')
except Exception:
    print('true')
" 2>/dev/null)
fi

if [ "$SUGGEST" = "true" ]; then
  echo ""
  echo "💡 Run \`/retro session\` to save a session summary before exiting."
fi
