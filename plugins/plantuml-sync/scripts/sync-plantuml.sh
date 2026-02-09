#!/bin/bash
# Claude Code PostToolUse hook: auto-sync PlantUML URLs after editing .md files
# Called by Claude Code after every Write/Edit operation.
# Reads tool input from stdin, checks if the file is .md, and runs sync.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE_PATH" == *.md ]]; then
  python3 "$PLUGIN_ROOT/scripts/plantuml-encode.py" --sync "$FILE_PATH" 2>&1
fi

exit 0
