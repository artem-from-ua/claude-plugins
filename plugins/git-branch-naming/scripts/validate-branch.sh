#!/bin/bash
# PreToolUse hook: validate git branch naming conventions.
# Intercepts: git checkout -b, git branch <name>, git switch -c, git commit, git push
#
# Input:  JSON from stdin with tool_input.command
# Output: JSON with permissionDecision (allow/ask/deny) or exit 0 for passthrough

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Read tool input from stdin
INPUT=$(cat)

# Extract the command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Fast exit: not a git command
if [[ -z "$COMMAND" ]] || ! echo "$COMMAND" | grep -qE '^\s*(git\s)'; then
  exit 0
fi

# Fast exit: not a relevant git subcommand
if ! echo "$COMMAND" | grep -qE '\b(checkout|branch|switch|commit|push)\b'; then
  exit 0
fi

# ─── Config loading ─────────────────────────────────────────────────────────

CONFIG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/git-branch-naming.json"

# Defaults
PREFIXES="feature|bugfix|hotfix|release|docs|test|chore|refactor"
TICKET_PATTERN=""
MAX_LENGTH=60
PROTECTED="main|master|develop"
REQUIRE_KEBAB_CASE=true
WARN_ON_CONTENT_MISMATCH=true
ENFORCEMENT_INVALID_NAME="ask"
ENFORCEMENT_PROTECTED_BRANCH="ask"
ENFORCEMENT_CONTENT_MISMATCH="ask"

if [[ -f "$CONFIG_FILE" ]]; then
  _prefixes=$(jq -r '.prefixes // empty | join("|")' "$CONFIG_FILE" 2>/dev/null || true)
  [[ -n "$_prefixes" ]] && PREFIXES="$_prefixes"

  _ticket=$(jq -r '.ticketPattern // empty' "$CONFIG_FILE" 2>/dev/null || true)
  [[ -n "$_ticket" ]] && TICKET_PATTERN="$_ticket"

  _maxlen=$(jq -r '.maxLength // empty' "$CONFIG_FILE" 2>/dev/null || true)
  [[ -n "$_maxlen" ]] && MAX_LENGTH="$_maxlen"

  _protected=$(jq -r '.protectedBranches // empty | join("|")' "$CONFIG_FILE" 2>/dev/null || true)
  [[ -n "$_protected" ]] && PROTECTED="$_protected"

  _kebab=$(jq -r '.requireKebabCase // empty' "$CONFIG_FILE" 2>/dev/null || true)
  [[ "$_kebab" == "false" ]] && REQUIRE_KEBAB_CASE=false

  _mismatch=$(jq -r '.warnOnContentMismatch // empty' "$CONFIG_FILE" 2>/dev/null || true)
  [[ "$_mismatch" == "false" ]] && WARN_ON_CONTENT_MISMATCH=false

  _e_name=$(jq -r '.enforcement.invalidName // empty' "$CONFIG_FILE" 2>/dev/null || true)
  [[ -n "$_e_name" ]] && ENFORCEMENT_INVALID_NAME="$_e_name"

  _e_prot=$(jq -r '.enforcement.protectedBranch // empty' "$CONFIG_FILE" 2>/dev/null || true)
  [[ -n "$_e_prot" ]] && ENFORCEMENT_PROTECTED_BRANCH="$_e_prot"

  _e_mis=$(jq -r '.enforcement.contentMismatch // empty' "$CONFIG_FILE" 2>/dev/null || true)
  [[ -n "$_e_mis" ]] && ENFORCEMENT_CONTENT_MISMATCH="$_e_mis"
fi

# ─── Helpers ────────────────────────────────────────────────────────────────

permission_response() {
  local decision="$1"
  local reason="$2"
  jq -n \
    --arg decision "$decision" \
    --arg reason "$reason" \
    '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: $decision,
        permissionDecisionReason: $reason
      }
    }'
  exit 0
}

# Validate branch name format
validate_name() {
  local name="$1"
  local prefix_part desc_part

  # Check prefix
  if ! echo "$name" | grep -qE "^($PREFIXES)/"; then
    local suggestion
    # Try to guess prefix from name
    if echo "$name" | grep -qiE '(fix|bug|patch|resolve)'; then
      suggestion="bugfix/$name"
    elif echo "$name" | grep -qiE '(doc|readme|wiki)'; then
      suggestion="docs/$name"
    elif echo "$name" | grep -qiE '(test|spec)'; then
      suggestion="test/$name"
    else
      suggestion="feature/$name"
    fi
    suggestion=$(echo "$suggestion" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    echo "INVALID_PREFIX:$suggestion"
    return
  fi

  prefix_part="${name%%/*}"
  desc_part="${name#*/}"

  # Check description not empty
  if [[ -z "$desc_part" ]]; then
    echo "INVALID_EMPTY_DESC:$prefix_part/my-description"
    return
  fi

  # Check kebab-case
  if [[ "$REQUIRE_KEBAB_CASE" == "true" ]]; then
    if echo "$desc_part" | grep -qE '[A-Z_]'; then
      local fixed_desc
      fixed_desc=$(echo "$desc_part" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
      echo "INVALID_KEBAB:$prefix_part/$fixed_desc"
      return
    fi
    if echo "$desc_part" | grep -qE '[^a-z0-9./-]'; then
      local fixed_desc
      fixed_desc=$(echo "$desc_part" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9./-]/-/g' | sed 's/--*/-/g')
      echo "INVALID_CHARS:$prefix_part/$fixed_desc"
      return
    fi
  fi

  # Check max length
  if [[ ${#name} -gt $MAX_LENGTH ]]; then
    echo "INVALID_TOO_LONG:${name:0:$MAX_LENGTH}"
    return
  fi

  # Check ticket pattern if required
  if [[ -n "$TICKET_PATTERN" ]]; then
    if ! echo "$desc_part" | grep -qE "$TICKET_PATTERN"; then
      echo "INVALID_TICKET:$prefix_part/TICKET-123-$desc_part"
      return
    fi
  fi

  echo "OK"
}

# ─── Branch creation commands ───────────────────────────────────────────────

handle_branch_creation() {
  local branch_name="$1"

  local result
  result=$(validate_name "$branch_name")

  if [[ "$result" == "OK" ]]; then
    exit 0
  fi

  local code="${result%%:*}"
  local suggestion="${result#*:}"

  local reason
  case "$code" in
    INVALID_PREFIX)
      reason="Branch name '$branch_name' is missing a valid prefix.

Valid prefixes: $(echo "$PREFIXES" | tr '|' ', ')

Suggested fix: git branch -m '$branch_name' '$suggestion'

Branch name format: <prefix>/<kebab-case-description>"
      ;;
    INVALID_EMPTY_DESC)
      reason="Branch name '$branch_name' has no description after the prefix.

Suggested fix: $suggestion"
      ;;
    INVALID_KEBAB)
      reason="Branch name '$branch_name' must use kebab-case (lowercase, hyphens only — no uppercase or underscores).

Suggested fix: git branch -m '$branch_name' '$suggestion'"
      ;;
    INVALID_CHARS)
      reason="Branch name '$branch_name' contains invalid characters. Only lowercase letters, digits, hyphens, and dots are allowed in the description part.

Suggested fix: git branch -m '$branch_name' '$suggestion'"
      ;;
    INVALID_TOO_LONG)
      reason="Branch name '$branch_name' exceeds max length of $MAX_LENGTH characters.

Suggested fix: $suggestion (truncated)"
      ;;
    INVALID_TICKET)
      reason="Branch name '$branch_name' is missing required ticket number (pattern: $TICKET_PATTERN).

Suggested fix: $suggestion"
      ;;
    *)
      reason="Branch name '$branch_name' does not follow naming conventions."
      ;;
  esac

  permission_response "$ENFORCEMENT_INVALID_NAME" "$reason"
}

# ─── Parse git subcommand and dispatch ──────────────────────────────────────

# Strip leading whitespace and normalize
CMD=$(echo "$COMMAND" | sed 's/^[[:space:]]*//' | tr -s ' ')

# git checkout -b/-B <name> [<start>]
if echo "$CMD" | grep -qE '^git\s+checkout\s+(-b|-B)\s+'; then
  BRANCH=$(echo "$CMD" | sed -E 's/^git[[:space:]]+checkout[[:space:]]+(-b|-B)[[:space:]]+([^[:space:]]+).*/\2/')
  handle_branch_creation "$BRANCH"
fi

# git branch <name> [<start>] — but not git branch -d/-D/-l/-r/-a (listing/deleting)
if echo "$CMD" | grep -qE '^git\s+branch\s+[^-]'; then
  BRANCH=$(echo "$CMD" | sed -E 's/^git[[:space:]]+branch[[:space:]]+([^[:space:]]+).*/\1/')
  handle_branch_creation "$BRANCH"
fi

# git switch -c/--create <name>
if echo "$CMD" | grep -qE '^git\s+switch\s+(-c|--create)\s+'; then
  BRANCH=$(echo "$CMD" | sed -E 's/^git[[:space:]]+switch[[:space:]]+(-c|--create)[[:space:]]+([^[:space:]]+).*/\2/')
  handle_branch_creation "$BRANCH"
fi

# git commit — check staged content vs branch type
if echo "$CMD" | grep -qE '^git\s+commit(\s|$)'; then
  if [[ "$WARN_ON_CONTENT_MISMATCH" != "true" ]]; then
    exit 0
  fi

  # Get current branch
  CURRENT_BRANCH=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)

  # Skip detached HEAD or protected branches
  if [[ -z "$CURRENT_BRANCH" ]] || [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
    exit 0
  fi
  if echo "$CURRENT_BRANCH" | grep -qE "^($PROTECTED)$"; then
    exit 0
  fi

  # Delegate content mismatch check
  MISMATCH_RESULT=$("$PLUGIN_ROOT/scripts/check-content-mismatch.sh" --staged "$CURRENT_BRANCH" "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true)
  if [[ -n "$MISMATCH_RESULT" ]]; then
    permission_response "$ENFORCEMENT_CONTENT_MISMATCH" "$MISMATCH_RESULT"
  fi
  exit 0
fi

# git push — check protected branch + content mismatch
if echo "$CMD" | grep -qE '^git\s+push(\s|$)'; then
  # Get current branch
  CURRENT_BRANCH=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)

  if [[ -z "$CURRENT_BRANCH" ]] || [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
    exit 0
  fi

  # Check protected branch push
  if echo "$CURRENT_BRANCH" | grep -qE "^($PROTECTED)$"; then
    permission_response "$ENFORCEMENT_PROTECTED_BRANCH" \
      "You are about to push directly to protected branch '$CURRENT_BRANCH'.

This is usually done via a pull request instead of a direct push. Are you sure?"
  fi

  # Content mismatch check on full branch diff
  if [[ "$WARN_ON_CONTENT_MISMATCH" == "true" ]]; then
    MISMATCH_RESULT=$("$PLUGIN_ROOT/scripts/check-content-mismatch.sh" --branch "$CURRENT_BRANCH" "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true)
    if [[ -n "$MISMATCH_RESULT" ]]; then
      permission_response "$ENFORCEMENT_CONTENT_MISMATCH" "$MISMATCH_RESULT"
    fi
  fi
  exit 0
fi

# Passthrough: let normal permission system handle everything else
exit 0
