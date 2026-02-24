#!/bin/bash
# PreToolUse hook: validate version bumps before commit/push/PR creation.
# Intercepts: git commit, git push, gh pr create, gh pr merge
#
# Input:  JSON from stdin with tool_input.command
# Output: JSON with permissionDecision (allow/ask/deny) or exit 0 for passthrough

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Read tool input from stdin
INPUT=$(cat)

# Extract the command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Fast exit: empty or not git/gh command
if [[ -z "$COMMAND" ]] || ! echo "$COMMAND" | grep -qE '^\s*(git\s|gh\s)'; then
  exit 0
fi

# Fast exit: not a relevant subcommand
if ! echo "$COMMAND" | grep -qE '\b(commit|push|pr)\b'; then
  exit 0
fi

# For gh commands, only intercept pr create/merge
if echo "$COMMAND" | grep -qE '^\s*gh\s'; then
  if ! echo "$COMMAND" | grep -qE '\bpr\s+(create|merge)\b'; then
    exit 0
  fi
fi

# ─── Config loading ──────────────────────────────────────────────────────────

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CONFIG_FILE="$PROJECT_DIR/.claude/semver.json"
GLOBAL_CONFIG="$HOME/.claude/semver.json"

# Defaults
TRIGGER_STRATEGY="auto"
BASE_BRANCH="main"
ENFORCEMENT_MISSING_BUMP="ask"

# Version files: newline-separated paths
VERSION_FILE_PATHS=""

# Exclude patterns: newline-separated
EXCLUDE_PATTERNS="README.md
CHANGELOG.md
LICENSE
.gitignore
*.md
docs/**
.claude/**"

load_config() {
  local cfg="$1"
  [[ ! -f "$cfg" ]] && return

  _trigger=$(jq -r '.triggerStrategy // empty' "$cfg" 2>/dev/null || true)
  [[ -n "$_trigger" ]] && TRIGGER_STRATEGY="$_trigger" || true

  _base=$(jq -r '.baseBranch // empty' "$cfg" 2>/dev/null || true)
  [[ -n "$_base" ]] && BASE_BRANCH="$_base" || true

  _enforcement=$(jq -r '.enforcement.missingBump // empty' "$cfg" 2>/dev/null || true)
  [[ -n "$_enforcement" ]] && ENFORCEMENT_MISSING_BUMP="$_enforcement" || true

  _paths=$(jq -r '.versionFiles[]?.path // empty' "$cfg" 2>/dev/null || true)
  [[ -n "$_paths" ]] && VERSION_FILE_PATHS="$_paths" || true

  _excludes=$(jq -r '.excludePatterns[]? // empty' "$cfg" 2>/dev/null || true)
  [[ -n "$_excludes" ]] && EXCLUDE_PATTERNS="$_excludes" || true

  return 0
}

# Project config takes priority, fall back to global
if [[ -f "$CONFIG_FILE" ]]; then
  load_config "$CONFIG_FILE"
elif [[ -f "$GLOBAL_CONFIG" ]]; then
  load_config "$GLOBAL_CONFIG"
fi

# If enforcement is "allow", nothing to check
if [[ "$ENFORCEMENT_MISSING_BUMP" == "allow" ]]; then
  exit 0
fi

# Auto-detect version files if none configured
if [[ -z "$VERSION_FILE_PATHS" ]]; then
  for candidate in "package.json" "pyproject.toml" "Cargo.toml" ".claude-plugin/plugin.json" "version.txt"; do
    if [[ -f "$PROJECT_DIR/$candidate" ]]; then
      VERSION_FILE_PATHS="$candidate"
      break
    fi
  done
fi

# If still no version files found — nothing to enforce
if [[ -z "$VERSION_FILE_PATHS" ]]; then
  exit 0
fi

# Not in a git repo — pass through silently
if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# ─── Helpers ─────────────────────────────────────────────────────────────────

permission_response() {
  local decision="$1"
  local reason="$2"
  # Use python3 to build valid JSON — handles newlines and special chars reliably
  PYTHONPATH="" python3 -c "
import sys, json
d = sys.argv[1]
r = sys.argv[2]
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': d, 'permissionDecisionReason': r}}))
" "$decision" "$reason"
  exit 0
}

# Check if any version file appears in git diff output.
# Mode: "staged" (--cached) or "branch" (baseBranch...HEAD)
check_version_bumped() {
  local mode="$1"
  while IFS= read -r vf; do
    [[ -z "$vf" ]] && continue
    local diff_out=""
    if [[ "$mode" == "staged" ]]; then
      diff_out=$(git -C "$PROJECT_DIR" diff --cached --name-only -- "$vf" 2>/dev/null || true)
    else
      diff_out=$(git -C "$PROJECT_DIR" diff "${BASE_BRANCH}...HEAD" --name-only -- "$vf" 2>/dev/null || true)
    fi
    if [[ -n "$diff_out" ]]; then
      echo "bumped"
      return
    fi
  done <<< "$VERSION_FILE_PATHS"
  echo "not_bumped"
}

# Check if all changed files match exclude patterns.
# Returns "excluded_only" or "has_source_changes".
check_changes_excluded() {
  local mode="$1"
  local changed=""
  if [[ "$mode" == "staged" ]]; then
    changed=$(git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null || true)
  else
    changed=$(git -C "$PROJECT_DIR" diff "${BASE_BRANCH}...HEAD" --name-only 2>/dev/null || true)
  fi

  [[ -z "$changed" ]] && echo "excluded_only" && return

  local has_source=false
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    local excluded=false
    while IFS= read -r pattern; do
      [[ -z "$pattern" ]] && continue
      # Match via bash glob — handle ** by stripping it to a prefix check
      local simple_pattern="${pattern//\*\*/\*}"
      if [[ "$f" == $simple_pattern ]] || [[ "$f" == $pattern ]]; then
        excluded=true
        break
      fi
    done <<< "$EXCLUDE_PATTERNS"
    if [[ "$excluded" == "false" ]]; then
      has_source=true
      break
    fi
  done <<< "$changed"

  if [[ "$has_source" == "true" ]]; then
    echo "has_source_changes"
  else
    echo "excluded_only"
  fi
}

# ─── Command dispatch ────────────────────────────────────────────────────────

CMD=$(echo "$COMMAND" | sed 's/^[[:space:]]*//' | tr -s ' ')

# Format version files list for messages
VF_LIST=$(echo "$VERSION_FILE_PATHS" | tr '\n' ' ' | sed 's/ $//')

# ── git commit ───────────────────────────────────────────────────────────────
if echo "$CMD" | grep -qE '^git\s+commit(\s|$)'; then
  # Skip detached HEAD
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  [[ -z "$CURRENT_BRANCH" ]] || [[ "$CURRENT_BRANCH" == "HEAD" ]] && exit 0

  bump=$(check_version_bumped "staged")
  [[ "$bump" == "bumped" ]] && exit 0

  changes=$(check_changes_excluded "staged")
  [[ "$changes" == "excluded_only" ]] && exit 0

  if [[ "$TRIGGER_STRATEGY" == "always" ]]; then
    permission_response "$ENFORCEMENT_MISSING_BUMP" \
"Version bump required but not found in staged files.

Version file(s): $VF_LIST
Strategy: always — every commit with source changes must include a version bump.

Please update the version in $VF_LIST, stage it, and commit together with your changes."
  else
    permission_response "$ENFORCEMENT_MISSING_BUMP" \
"No version bump detected in staged files.

Version file(s): $VF_LIST
Strategy: auto — evaluate whether these changes warrant a version bump:
  - New feature or capability → MINOR (x.Y.0)
  - Bug fix → PATCH (x.y.Z)
  - Breaking change → MAJOR (X.0.0)
  - Docs, config, refactor with no API change → skip

If a bump is needed, update $VF_LIST and stage it before committing.
Run /semver:guide for the full decision tree."
  fi
fi

# ── git push ─────────────────────────────────────────────────────────────────
if echo "$CMD" | grep -qE '^git\s+push(\s|$)'; then
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  [[ -z "$CURRENT_BRANCH" ]] || [[ "$CURRENT_BRANCH" == "HEAD" ]] && exit 0

  bump=$(check_version_bumped "branch")
  [[ "$bump" == "bumped" ]] && exit 0

  changes=$(check_changes_excluded "branch")
  [[ "$changes" == "excluded_only" ]] && exit 0

  permission_response "$ENFORCEMENT_MISSING_BUMP" \
"Pushing branch without a version bump.

Version file(s): $VF_LIST
No version file was modified compared to '${BASE_BRANCH}'.

If this branch contains meaningful changes, bump the version before pushing.
Run /semver:guide for SemVer decision rules."
fi

# ── gh pr create / gh pr merge ───────────────────────────────────────────────
if echo "$CMD" | grep -qE '^gh\s+pr\s+(create|merge)(\s|$)'; then
  bump=$(check_version_bumped "branch")
  [[ "$bump" == "bumped" ]] && exit 0

  changes=$(check_changes_excluded "branch")
  [[ "$changes" == "excluded_only" ]] && exit 0

  permission_response "$ENFORCEMENT_MISSING_BUMP" \
"Creating/merging PR without a version bump.

Version file(s): $VF_LIST
No version file was modified compared to '${BASE_BRANCH}'.

Without a version bump, caches and package managers may not pick up your changes.
Please bump the version before proceeding. Run /semver:guide for help."
fi

# Passthrough: let normal permission system handle everything else
exit 0
