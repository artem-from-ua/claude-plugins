#!/bin/bash
# inject-rules.sh — SessionStart hook for the issue-conventions plugin.
# Prints three lines, and only in repositories that have a taxonomy configured.
# Silent exit (zero output, zero tokens) everywhere else.
#
# Cache determinism: no date, no git log, no $RANDOM, no network. The sync date is
# read verbatim from the document footer, so the output changes only when the
# document changes — config-dependent, like playbook and semver.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

CONFIG="$PROJECT_DIR/.claude-plugin/issue-conventions.json"
[[ -f "$CONFIG" ]] || CONFIG="$PROJECT_DIR/.claude/issue-conventions.json"
[[ -f "$CONFIG" ]] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

DOC=$(jq -r '.taxonomyDocument // empty' "$CONFIG" 2>/dev/null || true)
[[ -n "$DOC" ]] || exit 0

DOC_PATH="$PROJECT_DIR/$DOC"
[[ -f "$DOC_PATH" ]] || exit 0

VERSION=$(jq -r '.version // "?"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "?")

# Sync date from the footer table row "| Last synced with GitHub | YYYY-MM-DD |".
SYNCED=$(grep -i '^| *Last synced' "$DOC_PATH" 2>/dev/null \
  | head -1 \
  | awk -F'|' '{gsub(/^[ \t`]+|[ \t`]+$/, "", $3); print $3}' || true)

cat <<EOF
<!-- Source: Plugin issue-conventions@artem-from-ua (v$VERSION) -->
## Issue Conventions — Active in This Repo

This repository has an issue taxonomy: \`$DOC\`${SYNCED:+ (last synced with GitHub: $SYNCED)}.

**ALWAYS invoke the \`issue-conventions-guide\` skill BEFORE** \`gh issue create\`, \`gh issue edit\`, \`gh issue close\`, or any label change. The skill routes to a subagent that reads the taxonomy — do not classify from memory.

Run \`/issue-conventions:drift\` to check that the document, GitHub labels, and the ADR still agree.
EOF
