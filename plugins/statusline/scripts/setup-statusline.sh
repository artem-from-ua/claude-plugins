#!/bin/bash
# SessionStart hook: ensure statusline.sh is available at ~/.claude/statusline.sh
# Copies the script if missing or outdated. Does NOT modify settings.json.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SOURCE="$PLUGIN_ROOT/scripts/statusline.sh"
TARGET="$HOME/.claude/statusline.sh"

# --- Logging ---
LOG_FILE="/tmp/claude-plugin-sync.log"
_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [setup-statusline] $*" >> "$LOG_FILE"
}

_log "=== setup-statusline.sh started ==="
_log "CLAUDE_PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT:-<unset>}"
_log "PLUGIN_ROOT=$PLUGIN_ROOT"
_log "SOURCE=$SOURCE"
_log "TARGET=$TARGET"
if [ -f "$SOURCE" ]; then
  _log "SOURCE exists: $(ls -la "$SOURCE" 2>&1)"
else
  _log "SOURCE does NOT exist"
fi
if [ -f "$TARGET" ]; then
  _log "TARGET exists: $(ls -la "$TARGET" 2>&1)"
else
  _log "TARGET does NOT exist"
fi

# Ensure ~/.claude directory exists
mkdir -p "$HOME/.claude"

# Copy if target doesn't exist or is different from source
if [ ! -f "$TARGET" ]; then
  _log "TARGET missing, will copy"
  if cp "$SOURCE" "$TARGET" && chmod +x "$TARGET"; then
    _log "Copied (target was missing): $(ls -la "$TARGET" 2>&1)"
    echo "statusline.sh updated"
  else
    _log "ERROR: failed to copy $SOURCE → $TARGET"
    echo "Warning: failed to copy statusline.sh to $TARGET" >&2
  fi
elif ! diff -q "$SOURCE" "$TARGET" > /dev/null 2>&1; then
  _log "TARGET differs from SOURCE, will copy"
  _log "diff output: $(diff "$SOURCE" "$TARGET" 2>&1 | head -20)"
  if cp "$SOURCE" "$TARGET" && chmod +x "$TARGET"; then
    _log "Copied (target updated): $(ls -la "$TARGET" 2>&1)"
    echo "statusline.sh updated"
  else
    _log "ERROR: failed to copy $SOURCE → $TARGET"
    echo "Warning: failed to copy statusline.sh to $TARGET" >&2
  fi
else
  _log "TARGET is identical to SOURCE, skipping copy"
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
_log "=== setup-statusline.sh finished ==="
