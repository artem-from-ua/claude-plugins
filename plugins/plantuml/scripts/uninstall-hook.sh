#!/bin/bash
# Remove the plantuml pre-commit hook section from the current project.
# Uses marker-based detection to only remove the plantuml section,
# preserving other hook content.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Only run in git repos
if ! git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
  echo "Not a git repository. Nothing to uninstall."
  exit 1
fi

# Determine hooks directory from core.hooksPath
HOOKS_DIR=$(git -C "$PROJECT_DIR" config --local core.hooksPath 2>/dev/null)
if [ -z "$HOOKS_DIR" ]; then
  HOOKS_DIR=".githooks"
fi

# Resolve relative hooks dir against project root
case "$HOOKS_DIR" in
  /*) HOOK_FILE="$HOOKS_DIR/pre-commit" ;;
  *)  HOOK_FILE="$PROJECT_DIR/$HOOKS_DIR/pre-commit" ;;
esac

if [ ! -f "$HOOK_FILE" ]; then
  echo "No pre-commit hook found at $HOOK_FILE. Nothing to uninstall."
  exit 0
fi

MARKER_BEGIN="# >>> artem-from-ua/plantuml >>>"
MARKER_END="# <<< artem-from-ua/plantuml <<<"

if ! grep -qF "$MARKER_BEGIN" "$HOOK_FILE"; then
  echo "No plantuml section found in $HOOK_FILE. Nothing to uninstall."
  exit 0
fi

# Remove the marker-delimited section
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

# Check if remaining content is only shebang/whitespace
if ! grep -qvE '^(#!/|[[:space:]]*$)' "$HOOK_FILE.tmp" 2>/dev/null; then
  # Only shebang or empty lines left — remove the hook file
  rm -f "$HOOK_FILE" "$HOOK_FILE.tmp"
  echo "Removed $HOOK_FILE (no other hook sections remaining)."
else
  mv "$HOOK_FILE.tmp" "$HOOK_FILE"
  chmod +x "$HOOK_FILE"
  echo "Removed plantuml section from $HOOK_FILE. Other hook sections preserved."
fi

exit 0
