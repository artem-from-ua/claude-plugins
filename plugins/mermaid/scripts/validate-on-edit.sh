#!/bin/bash
# Claude Code PostToolUse hook: validate Mermaid blocks after editing .md files.
# Reads tool input from stdin, checks if the file is .md, and runs the validator.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE_PATH" == *.md ]]; then
  python3 "$PLUGIN_ROOT/scripts/validate-mermaid.py" "$FILE_PATH" 2>&1
fi

exit 0
