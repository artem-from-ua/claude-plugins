#!/bin/bash
# fetch-issues.sh — dump every issue in the repo to JSON.
#
# Uses the REST API with --paginate, NOT `gh issue list --json`: that command
# silently caps at roughly 60 items even with --limit 200 (anti-pattern #1 in
# issue #324). Pull requests are filtered out — the REST issues endpoint
# returns them too.
#
# Usage:
#   fetch-issues.sh                 # writes the dump, prints its path
#   fetch-issues.sh --count-only    # prints just the issue count
#   fetch-issues.sh --out FILE      # writes to FILE instead of the default

set -euo pipefail

OUT=""
COUNT_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --count-only) COUNT_ONLY=1; shift ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

for tool in gh jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required" >&2; exit 1; }
done

gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated — run: gh auth login" >&2; exit 1; }

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
: "${OUT:=${TMPDIR:-/tmp}/issue-conventions-issues-${UID}.json}"

gh api "repos/$REPO/issues?state=all&per_page=100" --paginate \
  | jq -s 'add | map(select(.pull_request == null))
           | map({number, title, state, body,
                  labels: [.labels[].name],
                  closedAt: .closed_at})' > "$OUT"

if [[ "$COUNT_ONLY" -eq 1 ]]; then
  jq 'length' "$OUT"
else
  echo "$OUT"
fi
