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

# ADR supersession status, decided by script rather than re-derived from prose
# each run. The subagent still judges what a divergence *means*; this settles
# the fact it reasons from. Path comes from the config, if there is one.
# Reports *why* there is nothing to compare, never a bare null: "not configured"
# and "configured but the file is missing" look identical otherwise, and the
# second is a broken setup reading as a clean one.
ADR_STATE="not-configured"
ADR_RECORDS="[]"
ADR_MISSING="[]"

CONFIG="${CLAUDE_PROJECT_DIR:-.}/.claude-plugin/issue-conventions.json"
[[ -f "$CONFIG" ]] || CONFIG="${CLAUDE_PROJECT_DIR:-.}/.claude/issue-conventions.json"
if [[ -f "$CONFIG" ]]; then
  ADR_PATHS=$(jq -r '(.adr // empty) | if type == "array" then .[] else . end' "$CONFIG" 2>/dev/null || true)
  if [[ -n "$ADR_PATHS" ]]; then
    found=""
    missing=""
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      if [[ -f "$p" ]]; then
        found+="$(bash "$SCRIPT_DIR/adr-status.sh" "$p" 2>/dev/null)"$'\n'
      else
        missing+="$p"$'\n'
      fi
    done <<< "$ADR_PATHS"

    [[ -n "$found" ]] && ADR_RECORDS=$(printf '%s' "$found" | jq -sc . 2>/dev/null || echo '[]')
    [[ -n "$missing" ]] && ADR_MISSING=$(printf '%s' "$missing" | jq -R 'select(length > 0)' | jq -sc .)

    if [[ "$ADR_MISSING" != "[]" ]]; then
      ADR_STATE="configured-but-missing"
    else
      ADR_STATE="checked"
    fi
  fi
fi

ADR_STATUS=$(jq -n --arg state "$ADR_STATE" \
                   --argjson records "$ADR_RECORDS" \
                   --argjson missing "$ADR_MISSING" \
                   '{state: $state, records: $records, missingPaths: $missing}')
LIVE=$(gh label list --limit 500 --json name,color,description)
# The dump stays on disk and reaches jq through --slurpfile. Passing it via
# --argjson puts the whole thing on argv, which dies with "Argument list too
# long" past ARG_MAX (1 MB on macOS) — around 200 issues with bodies, i.e.
# exactly the size where this plugin earns its keep.
ISSUES_FILE=$(bash "$SCRIPT_DIR/fetch-issues.sh")

# Modules on disk, for check 9's input (the subagent decides what it means).
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
  --argjson adrStatus "$ADR_STATUS" \
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
        # 1. declared but absent from GitHub
        missingOnGitHub: [ $declared[] | select(. as $d | $onGitHub | index($d) | not) ],

        # 2. on GitHub but undeclared (Dependabot and friends) — reported, never auto-deleted
        undeclaredOnGitHub: [ $onGitHub[] | select(. as $g | $declared | index($g) | not) ],

        # 3. color or description drift (someone edited in the UI)
        metadataDrift: [
          $model.axes[] | .values[] as $v
          | ($live[] | select(.name == $v.label)) as $l
          | select((($l.color | ascii_downcase) != (($v.color // "#cccccc") | ltrimstr("#") | ascii_downcase))
                   or (($l.description // "") != $v.description))
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
        adrStatus: $adrStatus,
        footer: $model.footer,
        warnings: $model.warnings
      }
    }
'
