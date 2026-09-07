#!/bin/bash
# test-scale.sh — do the scripts survive a corpus larger than the author's own repo?
#
# Twice in this plugin's history a limit sat exactly where the tool starts being
# useful, and both times a live run found it rather than a test:
#
#   `gh issue list --json` silently truncates at ~60 issues
#   `--argjson` dies at ARG_MAX (1 MB), around 200 issues with bodies
#
# That is not coincidence. A plugin gets exercised on its author's repository,
# which is always smaller than the backlog it was written for. So the fixture is
# deliberately larger than any real repo here: 500 issues, ~2.5 MB — comfortably
# past ARG_MAX, and past whatever the next paging limit turns out to be.
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
ARGMAX=$(getconf ARG_MAX)
echo "fixture: $SIZE bytes, 500 issues (ARG_MAX: $ARGMAX)"
echo

if [ "$SIZE" -gt "$ARGMAX" ]; then
  ok "fixture exceeds ARG_MAX — the limit is actually exercised"
else
  bad "fixture is smaller than ARG_MAX ($SIZE ≤ $ARGMAX); it proves nothing"
fi

echo
echo "=== the old failure mode still fails ==="
BIG=$(cat "$DUMP")
if jq -n --argjson issues "$BIG" '$issues | length' >/dev/null 2>&1; then
  bad "--argjson accepted $SIZE bytes; the fixture is too small to be a guard"
else
  ok "--argjson still dies at this size, as it did on the second polygon"
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
# Strip comments first: the script mentions `gh issue list` precisely to explain
# why it does not use it. Matching the word rather than the code is the same trap
# the regression guide is about.
if grep -vE '^\s*#' "$DIR/fetch-issues.sh" | grep -q 'gh issue list'; then
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
