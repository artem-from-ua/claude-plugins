#!/bin/bash
# Remove the mermaid pre-commit hook section from the current project.
# Uses marker-based detection to only remove the mermaid section,
# preserving other hook content.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

if ! git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
  echo "Not a git repository. Nothing to uninstall."
  exit 1
fi

HOOKS_DIR=$(git -C "$PROJECT_DIR" config --local core.hooksPath 2>/dev/null)
if [ -z "$HOOKS_DIR" ]; then
  HOOKS_DIR=".githooks"
fi

case "$HOOKS_DIR" in
  /*) HOOK_FILE="$HOOKS_DIR/pre-commit" ;;
  *)  HOOK_FILE="$PROJECT_DIR/$HOOKS_DIR/pre-commit" ;;
esac

if [ ! -f "$HOOK_FILE" ]; then
  echo "No pre-commit hook found at $HOOK_FILE. Nothing to uninstall."
  exit 0
fi

MARKER_BEGIN="# >>> tribe-coding/mermaid >>>"
MARKER_END="# <<< tribe-coding/mermaid <<<"

if ! grep -qF "$MARKER_BEGIN" "$HOOK_FILE"; then
  echo "No mermaid section found in $HOOK_FILE. Nothing to uninstall."
  exit 0
fi

BEFORE_LINE=$(grep -nF "$MARKER_BEGIN" "$HOOK_FILE" | head -1 | cut -d: -f1)
AFTER_LINE=$(grep -nF "$MARKER_END" "$HOOK_FILE" | head -1 | cut -d: -f1)
TOTAL=$(wc -l < "$HOOK_FILE")

{
  if [ "$BEFORE_LINE" -gt 1 ]; then
    head -n "$(( BEFORE_LINE - 1 ))" "$HOOK_FILE"
  fi
  if [ "$AFTER_LINE" -lt "$TOTAL" ]; then
    tail -n "$(( TOTAL - AFTER_LINE ))" "$HOOK_FILE"
  fi
} > "$HOOK_FILE.tmp"

if ! grep -qvE '^(#!/|[[:space:]]*$)' "$HOOK_FILE.tmp" 2>/dev/null; then
  rm -f "$HOOK_FILE" "$HOOK_FILE.tmp"
  echo "Removed $HOOK_FILE (no other hook sections remaining)."
else
  mv "$HOOK_FILE.tmp" "$HOOK_FILE"
  chmod +x "$HOOK_FILE"
  echo "Removed mermaid section from $HOOK_FILE. Other hook sections preserved."
fi

exit 0
