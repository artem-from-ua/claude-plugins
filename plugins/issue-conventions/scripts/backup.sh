#!/bin/bash
# backup.sh — shared preflight for both mutating commands.
#
# `gh label delete` strips the label from every issue that carried it, and no
# --force brings that back. Both setup (before applying the label plan) and
# relabel (before classification) call this first.
#
# Writes labels.json, issues.json and a ready-to-run ROLLBACK.md.
# Prints the backup directory path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for tool in gh jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required" >&2; exit 1; }
done

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
STAMP=$(date +%Y-%m-%d-%H%M%S)
DIR="${TMPDIR:-/tmp}/issue-conventions-backup-${STAMP}-${UID}"
mkdir -p "$DIR"

gh label list --limit 500 --json name,color,description > "$DIR/labels.json"
bash "$SCRIPT_DIR/fetch-issues.sh" --out "$DIR/issues.json" >/dev/null

LABEL_COUNT=$(jq 'length' "$DIR/labels.json")
ISSUE_COUNT=$(jq 'length' "$DIR/issues.json")

{
  echo "# Rollback — $REPO"
  echo
  echo "Snapshot taken $STAMP: $LABEL_COUNT labels, $ISSUE_COUNT issues."
  echo
  echo "## Restore every label (color and description included)"
  echo
  echo '```bash'
  jq -r '.[] | "gh label create \"\(.name)\" --color \"\(.color)\" --description \"\(.description // "")\" --force"' \
    "$DIR/labels.json"
  echo '```'
  echo
  echo "## Restore the label set of every issue"
  echo
  echo "Each command replaces the issue's labels with what they were at snapshot time."
  echo
  echo '```bash'
  jq -r '.[] | select((.labels | length) > 0)
         | "gh issue edit \(.number) --add-label \"\(.labels | join(","))\""' \
    "$DIR/issues.json"
  echo '```'
  echo
  echo "Issues that carried no labels at snapshot time are not listed; strip labels"
  echo "from them by hand if a run added some."
} > "$DIR/ROLLBACK.md"

echo "$DIR"
