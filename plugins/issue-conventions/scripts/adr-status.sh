#!/bin/bash
# adr-status.sh — is this ADR still current, or has it been superseded?
#
# The three signals are deterministic, so they belong in a script rather than in
# prose the subagent has to re-derive each run. The subagent still decides what a
# divergence *means*; this decides the fact it reasons from.
#
# Signals, any one of which counts:
#   1. `status: superseded` in the frontmatter — replaced wholesale.
#   2. A non-empty `superseded_by` — often present while status stays `accepted`.
#   3. The index row has number and title struck through (`~~N~~`).
#
# Signal 3 is the structural one and the only one that cannot be reworded into
# meaning its opposite. The Status cell is prose: it supplies the successor's
# number, never the verdict. A successor row reading "accepted (0029 superseded
# by this record)" is not superseded, and only the strikethrough knows that.
#
# Usage: adr-status.sh <adr-file> [index-file]
# Output: JSON — {file, number, status, supersededBy[], struck, superseded, signals[]}

set -uo pipefail

ADR="${1:-}"
INDEX="${2:-}"

if [[ -z "$ADR" || ! -f "$ADR" ]]; then
  echo '{"error":"usage: adr-status.sh <adr-file> [index-file]"}' >&2
  exit 2
fi

[[ -z "$INDEX" ]] && INDEX="$(dirname "$ADR")/README.md"

NUM=$(basename "$ADR" | grep -oE '^[0-9]{4}' || true)
[[ -z "$NUM" ]] && NUM="$(basename "$ADR" | grep -oE '^[0-9]+' || true)"

# --- frontmatter ---------------------------------------------------------
FM=$(awk 'NR==1 && /^---/ {inside=1; next} inside && /^---/ {exit} inside' "$ADR")

STATUS=$(printf '%s\n' "$FM" | grep -iE '^status:' | head -1 | sed 's/^[Ss]tatus:[[:space:]]*//' | tr -d '\r')
: "${STATUS:=unknown}"

# superseded_by comes in three live shapes — a YAML list of filenames, a JSON
# array of strings, and a JSON array of bare numbers. Take the leading four
# digits of each entry: the number is the identity, the filename is decoration.
SB_BLOCK=$(printf '%s\n' "$FM" | awk '
  /^superseded_by:/ {found=1; print; next}
  found && /^[[:space:]]*-/ {print; next}
  found && /^[^[:space:]]/ {exit}
  found {print}
')
SB_NUMS=$(printf '%s\n' "$SB_BLOCK" | grep -oE '[0-9]{4}' | sort -u || true)
SUPERSEDED_BY="[]"
if [[ -n "$SB_NUMS" ]]; then
  SUPERSEDED_BY=$(printf '%s\n' "$SB_NUMS" | jq -R 'select(length > 0)' | jq -sc .)
fi

# --- index row -----------------------------------------------------------
STRUCK=false
FROM_INDEX="[]"
if [[ -n "$NUM" && -f "$INDEX" ]]; then
  # The file name is zero-padded (0024) while the index column usually is not (24),
  # so match on the number with leading zeros stripped, allowing them either way.
  BARE=$(printf '%s' "$NUM" | sed 's/^0*//')
  : "${BARE:=0}"
  ROW=$(grep -E "^\|[[:space:]]*~*[[:space:]]*0*${BARE}[[:space:]]*~*[[:space:]]*\|" "$INDEX" | head -1 || true)
  if [[ -n "$ROW" ]]; then
    # The strikethrough marks the record; it lives in the first two columns only,
    # because the Status cell is deliberately left readable.
    IDENTITY=$(printf '%s' "$ROW" | awk -F'|' '{print $2 "|" $3}')
    [[ "$IDENTITY" == *"~~"* ]] && STRUCK=true

    # The Status cell supplies the successor's number, never the verdict.
    # `grep -c` exits non-zero on no match, so collect first and guard the empty
    # case explicitly — piping nothing into jq is what breaks here.
    STATUS_CELL=$(printf '%s' "$ROW" | awk -F'|' '{print $(NF-1)}')
    NUMS=$(printf '%s' "$STATUS_CELL" \
      | grep -oiE 'superseded by[^0-9]*[0-9]{1,4}' \
      | grep -oE '[0-9]{1,4}$' | sort -u || true)
    if [[ -n "$NUMS" ]]; then
      FROM_INDEX=$(printf '%s\n' "$NUMS" | jq -R 'select(length > 0)' | jq -sc .)
    fi
  fi
fi

jq -n \
  --arg file "$ADR" \
  --arg number "$NUM" \
  --arg status "$STATUS" \
  --argjson supersededBy "$SUPERSEDED_BY" \
  --argjson fromIndex "$FROM_INDEX" \
  --argjson struck "$STRUCK" '
  ($status | ascii_downcase | startswith("superseded")) as $s1
  | (($supersededBy | length) > 0) as $s2
  | $struck as $s3
  | {
      file: $file,
      number: $number,
      status: $status,
      supersededBy: ($supersededBy + $fromIndex | unique),
      struck: $struck,
      superseded: ($s1 or $s2 or $s3),
      partial: (($s2 or $s3) and ($s1 | not)),
      signals: ([
        (if $s1 then "status" else empty end),
        (if $s2 then "superseded_by" else empty end),
        (if $s3 then "index-strikethrough" else empty end)
      ])
    }
'
