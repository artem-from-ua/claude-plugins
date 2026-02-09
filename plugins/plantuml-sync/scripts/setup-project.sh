#!/bin/bash
# SessionStart hook: install PlantUML pre-commit hook in the current project.
# Idempotent — only installs if not already present.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Only run in git repos
if ! git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
  exit 0
fi

HOOKS_DIR="$PROJECT_DIR/.githooks"
HOOK_FILE="$HOOKS_DIR/pre-commit"
TEMPLATE="$PLUGIN_ROOT/templates/pre-commit"

# Install pre-commit hook if template exists and hook is missing or outdated
if [ -f "$TEMPLATE" ]; then
  if [ ! -f "$HOOK_FILE" ] || ! diff -q "$TEMPLATE" "$HOOK_FILE" > /dev/null 2>&1; then
    mkdir -p "$HOOKS_DIR"
    cp "$TEMPLATE" "$HOOK_FILE"
    chmod +x "$HOOK_FILE"
  fi
fi

# Configure git to use .githooks directory
CURRENT_HOOKS_PATH=$(git -C "$PROJECT_DIR" config --local core.hooksPath 2>/dev/null)
if [ "$CURRENT_HOOKS_PATH" != ".githooks" ]; then
  git -C "$PROJECT_DIR" config core.hooksPath .githooks
fi

exit 0
