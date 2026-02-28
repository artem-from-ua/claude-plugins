#!/usr/bin/env bash
# kb-structural-scan.sh — Phase 1: structural documentation checks
# Usage: KB_CONFIG_FILE=path/to/config.json CLAUDE_PROJECT_DIR=/path/to/project kb-structural-scan.sh
#
# Checks: brokenLinks, orphanDocs, duplicateContent, claudemdOverflow, mandatoryDocs
# Output: JSON report to /tmp/kb-structural-scan-{timestamp}-${UID}.json, prints path to stdout

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG_FILE="${KB_CONFIG_FILE:-}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="/tmp/kb-structural-scan-${TIMESTAMP}-${UID}.json"

# ── Load config ──────────────────────────────────────────────────────────────

# Defaults (all checks enabled)
CHECK_BROKEN_LINKS=true
CHECK_ORPHAN_DOCS=true
CHECK_DUPLICATE_CONTENT=true
CHECK_CLAUDEMD_OVERFLOW=true
CHECK_MANDATORY_DOCS=true

EXCLUDE_PATTERNS='["node_modules/", ".git/", "vendor/", "dist/", "build/"]'

if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
  # Use if/then/else in jq — the // operator treats false as falsy
  CHECK_BROKEN_LINKS=$(jq -r 'if .checks.brokenLinks == false then "false" else "true" end' "$CONFIG_FILE")
  CHECK_ORPHAN_DOCS=$(jq -r 'if .checks.orphanDocs == false then "false" else "true" end' "$CONFIG_FILE")
  CHECK_DUPLICATE_CONTENT=$(jq -r 'if .checks.duplicateContent == false then "false" else "true" end' "$CONFIG_FILE")
  CHECK_CLAUDEMD_OVERFLOW=$(jq -r 'if .checks.claudemdOverflow == false then "false" else "true" end' "$CONFIG_FILE")
  CHECK_MANDATORY_DOCS=$(jq -r 'if .checks.mandatoryDocs == false then "false" else "true" end' "$CONFIG_FILE")
  EXCLUDE_PATTERNS=$(jq -c '.scope.exclude // ["node_modules/", ".git/", "vendor/", "dist/", "build/"]' "$CONFIG_FILE")
fi

# ── Discover markdown files ──────────────────────────────────────────────────

# Build find command with include/exclude patterns
build_find_args() {
  local find_cmd="find \"$PROJECT_DIR\" -type f -name '*.md'"

  # Exclude patterns
  local excludes
  excludes=$(echo "$EXCLUDE_PATTERNS" | python3 -c "
import sys, json
patterns = json.load(sys.stdin)
for p in patterns:
    p = p.rstrip('/')
    print(p)
")
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    find_cmd+=" -not -path \"*/${pattern}/*\" -not -path \"*/${pattern}\""
  done <<< "$excludes"

  echo "$find_cmd"
}

FIND_CMD=$(build_find_args)
MD_FILES=$(eval "$FIND_CMD" 2>/dev/null | sort) || MD_FILES=""

if [ -z "$MD_FILES" ]; then
  # No markdown files found — output empty report
  python3 -c "
import json, sys
report = {
    'projectDir': sys.argv[1],
    'timestamp': sys.argv[2],
    'checksRun': [],
    'findings': [],
    'summary': {'total': 0, 'byCheck': {}, 'filesScanned': 0}
}
with open(sys.argv[3], 'w') as f:
    json.dump(report, f, indent=2)
" "$PROJECT_DIR" "$TIMESTAMP" "$REPORT_FILE"
  echo "$REPORT_FILE"
  exit 0
fi

FILE_COUNT=$(echo "$MD_FILES" | wc -l | tr -d ' ')

# ── Findings collector ───────────────────────────────────────────────────────
# Each finding: check|severity|file|line|message|fixable
# Stored as lines in a temp file (avoid bash array limits)
FINDINGS_FILE="/tmp/kb-findings-${TIMESTAMP}-${UID}.txt"
: > "$FINDINGS_FILE"

add_finding() {
  local check="$1" severity="$2" file="$3" line="$4" message="$5" fixable="${6:-false}"
  # Escape pipe chars in message
  local safe_msg="${message//|/¦}"
  echo "${check}|${severity}|${file}|${line}|${safe_msg}|${fixable}" >> "$FINDINGS_FILE"
}

CHECKS_RUN=()

# ── Check: brokenLinks ──────────────────────────────────────────────────────

if [ "$CHECK_BROKEN_LINKS" = "true" ]; then
  CHECKS_RUN+=("brokenLinks")
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    local_dir=$(dirname "$file")

    # Collect links into temp file to avoid grep|while pipefail issues
    LINKS_TMP="/tmp/kb-links-${TIMESTAMP}-${UID}.txt"
    grep -noE '\[([^]]*)\]\(([^)]+)\)' "$file" 2>/dev/null > "$LINKS_TMP" || true

    while IFS= read -r match; do
      [ -z "$match" ] && continue
      line_num=$(echo "$match" | cut -d: -f1)
      target=$(echo "$match" | sed 's/.*](\([^)]*\)).*/\1/')

      # Skip external URLs, anchors, mailto
      case "$target" in
        http://*|https://*|'#'*|mailto:*) continue ;;
      esac

      # Strip anchor from relative paths
      target_path="${target%%#*}"
      [ -z "$target_path" ] && continue

      # Resolve relative path
      if [[ "$target_path" == /* ]]; then
        resolved="${PROJECT_DIR}${target_path}"
      else
        resolved="${local_dir}/${target_path}"
      fi

      # Normalize path (cd may fail for broken parent dirs)
      resolved=$(cd "$(dirname "$resolved")" 2>/dev/null && echo "$(pwd)/$(basename "$resolved")") || resolved=""

      if [ -n "$resolved" ] && [ ! -e "$resolved" ]; then
        rel_file="${file#$PROJECT_DIR/}"
        add_finding "brokenLinks" "warning" "$rel_file" "$line_num" "Broken link: ${target}" "false"
      fi
    done < "$LINKS_TMP"

    rm -f "$LINKS_TMP"
  done <<< "$MD_FILES"
fi

# ── Check: orphanDocs ────────────────────────────────────────────────────────

if [ "$CHECK_ORPHAN_DOCS" = "true" ]; then
  CHECKS_RUN+=("orphanDocs")

  # Entry points (never orphans): README.md, CLAUDE.md at project root
  ENTRY_POINTS=("${PROJECT_DIR}/README.md" "${PROJECT_DIR}/CLAUDE.md")

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    rel_file="${file#$PROJECT_DIR/}"
    basename_file=$(basename "$file")

    # Skip entry points
    is_entry=false
    for ep in "${ENTRY_POINTS[@]}"; do
      if [ "$file" = "$ep" ]; then
        is_entry=true
        break
      fi
    done
    [ "$is_entry" = "true" ] && continue

    # Check if any other .md file references this file
    referenced=false
    while IFS= read -r other_file; do
      [ -z "$other_file" ] && continue
      [ "$other_file" = "$file" ] && continue

      if grep -qE "\]\([^)]*${basename_file}" "$other_file" 2>/dev/null; then
        referenced=true
        break
      fi
    done <<< "$MD_FILES"

    if [ "$referenced" = "false" ]; then
      add_finding "orphanDocs" "info" "$rel_file" "0" "Orphan document: no incoming references found" "false"
    fi
  done <<< "$MD_FILES"
fi

# ── Check: duplicateContent ─────────────────────────────────────────────────

if [ "$CHECK_DUPLICATE_CONTENT" = "true" ]; then
  CHECKS_RUN+=("duplicateContent")

  # Extract first 10 non-frontmatter, non-empty lines from a file
  extract_content_lines() {
    local file="$1"
    local in_frontmatter=false
    local line_count=0
    local result=""

    while IFS= read -r line || [ -n "$line" ]; do
      if [ "$line_count" -eq 0 ] && [ "$in_frontmatter" = "false" ] && [ "$line" = "---" ]; then
        in_frontmatter=true
        continue
      fi
      if [ "$in_frontmatter" = "true" ]; then
        if [ "$line" = "---" ]; then
          in_frontmatter=false
        fi
        continue
      fi
      # Skip empty/whitespace-only lines
      local trimmed
      trimmed=$(printf '%s' "$line" | tr -d '[:space:]')
      [ -z "$trimmed" ] && continue

      if [ -n "$result" ]; then
        result+=$'\n'"$line"
      else
        result="$line"
      fi
      line_count=$((line_count + 1))
      [ "$line_count" -ge 10 ] && break
    done < "$file"

    printf '%s' "$result"
  }

  # Store content fingerprints in temp file
  FINGERPRINT_FILE="/tmp/kb-fingerprints-${TIMESTAMP}-${UID}.txt"
  : > "$FINGERPRINT_FILE"

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    rel_file="${file#$PROJECT_DIR/}"
    content=$(extract_content_lines "$file") || true
    [ -z "$content" ] && continue
    # Use md5 hash as fingerprint
    if command -v md5sum >/dev/null 2>&1; then
      hash=$(printf '%s' "$content" | md5sum | cut -d' ' -f1)
    else
      hash=$(printf '%s' "$content" | md5 -q)
    fi
    echo "${hash}|${rel_file}" >> "$FINGERPRINT_FILE"
  done <<< "$MD_FILES"

  # Find duplicate hashes
  if [ -s "$FINGERPRINT_FILE" ]; then
    while IFS= read -r entry; do
      hash=$(echo "$entry" | cut -d'|' -f1)
      file=$(echo "$entry" | cut -d'|' -f2)
      dup_count=$(grep -c "^${hash}|" "$FINGERPRINT_FILE") || true
      if [ "$dup_count" -gt 1 ]; then
        others=$(grep "^${hash}|" "$FINGERPRINT_FILE" | cut -d'|' -f2 | { grep -v "^${file}$" || true; } | head -3 | tr '\n' ', ' | sed 's/,$//')
        [ -n "$others" ] && add_finding "duplicateContent" "info" "$file" "0" "Similar content found in: ${others}" "false"
      fi
    done < <(sort "$FINGERPRINT_FILE")
  fi

  rm -f "$FINGERPRINT_FILE"
fi

# ── Check: claudemdOverflow ─────────────────────────────────────────────────

if [ "$CHECK_CLAUDEMD_OVERFLOW" = "true" ]; then
  CHECKS_RUN+=("claudemdOverflow")

  CLAUDE_MD="${PROJECT_DIR}/CLAUDE.md"
  if [ -f "$CLAUDE_MD" ]; then
    line_count=$(wc -l < "$CLAUDE_MD" | tr -d ' ')
    char_count=$(wc -c < "$CLAUDE_MD" | tr -d ' ')

    if [ "$line_count" -gt 200 ]; then
      add_finding "claudemdOverflow" "warning" "CLAUDE.md" "0" "CLAUDE.md has ${line_count} lines (recommended max: 200)" "false"
    fi
    if [ "$char_count" -gt 10000 ]; then
      add_finding "claudemdOverflow" "warning" "CLAUDE.md" "0" "CLAUDE.md has ${char_count} characters (recommended max: 10000)" "false"
    fi
  fi
fi

# ── Check: mandatoryDocs ────────────────────────────────────────────────────

if [ "$CHECK_MANDATORY_DOCS" = "true" ]; then
  CHECKS_RUN+=("mandatoryDocs")

  if [ ! -f "${PROJECT_DIR}/README.md" ]; then
    add_finding "mandatoryDocs" "error" "README.md" "0" "Missing mandatory file: README.md" "false"
  fi
  if [ ! -f "${PROJECT_DIR}/CLAUDE.md" ]; then
    add_finding "mandatoryDocs" "warning" "CLAUDE.md" "0" "Missing recommended file: CLAUDE.md" "false"
  fi
fi

# ── Assemble JSON report ────────────────────────────────────────────────────

CHECKS_JSON=$(printf '%s\n' "${CHECKS_RUN[@]+"${CHECKS_RUN[@]}"}" | python3 -c "
import sys, json
checks = [line.strip() for line in sys.stdin if line.strip()]
print(json.dumps(checks))
")

python3 -c "
import sys, json

project_dir = sys.argv[1]
timestamp = sys.argv[2]
report_file = sys.argv[3]
findings_file = sys.argv[4]
checks_json = sys.argv[5]
file_count = int(sys.argv[6])

checks_run = json.loads(checks_json)

findings = []
by_check = {}

with open(findings_file, 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split('|', 5)
        if len(parts) < 6:
            continue
        check, severity, file_path, line_num, message, fixable = parts
        message = message.replace('\u00a6', '|')
        finding = {
            'check': check,
            'severity': severity,
            'file': file_path,
            'line': int(line_num),
            'message': message,
            'fixable': fixable == 'true'
        }
        findings.append(finding)
        by_check[check] = by_check.get(check, 0) + 1

report = {
    'projectDir': project_dir,
    'timestamp': timestamp,
    'checksRun': checks_run,
    'findings': findings,
    'summary': {
        'total': len(findings),
        'byCheck': by_check,
        'filesScanned': file_count
    }
}

with open(report_file, 'w') as f:
    json.dump(report, f, indent=2)
" "$PROJECT_DIR" "$TIMESTAMP" "$REPORT_FILE" "$FINDINGS_FILE" "$CHECKS_JSON" "$FILE_COUNT"

rm -f "$FINDINGS_FILE"

echo "$REPORT_FILE"
