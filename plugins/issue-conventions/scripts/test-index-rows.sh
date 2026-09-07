#!/bin/bash
# test-index-rows.sh — does the supersession rule read an ADR index row correctly?
#
# Two traps, pulling in opposite directions, both found on the first polygon:
#   - "superseded by" sits mid-cell inside parentheses, so prefix matching or
#     normalizing the cell to its first word sees only "accepted" and misses it;
#   - "supersedes" is the successor, not the superseded — a substring search for
#     "supersede" marks the replacement as replaced.
#
# Rows below are verbatim from the reference project's docs/adr/README.md.

set -uo pipefail

rows=(
"| ~~24~~ | ~~[Defaults for the safe_speech stage](0024-x.md)~~ | accepted (render display superseded by 0025) |SUPERSEDED:0025"
"| 25 | [Silence events](0025-x.md) | accepted (supersedes 0024 render display) |NO"
"| ~~26~~ | ~~[Proofread default off](0026-x.md)~~ | superseded by 0028 |SUPERSEDED:0028"
"| 28 | [Proofread default on](0028-x.md) | accepted (supersedes 0026) |NO"
"| ~~29~~ | ~~[Issue label taxonomy](0029-x.md)~~ | accepted (storage mechanism superseded by 0038; axes still in force) |SUPERSEDED:0038"
"| 30 | [Something else](0030-x.md) | accepted |NO"
)

pass=0
fail=0

for entry in "${rows[@]}"; do
  expect="${entry##*|}"

  # The rule: "superseded by" as a substring anywhere in the row, successor
  # number taken from what follows it. Not a prefix, and not bare "supersede".
  if [[ "$entry" =~ superseded\ by\ ([0-9]{4}) ]]; then
    got="SUPERSEDED:${BASH_REMATCH[1]}"
  else
    got="NO"
  fi

  if [ "$got" = "$expect" ]; then
    echo "  ok    $got"
    pass=$((pass + 1))
  else
    echo "  FAIL  got '$got', expected '$expect'"
    echo "        row: $(echo "$entry" | cut -c1-70)"
    fail=$((fail + 1))
  fi
done

echo
echo "Passed: $pass, failed: $fail"
echo "The load-bearing cases are rows 25 and 28: they say 'supersedes' and are"
echo "successors, not superseded records."
[ "$fail" -eq 0 ]
