#!/bin/bash
# test-adr-state.sh — does drift-check.sh distinguish the three ADR states?
#
# "No ADR configured" and "an ADR is configured but its file is gone" used to
# produce the same empty result, so a broken configuration read as a clean one.
#
# The block under test is extracted from drift-check.sh rather than reimplemented
# here: a copy would keep passing after the original changed.
#
# Usage: test-adr-state.sh [path-to-scripts-dir]

S="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
W=$(mktemp -d)
pass=0; fail=0
ok(){ echo "  ok    $1"; pass=$((pass+1)); }
bad(){ echo "  FAIL  $1"; fail=$((fail+1)); }

mkdir -p "$W/.claude-plugin" "$W/docs/adr"
cp /Users/artem/.claude/jobs/2d339529/tmp/adrs/0029-*.md "$W/docs/adr/" 2>/dev/null
cp /Users/artem/.claude/jobs/2d339529/tmp/adrs/README.md "$W/docs/adr/" 2>/dev/null
ADR=$(basename "$W"/docs/adr/0029-*.md)

# Cut the ADR block out of the real drift-check.sh, from its comment to the
# line that assembles ADR_STATUS.
sed -n '/^# Reports \*why\* there is nothing/,/^                   .missingPaths: \$missing}.)$/p' \
  "$S/drift-check.sh" > "$W/block.sh"

if [ ! -s "$W/block.sh" ]; then
  echo "  FAIL  could not extract the ADR block from drift-check.sh"
  rm -rf "$W"; exit 1
fi

run_state() {
  ( cd "$W" && SCRIPT_DIR="$S" CLAUDE_PROJECT_DIR="$W" bash -c "
      source '$W/block.sh'
      printf '%s' \"\$ADR_STATUS\"
    " 2>/dev/null )
}

echo "=== 1. no ADR configured ==="
printf '{"version":1,"taxonomyDocument":"d.md"}\n' > "$W/.claude-plugin/issue-conventions.json"
out=$(run_state)
[ "$(echo "$out" | jq -r .state)" = "not-configured" ] && ok "state=not-configured" || bad "$out"

echo
echo "=== 2. ADR configured, file present ==="
printf '{"version":1,"adr":"docs/adr/%s"}\n' "$ADR" > "$W/.claude-plugin/issue-conventions.json"
out=$(run_state)
st=$(echo "$out" | jq -r .state); n=$(echo "$out" | jq '.records | length')
[ "$st" = "checked" ] && [ "$n" = "1" ] && ok "state=checked, records=1" || bad "$out"

echo
echo "=== 3. ADR configured, file missing ==="
printf '{"version":1,"adr":"docs/adr/9999-gone.md"}\n' > "$W/.claude-plugin/issue-conventions.json"
out=$(run_state)
st=$(echo "$out" | jq -r .state); m=$(echo "$out" | jq -r '.missingPaths[0]')
if [ "$st" = "configured-but-missing" ] && [ "$m" = "docs/adr/9999-gone.md" ]; then
  ok "state=configured-but-missing, path named exactly"
else bad "$out"; fi

echo
echo "Passed: $pass, failed: $fail"
rm -rf "$W"
[ "$fail" -eq 0 ]
