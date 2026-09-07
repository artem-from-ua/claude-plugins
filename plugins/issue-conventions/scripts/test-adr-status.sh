#!/bin/bash
# test-adr-status.sh — does adr-status.sh classify real ADRs correctly?
#
# Fixtures are frontmatter and index rows copied verbatim from the reference
# project, including the three shapes of superseded_by and the successor rows
# whose Status cells say "supersedes".
#
# Usage: test-adr-status.sh [path-to-adr-status.sh]

set -uo pipefail

SCRIPT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/adr-status.sh}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
pass=0
fail=0

# --- fixtures ------------------------------------------------------------

cat > "$WORK/0001-local-llm.md" <<'EOF'
---
status: superseded
superseded_by:
  - 0006-mlx-lm-over-lm-studio.md
  - 0020-default-llm-qwen25-7b.md
date: 2026-05-11
---
# 0001 — Local LLM
EOF

cat > "$WORK/0024-safe-speech.md" <<'EOF'
---
status: accepted
date: 2026-05-12
---
# 0024 — Defaults for the safe_speech stage
EOF

cat > "$WORK/0025-render-silence.md" <<'EOF'
---
status: accepted
date: 2026-05-12
---
# 0025 — Silence events
EOF

cat > "$WORK/0026-proofread-off.md" <<'EOF'
---
status: superseded
date: 2026-05-13
superseded_by: ["0028-proofread-default-on-after-rework"]
see_also: [0005, 0017]
---
# 0026 — Proofread default off
EOF

cat > "$WORK/0029-taxonomy.md" <<'EOF'
---
status: accepted
superseded_by: [0038]
date: 2026-05-14
---
# 0029 — Issue label taxonomy
EOF

cat > "$WORK/0030-plain.md" <<'EOF'
---
status: accepted
date: 2026-05-15
---
# 0030 — Something with no supersession at all
EOF

cat > "$WORK/README.md" <<'EOF'
| #  | Title | Status |
|----|-------|--------|
| ~~1~~ | ~~[Local LLM](0001-local-llm.md)~~ | superseded by 0006 and 0020 |
| ~~24~~ | ~~[Defaults for the safe_speech stage](0024-safe-speech.md)~~ | accepted (render display superseded by 0025) |
| 25 | [Silence events](0025-render-silence.md) | accepted (supersedes 0024 render display) |
| ~~26~~ | ~~[Proofread default off](0026-proofread-off.md)~~ | superseded by 0028 |
| ~~29~~ | ~~[Issue label taxonomy](0029-taxonomy.md)~~ | accepted (storage mechanism superseded by 0038; axes still in force) |
| 30 | [Something plain](0030-plain.md) | accepted |
EOF

# --- assertions ----------------------------------------------------------
# file | superseded | partial | expected signals | successors

check() {
  local file="$1" want_sup="$2" want_partial="$3" want_signals="$4" want_succ="$5"
  local out sup partial signals succ
  out=$(bash "$SCRIPT" "$WORK/$file" "$WORK/README.md" 2>&1) || {
    echo "  FAIL  $file — script errored: $out"; fail=$((fail + 1)); return
  }
  sup=$(printf '%s' "$out" | jq -r '.superseded')
  partial=$(printf '%s' "$out" | jq -r '.partial')
  signals=$(printf '%s' "$out" | jq -r '.signals | sort | join(",")')
  succ=$(printf '%s' "$out" | jq -r '.supersededBy | sort | join(",")')

  if [ "$sup" = "$want_sup" ] && [ "$partial" = "$want_partial" ] \
     && [ "$signals" = "$want_signals" ] && [ "$succ" = "$want_succ" ]; then
    echo "  ok    $file"
    pass=$((pass + 1))
  else
    echo "  FAIL  $file"
    echo "        superseded=$sup (want $want_sup), partial=$partial (want $want_partial)"
    echo "        signals='$signals' (want '$want_signals')"
    echo "        successors='$succ' (want '$want_succ')"
    fail=$((fail + 1))
  fi
}

echo "=== full supersession: status says so ==="
check "0001-local-llm.md"    true  false "index-strikethrough,status,superseded_by" "0006,0020"
check "0026-proofread-off.md" true false "index-strikethrough,status,superseded_by" "0028"

echo
echo "=== partial: status stays accepted ==="
# 0024 carries no superseded_by at all — the strikethrough is the only signal,
# and the successor's number comes from the Status cell's prose.
check "0024-safe-speech.md" true true "index-strikethrough" "0025"
check "0029-taxonomy.md"    true true "index-strikethrough,superseded_by" "0038"

echo
echo "=== successors and plain records: not superseded ==="
# 0025's Status cell says "supersedes 0024" — a naive substring search for
# "supersede" would mark the replacement as replaced.
check "0025-render-silence.md" false false "" ""
check "0030-plain.md"          false false "" ""

echo
echo "Passed: $pass, failed: $fail"
echo "Load-bearing: 0024 (strikethrough is the only signal) and 0025 (successor,"
echo "whose Status cell contains the substring 'supersede')."
[ "$fail" -eq 0 ]
