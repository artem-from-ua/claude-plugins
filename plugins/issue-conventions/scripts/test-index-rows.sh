#!/bin/bash
# test-index-rows.sh — does the supersession rule read an ADR index row correctly?
#
# The rule reads two things from different places, for a reason:
#   whether a record was replaced  ← the strikethrough on number and title (structure)
#   which record replaced it       ← "superseded by NNNN" in the Status cell (prose)
#
# Anchoring "whether" on the prose is what fails. Three traps, all live in the
# reference project's 37-row index:
#   - "supersedes" is the successor, not the superseded. Five rows say it; a
#     naive search for "supersede" returns 10 of 37 instead of 5.
#   - "superseded by" sits mid-cell inside parentheses, so prefix matching or
#     normalizing the cell to its first word misses every partial supersession.
#   - Status wording is unconstrained. "accepted (0029 superseded by this record)"
#     would read naturally on a successor row and fool a phrase-only check.
#
# The Status cell is deliberately never struck through — that convention is what
# makes the split reliable.

set -uo pipefail

rows=(
"| ~~24~~ | ~~[Defaults for the safe_speech stage](0024-x.md)~~ | accepted (render display superseded by 0025) |SUPERSEDED:0025"
"| 25 | [Silence events](0025-x.md) | accepted (supersedes 0024 render display) |NO"
"| ~~26~~ | ~~[Proofread default off](0026-x.md)~~ | superseded by 0028 |SUPERSEDED:0028"
"| 28 | [Proofread default on](0028-x.md) | accepted (supersedes 0026) |NO"
"| ~~29~~ | ~~[Issue label taxonomy](0029-x.md)~~ | accepted (storage mechanism superseded by 0038; axes still in force) |SUPERSEDED:0038"
"| 38 | [Taxonomy storage](0038-x.md) | accepted (supersedes 0029 in part) |NO"
"| 30 | [Something else](0030-x.md) | accepted |NO"
"| 31 | [Hypothetical successor](0031-x.md) | accepted (0029 superseded by this record) |NO"
)

pass=0
fail=0

for entry in "${rows[@]}"; do
  expect="${entry##*|}"
  row="${entry%|*}"

  # Split off the Status cell (last column) from the identity columns.
  status="${row##*|}"
  identity="${row%|*}"

  if [[ "$identity" == *"~~"* ]]; then
    if [[ "$status" =~ superseded\ by\ ([0-9]{4}) ]]; then
      got="SUPERSEDED:${BASH_REMATCH[1]}"
    else
      got="SUPERSEDED:?"
    fi
  else
    got="NO"
  fi

  if [ "$got" = "$expect" ]; then
    echo "  ok    $got"
    pass=$((pass + 1))
  else
    echo "  FAIL  got '$got', expected '$expect'"
    echo "        row: $(echo "$row" | cut -c1-72)"
    fail=$((fail + 1))
  fi
done

echo
echo "Passed: $pass, failed: $fail"
echo "Load-bearing: rows 25, 28 and 38 say 'supersedes' and are successors;"
echo "row 31 phrases 'superseded by' on a successor and only the strikethrough saves it."
[ "$fail" -eq 0 ]
