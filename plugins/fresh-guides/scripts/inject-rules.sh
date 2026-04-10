#!/bin/bash
# inject-rules.sh — SessionStart hook for fresh-guides plugin
# Reads watchlist config and outputs compact verification rules.
# Silent exit (zero output) when no config or empty watchlist.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
VERSION=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "?")

PROJECT_CONFIG="${CLAUDE_PROJECT_DIR:-.}/.claude-plugin/fresh-guides.json"
GLOBAL_CONFIG="$HOME/.claude/fresh-guides.json"

# Determine which config(s) to use
PROJECT_WATCHLIST=""
GLOBAL_WATCHLIST=""
CHECK_MODE="alert-and-verify"

if [[ -f "$PROJECT_CONFIG" ]]; then
  PROJECT_WATCHLIST=$(jq -r '.watchlist // [] | length' "$PROJECT_CONFIG" 2>/dev/null || echo "0")
  CHECK_MODE=$(jq -r '.checkMode // "alert-and-verify"' "$PROJECT_CONFIG" 2>/dev/null || echo "alert-and-verify")
fi

if [[ -f "$GLOBAL_CONFIG" ]]; then
  GLOBAL_WATCHLIST=$(jq -r '.watchlist // [] | length' "$GLOBAL_CONFIG" 2>/dev/null || echo "0")
  if [[ "$CHECK_MODE" == "alert-and-verify" && -z "$PROJECT_WATCHLIST" ]]; then
    CHECK_MODE=$(jq -r '.checkMode // "alert-and-verify"' "$GLOBAL_CONFIG" 2>/dev/null || echo "alert-and-verify")
  fi
fi

# Silent exit if no config
if [[ ! -f "$PROJECT_CONFIG" && ! -f "$GLOBAL_CONFIG" ]]; then
  exit 0
fi

# Merge watchlists: project entries override global entries with same name
MERGED=$(jq -n '
  def merge_lists(global; project):
    (global // []) as $g |
    (project // []) as $p |
    ($p | map(.name) | map(ascii_downcase)) as $pnames |
    [$g[] | select((.name | ascii_downcase) as $n | $pnames | index($n) | not)] + $p;

  input as $global |
  input as $project |
  merge_lists($global.watchlist; $project.watchlist)
' <(if [[ -f "$GLOBAL_CONFIG" ]]; then cat "$GLOBAL_CONFIG"; else echo '{"watchlist":[]}'; fi) \
  <(if [[ -f "$PROJECT_CONFIG" ]]; then cat "$PROJECT_CONFIG"; else echo '{"watchlist":[]}'; fi) 2>/dev/null || echo '[]')

# Count entries
COUNT=$(echo "$MERGED" | jq 'length' 2>/dev/null || echo "0")

# Silent exit if empty watchlist
if [[ "$COUNT" == "0" ]]; then
  exit 0
fi

# Emit compact output (≤300 tokens)
printf '<!-- Source: Plugin fresh-guides@tribe-coding (v%s) -->\n' "$VERSION"
printf '## Fresh Guides — Fast-Changing Technology Watchlist\n\n'
printf 'These technologies change frequently — model training data may be outdated.\n'
printf 'When the conversation involves any of them AND advice is version-specific:\n'

if [[ "$CHECK_MODE" == "alert-and-verify" ]]; then
  printf '1. **Alert**: "fresh-guides: <name> is on your fast-changing tech watchlist."\n'
  printf '2. **Verify** by invoking the `fresh-guides-verify` skill BEFORE giving version-specific advice.\n'
  printf '3. **Cite** the source URL and date when providing verified information.\n\n'
else
  printf '1. **Alert**: "fresh-guides: <name> is on your fast-changing tech watchlist — verify before relying on my answer."\n\n'
fi

printf '**Watchlist:**\n'

# Format each entry: name → docs (version)
echo "$MERGED" | jq -r '
  .[:10] | .[] |
  "- \(.name) → \(.docs | join(", ")) (\(.version // "latest"))"
' 2>/dev/null

OVERFLOW=$((COUNT - 10))
if [[ "$OVERFLOW" -gt 0 ]]; then
  printf '- ...and %d more\n' "$OVERFLOW"
fi

if [[ "$CHECK_MODE" == "alert-and-verify" ]]; then
  printf '\nWhen you need to verify → invoke `fresh-guides-verify` skill.\n'
fi
printf 'Run `/fresh-guides-setup` to configure, `/fresh-guides-show` to view, `/fresh-guides-update` to modify.\n'
