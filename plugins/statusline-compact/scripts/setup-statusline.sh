#!/bin/bash
# SessionStart hook: ensure statusline.sh is available at ~/.claude/statusline.sh
# Copies the script if missing or outdated. Does NOT modify settings.json.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SOURCE="$PLUGIN_ROOT/scripts/statusline.sh"
TARGET="$HOME/.claude/statusline.sh"

# Ensure ~/.claude directory exists
mkdir -p "$HOME/.claude"

# Copy if target doesn't exist or is different from source
if [ ! -f "$TARGET" ] || ! diff -q "$SOURCE" "$TARGET" > /dev/null 2>&1; then
  if cp "$SOURCE" "$TARGET" && chmod +x "$TARGET"; then
    echo "statusline.sh updated"
  else
    echo "Warning: failed to copy statusline.sh to $TARGET" >&2
  fi
fi

# Check if statusline is configured in settings
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  if ! jq -e '.statusLine' "$SETTINGS" > /dev/null 2>&1; then
    echo "Note: statusline.sh installed at ~/.claude/statusline.sh"
    echo "Run /statusline:statusline-setup to configure it in your settings."
  fi
else
  echo "Note: statusline.sh installed at ~/.claude/statusline.sh"
  echo "Run /statusline:statusline-setup to configure it in your settings."
fi
