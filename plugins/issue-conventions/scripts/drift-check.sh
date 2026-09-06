#!/bin/bash
# drift-check.sh — the mechanical half of the drift algorithm.
#
# Checks 1, 2, 3, 7, 8, 11 are set operations over JSON and need no model at all;
# this script runs them. Checks 4, 5, 6, 9, 10 need judgment (numbers stated in
# human prose, "documented norm vs the actual corpus", ADR freshness) and are left
# to the drift-check subagent, which reads this output as its input.
#
# The taxonomy document is the source of truth: every finding names the two
# sources that disagree, and the fix always pulls GitHub up to the document.
#
# Usage: drift-check.sh <taxonomy-document.md>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOC="${1:-}"

if [[ -z "$DOC" || ! -f "$DOC" ]]; then
  echo "usage: drift-check.sh <taxonomy-document.md>" >&2
  exit 2
fi

for tool in gh jq python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required" >&2; exit 1; }
done

MODEL=$(python3 "$SCRIPT_DIR/parse-taxonomy.py" "$DOC")
LIVE=$(gh label list --limit 500 --json name,color,description)
ISSUES_FILE=$(bash "$SCRIPT_DIR/fetch-issues.sh")
ISSUES=$(cat "$ISSUES_FILE")

# Modules on disk, for check 9's input (the subagent decides what it means).
MODULES="[]"
SRC_PATH=$(echo "$MODEL" | jq -r '[.axes[] | select(.source.kind == "modules")][0].source.path // empty')
if [[ -n "$SRC_PATH" && -d "$SRC_PATH" ]]; then
  MODULES=$(find "$SRC_PATH" -mindepth 1 -maxdepth 1 \( -type d -o -name '*.py' -o -name '*.ts' -o -name '*.go' -o -name '*.rs' -o -name '*.swift' \) \
    -exec basename {} \; 2>/dev/null \
    | sed 's/\.[a-z]*$//' \
    | grep -v '^_' \
    | sort -u \
    | jq -R . | jq -s .)
fi

jq -n \
  --argjson model "$MODEL" \
  --argjson live "$LIVE" \
  --argjson issues "$ISSUES" \
  --argjson modules "$MODULES" \
  --arg doc "$DOC" '
  ($model.axes | map(.values[].label)) as $declared
  | ($live | map(.name)) as $onGitHub
  | ($model.builtins.canonical) as $builtins
  | ($model.softLimit // 5) as $softLimit
  | ($issues | map(.labels[]) | group_by(.) | map({key: .[0], count: length})
     | from_entries) as $usage

  # --- mandatory-rule compliance (check 7) ---
  | [ $model.axes[] | select(.mandatory and .cardinality == "exactly one") ] as $exactlyOne
  | [ $model.crossAxisRules[] | select(.kind == "at-least-one") ] as $atLeastOne

  | {
      document: $doc,
      mechanical: {
        # 1. declared but absent from GitHub
        missingOnGitHub: [ $declared[] | select(. as $d | $onGitHub | index($d) | not) ],

        # 2. on GitHub but undeclared (Dependabot and friends) — reported, never auto-deleted
        undeclaredOnGitHub: [ $onGitHub[] | select(. as $g | $declared | index($g) | not) ],

        # 3. color or description drift (someone edited in the UI)
        metadataDrift: [
          $model.axes[] | .values[] as $v
          | ($live[] | select(.name == $v.label)) as $l
          | select((($l.color | ascii_downcase) != (($v.color // "#cccccc") | ltrimstr("#") | ascii_downcase))
                   or ((.description // "") != $v.description))
          | {label: $v.label,
             github: {color: $l.color, description: ($l.description // "")},
             document: {color: ($v.color // "#cccccc" | ltrimstr("#")), description: $v.description}}
        ],

        # 7. issues violating cardinality / cross-axis rules / soft limit
        violations: [
          $issues[] as $i
          | ($exactlyOne | map(. as $ax
              | {axis: $ax.name,
                 n: ([$i.labels[] | select(startswith($ax.prefix))] | length)})
             | map(select(.n != 1))) as $bad
          | ($atLeastOne | map(. as $r
              | {rule: ($r.axes | join("/")),
                 n: ([$i.labels[] | . as $l
                      | select([$r.axes[] as $a | $l | startswith($a + ":")] | any)] | length)})
             | map(select(.n == 0))) as $badCross
          | select(($bad | length) > 0 or ($badCross | length) > 0 or (($i.labels | length) > $softLimit))
          | {number: $i.number, labels: $i.labels,
             cardinality: $bad, crossAxis: $badCross,
             overSoftLimit: (($i.labels | length) > $softLimit)}
        ],

        # 8. declared values nobody uses — INFO only, never a divergence
        unusedValues: [ $declared[] | select(($usage[.] // 0) == 0) ],

        # 11. GitHub silently re-created a built-in
        builtinsPresent: [ $builtins[] | select(. as $b | $onGitHub | index($b)) ]
      },

      # input for the judgment half (checks 4, 5, 6, 9, 10)
      forSubagent: {
        softLimit: $softLimit,
        labelCountDistribution: ($issues | map(.labels | length) | group_by(.)
                                 | map({labels: .[0], issues: length})),
        issueCount: ($issues | length),
        declaredCount: ($declared | length),
        axisSizes: [ $model.axes[] | {axis: .name, values: (.values | length)} ],
        modulesOnDisk: $modules,
        modulesIgnored: [ $model.axes[] | select(.source.kind == "modules") | .source.ignore[] ],
        moduleAxis: ([ $model.axes[] | select(.source.kind == "modules") ][0].name // null),
        footer: $model.footer,
        warnings: $model.warnings
      }
    }
'
