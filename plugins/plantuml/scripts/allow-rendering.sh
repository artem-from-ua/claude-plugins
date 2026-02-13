#!/bin/bash
# PreToolUse hook: Auto-allow PlantUML rendering commands without prompts
#
# This hook runs before every Bash tool use and automatically allows
# PlantUML-related commands (render-ascii.sh, temp file creation) without
# permission prompts, while maintaining security for other commands.
#
# Input: JSON from stdin with tool_input.command
# Output: JSON with permissionDecision (allow/deny/ask) or exit 0 for passthrough

set -euo pipefail

# Read tool input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Exit early if no command (passthrough to normal permission system)
[[ -z "$COMMAND" ]] && exit 0

# Allow PlantUML rendering commands
if echo "$COMMAND" | grep -qE '(render-ascii\.sh|plantuml-encode\.py --render-ascii)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "PlantUML plugin rendering command"
    }
  }'
  exit 0
fi

# Allow creating temp files for PlantUML diagrams
if echo "$COMMAND" | grep -qE 'cat > .*(diagram|plantuml).*\.puml'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "PlantUML plugin temp file creation"
    }
  }'
  exit 0
fi

# Passthrough: Let normal permission system handle other commands
exit 0
