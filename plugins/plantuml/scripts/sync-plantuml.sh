#!/bin/bash
# Claude Code PostToolUse hook: auto-sync PlantUML diagrams after editing .md files.
# Called by Claude Code after every Write/Edit operation.
# Reads tool input from stdin, decides whether the file is ours to touch, and syncs.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$FILE_PATH" == *.md ]] || exit 0
[ -f "$FILE_PATH" ] || exit 0

# The sync rewrites document structure, not just a URL, and this plugin is often
# installed globally — so it runs on every markdown file in every project the user
# opens. Vendored and generated trees are not the author's to restructure, and a
# file outside version control has no diff to review the change in.
case "/$FILE_PATH" in
  */node_modules/*|*/vendor/*|*/.git/*|*/dist/*|*/build/*|*/.venv/*|*/site-packages/*)
    exit 0 ;;
esac

FILE_DIR=$(dirname "$FILE_PATH")
git -C "$FILE_DIR" rev-parse --git-dir > /dev/null 2>&1 || exit 0
git -C "$FILE_DIR" check-ignore -q "$FILE_PATH" 2>/dev/null && exit 0

python3 "$PLUGIN_ROOT/scripts/plantuml-encode.py" --sync "$FILE_PATH" 2>&1

exit 0
