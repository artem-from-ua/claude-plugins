#!/bin/bash
# test-scale.sh — do the scripts survive a corpus larger than the author's own repo?
#
# Twice in this plugin's history a limit sat exactly where the tool starts being
# useful, and both times a live run found it rather than a test:
#
#   `gh issue list --json` silently truncates at ~60 issues
#   `--argjson` exceeds the execve argument limit, around 200 issues with bodies
#
# That is not coincidence. A plugin gets exercised on its author's repository,
# which is always smaller than the backlog it was written for. So the fixture is
# deliberately larger than any real repo here: 500 issues, ~2.4 MB.
#
# The tests observe rather than calculate. Each one runs the failing form and
# requires it to fail — so a fixture that has gone stale announces itself instead
# of quietly passing. That matters most for the argv limit, which is not a fixed
# number: `getconf ARG_MAX` is an upper bound, while execve also counts the
# environment and the argv pointers, so the real ceiling moves with the user's
# shell.
#
# Usage: test-scale.sh [path-to-scripts-dir]

set -uo pipefail

DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
pass=0
fail=0

ok()  { echo "  ok    $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; fail=$((fail + 1)); }

DUMP="$WORK/issues.json"
python3 - "$DUMP" <<'PY'
import json, sys
issues = []
for i in range(1, 501):
    issues.append({
        "number": i,
        "title": f"feat(core): synthetic issue {i} for scale testing",
        "state": "open" if i % 3 else "closed",
        "body": "Body text repeated to reach a realistic size. " * 100,
        "labels": ["type:feature", "priority:medium"] if i % 2 else ["type:bug"],
        "closedAt": None,
    })
json.dump(issues, open(sys.argv[1], "w"))
PY

SIZE=$(wc -c < "$DUMP" | tr -d ' ')
# getconf is printed as diagnostics, never asserted against: it is an upper
# bound, so it explains *why* a stale fixture stopped reproducing the failure
# without being trusted to decide *whether* it has.
echo "fixture: $SIZE bytes, 500 issues (getconf ARG_MAX: $(getconf ARG_MAX), env: $(env | wc -c | tr -d ' ') bytes)"
echo

echo "=== the bug still reproduces at this size ==="

# Observe, do not compute. `getconf ARG_MAX` is an upper bound, not the limit
# execve enforces: the real ceiling also counts the environment and the argv
# pointer array, so it moves with however many variables the user exports.
# Measured here: getconf reported 1048576 while jq actually failed at ~1040234,
# a gap of roughly the environment's own size.
#
# A guard that compares against getconf can therefore claim the fixture is large
# enough when it no longer is. Running the old form and requiring it to fail is
# exact: if it ever stops failing, the fixture has gone stale, and that is the
# signal — not an estimate of one.
BIG=$(cat "$DUMP")
err=$(jq -n --argjson issues "$BIG" '$issues | length' 2>&1)
if [ -n "$err" ] && printf '%s' "$err" | grep -qi 'argument list too long'; then
  ok "--argjson dies with 'Argument list too long', as on the second polygon"
elif [ -z "$err" ]; then
  bad "--argjson accepted $SIZE bytes — the fixture no longer reproduces the bug; enlarge it"
else
  bad "--argjson failed for an unexpected reason: $err"
fi

echo
echo "=== --slurpfile handles it ==="
n=$(jq -n --slurpfile w "$DUMP" '$w[0] | length' 2>&1)
[ "$n" = "500" ] && ok "--slurpfile read all 500" || bad "--slurpfile returned: $n"

echo
echo "=== drift-check.sh passes the dump by file, not argv ==="
if grep -q 'argjson issues' "$DIR/drift-check.sh"; then
  bad "drift-check.sh passes issues through argv again"
else
  ok "drift-check.sh does not use --argjson for the dump"
fi

echo
echo "=== fetch-issues.sh pages rather than truncating ==="
# Match a call, not a mention. The script names `gh issue list` precisely to
# explain why it does not use it — the most conscientiously written file defeats
# the simplest check. `^[^#]*` anchors on the line up to any comment, which also
# catches a trailing comment on a line of real code.
if grep -qE '^[^#]*gh issue list' "$DIR/fetch-issues.sh"; then
  bad "fetch-issues.sh calls gh issue list, which caps around 60"
else
  ok "fetch-issues.sh uses the REST API"
fi
grep -q -- '--paginate' "$DIR/fetch-issues.sh" \
  && ok "fetch-issues.sh paginates" \
  || bad "fetch-issues.sh does not paginate"

echo
echo "Passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
