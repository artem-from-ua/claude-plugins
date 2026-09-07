#!/bin/bash
# drift-check.sh — the mechanical half of the drift algorithm.
#
# The set operations over JSON need no model at all;
# this script runs them. The rest need judgment — numbers stated in human prose,
# a documented norm against the actual corpus — and are left to the drift-check
# subagent, which reads this output as its input.
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
# The dump stays on disk and reaches jq through --slurpfile. Passing it via
# --argjson puts the whole thing on argv, which dies with "Argument list too
# long" past ARG_MAX (1 MB on macOS) — around 200 issues with bodies, i.e.
# exactly the size where this plugin earns its keep.
ISSUES_FILE=$(bash "$SCRIPT_DIR/fetch-issues.sh")

# Modules on disk (the subagent decides what an uncovered one means).
#
# Private modules (a leading underscore, and `__init__`) are dropped entirely —
# they are implementation detail, never their own axis value. They therefore do
# NOT need to be listed in the axis's `ignore=`. Names are reported without their
# file extension: `transcode.py` becomes `transcode`, which is what an axis value
# is matched against.
MODULES="[]"
SRC_PATH=$(echo "$MODEL" | jq -r '[.axes[] | select(.source.kind == "modules")][0].source.path // empty')
if [[ -n "$SRC_PATH" && -d "$SRC_PATH" ]]; then
  MODULES=$(find "$SRC_PATH" -mindepth 1 -maxdepth 1 \( -type d -o -name '*.py' -o -name '*.ts' -o -name '*.go' -o -name '*.rs' -o -name '*.swift' \) \
    -exec basename {} \; 2>/dev/null \
    | sed 's/\.[A-Za-z0-9]*$//' \
    | grep -v '^_' \
    | sort -u \
    | jq -R . | jq -s .)
fi

jq -n \
  --argjson model "$MODEL" \
  --argjson live "$LIVE" \
  --slurpfile issuesWrapped "$ISSUES_FILE" \
  --argjson modules "$MODULES" \
  --arg doc "$DOC" '
  ($issuesWrapped[0]) as $issues
  | ($model.axes | map(.values[].label)) as $declared
  | (([$model.axes[] | .values[] | .name])
     + ([$model.titleFormat.allowedScopes[]? | .scope])) as $knownScopes
  | ($live | map(.name)) as $onGitHub
  | ($model.builtins.canonical) as $builtins
  | ($model.softLimit // 5) as $softLimit
  | ($issues | map(.labels[]) | group_by(.) | map({key: .[0], value: length})
     | from_entries) as $usage

  # --- mandatory-rule compliance (check 7) ---
  | [ $model.axes[] | select(.mandatory and .cardinality == "exactly one") ] as $exactlyOne
  | [ $model.crossAxisRules[] | select(.kind == "at-least-one") ] as $atLeastOne

  | {
      document: $doc,
      mechanical: {
        # declared but absent from GitHub
        missingOnGitHub: [ $declared[] | select(. as $d | $onGitHub | index($d) | not) ],

        # on GitHub but undeclared (Dependabot and friends) — reported, never auto-deleted
        undeclaredOnGitHub: [ $onGitHub[] | select(. as $g | $declared | index($g) | not) ],

        # color or description drift (someone edited in the UI)
        metadataDrift: [
          $model.axes[] | .values[] as $v
          | ($live[] | select(.name == $v.label)) as $l
          | select((($l.color | ascii_downcase) != (($v.color // "#cccccc") | ltrimstr("#") | ascii_downcase))
                   or (($l.description // "") != $v.description))
          | {label: $v.label,
             github: {color: $l.color, description: ($l.description // "")},
             document: {color: ($v.color // "#cccccc" | ltrimstr("#")), description: $v.description}}
        ],

        # issues violating cardinality / cross-axis rules / soft limit
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
          # A documented exception is a decision, not a violation. Without this
          # the same issue is reported on every run, forever.
          | ([$model.ruleExceptions[]? | select((.issue | tonumber?) == $i.number) | .rule]) as $exempt
          | ($bad | map(select(.axis as $a | $exempt | index($a) | not))) as $bad
          | ($badCross | map(select(.rule as $r | $exempt | any(. == "at-least-one" or . == $r) | not))) as $badCross
          | select(($bad | length) > 0 or ($badCross | length) > 0 or (($i.labels | length) > $softLimit))
          | {number: $i.number, labels: $i.labels,
             cardinality: $bad, crossAxis: $badCross,
             overSoftLimit: (($i.labels | length) > $softLimit)}
        ],

        # declared values nobody uses — INFO only, never a divergence
        unusedValues: [ $declared[] | select(($usage[.] // 0) == 0) ],

        # GitHub silently re-created a built-in
        builtinsPresent: [ $builtins[] | select(. as $b | $onGitHub | index($b)) ]
      },

      # input for the judgment half
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

        # Scopes used in titles that match no axis value. The title-format regex
        # accepts any word inside the parentheses, so a scope can be well-formed
        # and still name something that does not exist. Provenance-labelled issues
        # are exempt: their titles belong to the automation that filed them.
        titleScopes: [
          $issues[]
          | select([.labels[] | startswith("by:")] | any | not)
          | select(.title | test("^(?:CRITICAL )?[a-z]+\\([^)]+\\):"))
          | {number, title,
             scope: (.title | capture("^(?:CRITICAL )?[a-z]+\\((?<s>[^)]+)\\):") | .s)}
          | .scope as $s
          | select($knownScopes | index($s) | not)
        ],
        footer: $model.footer,
        warnings: $model.warnings
      }
    }
'
