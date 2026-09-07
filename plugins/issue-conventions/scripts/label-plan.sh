#!/bin/bash
# label-plan.sh — diff the taxonomy document against the live GitHub labels.
#
# The document is the source of truth: this plan always pulls GitHub up to the
# document, never the reverse. Emits JSON with create/update/delete/unknown groups.
#
# `unknown` lists labels that exist on GitHub but not in the taxonomy — they are
# NOT scheduled for deletion. Foreign labels (Dependabot's, for one) are reported
# so a human decides, exactly as the legacy mapping's `keep` action intends.
#
# Usage:
#   label-plan.sh <taxonomy-document.md> [--summary]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOC="${1:-}"
SUMMARY=0
APPLY=0
case "${2:-}" in
  --summary) SUMMARY=1 ;;
  --apply)   APPLY=1 ;;
  "")        ;;
  *) echo "unknown option: $2" >&2; exit 2 ;;
esac

if [[ -z "$DOC" || ! -f "$DOC" ]]; then
  echo "usage: label-plan.sh <taxonomy-document.md> [--summary|--apply]" >&2
  exit 2
fi

for tool in gh jq python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required" >&2; exit 1; }
done

MODEL=$(python3 "$SCRIPT_DIR/parse-taxonomy.py" "$DOC")
LIVE=$(gh label list --limit 500 --json name,color,description)

PLAN=$(jq -n --argjson model "$MODEL" --argjson live "$LIVE" '
  ($model.axes | map(.values[] | {
      name: .label,
      color: (.color // "cccccc" | ltrimstr("#")),
      description: .description
  })) as $want
  | ($live | map({name, color: (.color | ascii_downcase), description: (.description // "")})) as $have
  | ($want | map(.name)) as $wantNames
  | ($have | map(.name)) as $haveNames
  | {
      create: [ $want[] | select(.name as $n | $haveNames | index($n) | not) ],
      update: [ $want[] as $w
                | ($have[] | select(.name == $w.name)) as $h
                | select(($h.color != ($w.color | ascii_downcase)) or ($h.description != $w.description))
                | {name: $w.name, from: {color: $h.color, description: $h.description},
                   to: {color: $w.color, description: $w.description}} ],
      unknown: [ $have[] | select(.name as $n | $wantNames | index($n) | not) | .name ]
    }
')

if [[ "$APPLY" -eq 1 ]]; then
  # Creates and updates only. Undeclared labels are never touched here — they
  # belong to someone else, or to a decision the user has not made yet. Nor are
  # legacy labels deleted: relabel classifies from them, so removing them is the
  # last step of the migration, not part of applying the plan.
  applied=0
  failed=0
  while IFS=$'\t' read -r name color desc; do
    [[ -z "$name" ]] && continue
    if gh label create "$name" --color "$color" --description "$desc" --force >/dev/null 2>&1; then
      applied=$((applied + 1))
    else
      failed=$((failed + 1))
      echo "  failed: $name" >&2
    fi
    sleep 0.3
  done < <(echo "$PLAN" | jq -r '(.create + (.update | map({name, color: .to.color, description: .to.description})))[]
                                 | [.name, .color, .description] | @tsv')

  echo "applied $applied label(s)"
  [[ "$failed" -gt 0 ]] && { echo "$failed failed — see above" >&2; exit 1; }
  exit 0
fi

if [[ "$SUMMARY" -eq 1 ]]; then
  echo "$PLAN" | jq -r '"Create \(.create | length) · Update \(.update | length) · Undeclared on GitHub \(.unknown | length)"'
else
  echo "$PLAN"
fi
