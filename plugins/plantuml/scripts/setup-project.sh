#!/bin/bash
# SessionStart hook: install PlantUML pre-commit hook in the current project.
# Non-destructive — uses marker-based injection to coexist with existing hooks.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Only run in git repos
if ! git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
  exit 0
fi

TEMPLATE="$PLUGIN_ROOT/templates/pre-commit"

if [ ! -f "$TEMPLATE" ]; then
  exit 0
fi

# Determine hooks directory: respect existing core.hooksPath, default to .githooks
HOOKS_DIR=$(git -C "$PROJECT_DIR" config --local core.hooksPath 2>/dev/null)
if [ -z "$HOOKS_DIR" ]; then
  HOOKS_DIR=".githooks"
  git -C "$PROJECT_DIR" config core.hooksPath "$HOOKS_DIR"
fi

# Resolve relative hooks dir against project root
case "$HOOKS_DIR" in
  /*) HOOK_FILE="$HOOKS_DIR/pre-commit" ;;
  *)  HOOK_FILE="$PROJECT_DIR/$HOOKS_DIR/pre-commit" ;;
esac

mkdir -p "$(dirname "$HOOK_FILE")"

MARKER_BEGIN="# >>> tribe-coding/plantuml >>>"
MARKER_END="# <<< tribe-coding/plantuml <<<"
SECTION=$(cat "$TEMPLATE")

if [ -f "$HOOK_FILE" ]; then
  # Hook file exists — check for markers
  if grep -qF "$MARKER_BEGIN" "$HOOK_FILE"; then
    # Markers found — replace section in-place
    BEFORE_LINE=$(grep -nF "$MARKER_BEGIN" "$HOOK_FILE" | head -1 | cut -d: -f1)
    AFTER_LINE=$(grep -nF "$MARKER_END" "$HOOK_FILE" | head -1 | cut -d: -f1)
    TOTAL=$(wc -l < "$HOOK_FILE")

    {
      # Lines before the begin marker
      if [ "$BEFORE_LINE" -gt 1 ]; then
        head -n "$(( BEFORE_LINE - 1 ))" "$HOOK_FILE"
      fi
      # New section (includes markers)
      printf '%s\n' "$SECTION"
      # Lines after the end marker
      if [ "$AFTER_LINE" -lt "$TOTAL" ]; then
        tail -n "$(( TOTAL - AFTER_LINE ))" "$HOOK_FILE"
      fi
    } > "$HOOK_FILE.tmp"
    mv "$HOOK_FILE.tmp" "$HOOK_FILE"
  else
    # No markers — append section
    printf '\n%s\n' "$SECTION" >> "$HOOK_FILE"
  fi
else
  # No hook file — create with shebang
  {
    printf '#!/bin/bash\n\n'
    printf '%s\n' "$SECTION"
  } > "$HOOK_FILE"
fi

chmod +x "$HOOK_FILE"

exit 0
