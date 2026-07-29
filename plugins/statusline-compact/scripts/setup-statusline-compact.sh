#!/bin/bash
# SessionStart hook: ensure statusline-compact.sh is available at
# ~/.claude/statusline-compact.sh. Copies the script if missing or outdated.
# Does NOT modify settings.json (that is the slash command's job).
#
# A distinct target file (statusline-compact.sh, not statusline.sh) lets this
# plugin coexist with the statusline plugin without the two copiers fighting
# over one file.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SOURCE="$PLUGIN_ROOT/scripts/statusline-compact.sh"
TARGET="$HOME/.claude/statusline-compact.sh"

mkdir -p "$HOME/.claude"

# Copy if target doesn't exist or differs from source
if [ ! -f "$TARGET" ] || ! diff -q "$SOURCE" "$TARGET" > /dev/null 2>&1; then
  if cp "$SOURCE" "$TARGET" && chmod +x "$TARGET"; then
    echo "statusline-compact.sh updated"
  else
    echo "Warning: failed to copy statusline-compact.sh to $TARGET" >&2
  fi
fi

# Nudge to run setup only if no statusline is configured yet
SETTINGS="$HOME/.claude/settings.json"
if [ ! -f "$SETTINGS" ] || ! jq -e '.statusLine' "$SETTINGS" > /dev/null 2>&1; then
  echo "Note: statusline-compact.sh installed at ~/.claude/statusline-compact.sh"
  echo "Run /statusline-compact:statusline-compact-setup to configure it."
fi
