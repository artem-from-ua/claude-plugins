#!/bin/bash
# test-drift-jq.sh — regression tests for the jq expressions in drift-check.sh.
#
# Both bugs below shipped in 0.1.0 and were caught on the first polygon. They
# share a shape: jq stayed silent and produced plausible-looking output, so
# neither showed up in a syntax check. These tests pin the semantics instead.
#
# Usage: test-drift-jq.sh [path-to-drift-check.sh]

set -uo pipefail

SCRIPT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/drift-check.sh}"
pass=0
fail=0

ok()  { echo "  ok    $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; fail=$((fail + 1)); }

echo "=== usage counting: from_entries needs .value, not .count ==="

# Bug: map({key, count}) makes from_entries yield {"a": null}, so every declared
# value looked unused — 36 of 36 on the first polygon, drowning the five real ones.
usage=$(jq -nc '[{"labels":["a","b"]},{"labels":["a"]}]
                | map(.labels[]) | group_by(.) | map({key: .[0], value: length})
                | from_entries')
[ "$(echo "$usage" | jq -r '.a')" = "2" ] && ok "counts survive from_entries" \
  || bad "counts lost: $usage"

unused=$(jq -nc --argjson usage "$usage" '["a","b","c"] | map(select(($usage[.] // 0) == 0))')
[ "$unused" = '["c"]' ] && ok "only genuinely unused values reported" \
  || bad "expected [\"c\"], got $unused"

if grep -q 'map({key: .\[0\], count: length})' "$SCRIPT"; then
  bad "drift-check.sh still uses 'count:' in from_entries"
else
  ok "drift-check.sh uses 'value:' in from_entries"
fi

echo
echo "=== metadata drift: compare \$l.description, not .description ==="

# Bug: inside `($live[] | select(...)) as $l | select(...)`, a bare `.` is still
# the *value* being iterated, not $l. `(.description != $v.description)` compared
# a thing to itself and was always true, flagging every label as drifted — while
# label-plan.sh, which got this right, reported zero updates on the same data.
live='[{"name":"type:bug","color":"b60205","description":"Broken."},
       {"name":"type:docs","color":"cccccc","description":"Docs only."}]'

identical=$(jq -n --argjson live "$live" \
  --argjson v '{"label":"type:bug","color":"#b60205","description":"Broken."}' '
  [ ($live[] | select(.name == $v.label)) as $l
    | select((($l.color | ascii_downcase) != (($v.color // "#cccccc") | ltrimstr("#") | ascii_downcase))
             or (($l.description // "") != $v.description)) ] | length')
[ "$identical" = "0" ] && ok "identical label produces no finding" \
  || bad "false positive on identical label (got $identical)"

changed=$(jq -n --argjson live "$live" \
  --argjson v '{"label":"type:docs","color":"#cccccc","description":"Documentation changes."}' '
  [ ($live[] | select(.name == $v.label)) as $l
    | select((($l.color | ascii_downcase) != (($v.color // "#cccccc") | ltrimstr("#") | ascii_downcase))
             or (($l.description // "") != $v.description)) ] | length')
[ "$changed" = "1" ] && ok "changed description is detected" \
  || bad "real drift missed (got $changed)"

recolored=$(jq -n --argjson live "$live" \
  --argjson v '{"label":"type:bug","color":"#ff0000","description":"Broken."}' '
  [ ($live[] | select(.name == $v.label)) as $l
    | select((($l.color | ascii_downcase) != (($v.color // "#cccccc") | ltrimstr("#") | ascii_downcase))
             or (($l.description // "") != $v.description)) ] | length')
[ "$recolored" = "1" ] && ok "changed color is detected" \
  || bad "color drift missed (got $recolored)"

if grep -q 'or ((\.description // "") != \$v\.description)' "$SCRIPT"; then
  bad "drift-check.sh still compares bare .description"
else
  ok "drift-check.sh compares \$l.description"
fi

echo
echo "=== module list: private modules dropped, extension stripped ==="

mods=$(printf '_prompts.py\n__init__.py\ntranscode.py\nrender.PY\n' \
  | sed 's/\.[A-Za-z0-9]*$//' | grep -v '^_' | sort -u | tr '\n' ' ')
[ "$mods" = "render transcode " ] && ok "private dropped, extensions stripped (incl. uppercase)" \
  || bad "unexpected module list: '$mods'"

echo
echo "=== title scopes: bind the scope before index(), or . means the array ==="

# Same trap as bug 2 above, one layer along: after `$known | index(...)`, the dot
# refers to $known, not to the object being filtered. `index(.scope)` therefore
# asks jq to index an array with a string and dies at runtime.
scope_model='{"axes":[{"name":"stage","values":[{"name":"proofread"}]},
                      {"name":"area","values":[{"name":"llm"}]}]}'
scope_issues='[
  {"number":1,"title":"feat(proofread): known","labels":["type:feature"]},
  {"number":2,"title":"research(pipeline): never exists","labels":["type:docs"]},
  {"number":3,"title":"feat(followup): proposes a stage","labels":["type:feature"]},
  {"number":4,"title":"CRITICAL fix(llm): known, with prefix","labels":["type:bug"]},
  {"number":5,"title":"chore(nope): bot-filed","labels":["by:kb-grooming"]},
  {"number":6,"title":"no scope at all","labels":["type:docs"]}
]'

scopes=$(jq -c -n --argjson model "$scope_model" --argjson issues "$scope_issues" '
  ([$model.axes[] | .values[] | .name]) as $knownScopes
  | [ $issues[]
      | select([.labels[] | startswith("by:")] | any | not)
      | select(.title | test("^(?:CRITICAL )?[a-z]+\\([^)]+\\):"))
      | {number, scope: (.title | capture("^(?:CRITICAL )?[a-z]+\\((?<s>[^)]+)\\):") | .s)}
      | .scope as $s
      | select($knownScopes | index($s) | not) ]' 2>&1)

[ "$scopes" = '[{"number":2,"scope":"pipeline"},{"number":3,"scope":"followup"}]' ] \
  && ok "unknown scopes found; known, exempt and scope-less titles skipped" \
  || bad "unexpected: $scopes"

if grep -q 'index(\.scope)' "$SCRIPT"; then
  bad "drift-check.sh still calls index(.scope) — the dot is the array there"
else
  ok "drift-check.sh binds the scope before index()"
fi

echo
echo "Пройдено: $pass, провалено: $fail"
[ "$fail" -eq 0 ]
