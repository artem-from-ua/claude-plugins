#!/bin/bash
# PreToolUse hook: Auto-allow PlantUML rendering commands without prompts
#
# This hook runs before Bash and Write tool use and automatically allows
# PlantUML-related operations (render-ascii.sh, temp file creation) without
# permission prompts, while maintaining security for other commands.
#
# Input: JSON from stdin with tool_input.command (Bash) or tool_input.file_path (Write)
# Output: JSON with permissionDecision (allow/deny/ask) or exit 0 for passthrough

set -euo pipefail

# Read tool input from stdin
INPUT=$(cat)

# For Bash tool: check command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# For Write tool: check file_path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

# Allow PlantUML encoding and rendering commands
if echo "$COMMAND" | grep -qE '(render-ascii\.sh|plantuml-encode\.py)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "PlantUML plugin encoding/rendering command"
    }
  }'
  exit 0
fi

# Allow creating temp PlantUML files via Bash (heredoc or redirect)
if [[ -n "$COMMAND" ]] && echo "$COMMAND" | grep -qE 'cat > /tmp/.*\.puml'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "PlantUML plugin temp file creation"
    }
  }'
  exit 0
fi

# Allow deleting temp PlantUML files
if [[ -n "$COMMAND" ]] && echo "$COMMAND" | grep -qE 'rm /tmp/.*\.puml'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "PlantUML plugin temp file cleanup"
    }
  }'
  exit 0
fi

# Allow Write tool for PlantUML files in /tmp
if [[ -n "$FILE_PATH" ]] && echo "$FILE_PATH" | grep -qE '^/tmp/.*\.puml$'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "PlantUML plugin temp file"
    }
  }'
  exit 0
fi

# Passthrough: Let normal permission system handle other commands
exit 0
