#!/bin/bash
# Helper: analyze staged files or full branch diff vs branch name prefix.
# Called by validate-branch.sh — not a hook itself.
#
# Usage:
#   check-content-mismatch.sh --staged <branch> <repo_dir>
#   check-content-mismatch.sh --branch <branch> <repo_dir>
#
# Output: non-empty warning message if mismatch detected, empty if OK.

set -euo pipefail

MODE="${1:-}"
BRANCH="${2:-}"
REPO_DIR="${3:-.}"

if [[ -z "$MODE" ]] || [[ -z "$BRANCH" ]]; then
  exit 0
fi

# ─── File classification ─────────────────────────────────────────────────────

classify_file() {
  local f="$1"

  # Tests (check before code — test files are also .ts/.py etc.)
  if echo "$f" | grep -qE '(\.test\.|\.spec\.|_test\.|test_|__tests__/|/tests?/)'; then
    echo "test"
    return
  fi

  # Config/CI
  if echo "$f" | grep -qE '(\.github/|Dockerfile|\.ya?ml$|\.tf$|Makefile|package\.json|Cargo\.toml|pyproject\.toml|setup\.py|\.env|\.ini$|\.cfg$)'; then
    echo "config"
    return
  fi

  # Docs
  if echo "$f" | grep -qE '(\.(md|rst|txt|adoc)$|^docs?/|/docs?/)'; then
    echo "docs"
    return
  fi

  # Code
  if echo "$f" | grep -qE '\.(ts|tsx|js|jsx|py|go|rs|java|rb|c|cpp|h|cs|swift|kt|php|scala|clj|ex|exs|hs|ml|fs|fsx|sh|bash)$'; then
    echo "code"
    return
  fi

  echo "other"
}

# ─── Count file types ────────────────────────────────────────────────────────

count_types() {
  local files_list="$1"
  local code=0 docs=0 test=0 config=0 other=0 total=0

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    total=$((total + 1))
    local t
    t=$(classify_file "$f")
    case "$t" in
      code)   code=$((code + 1)) ;;
      docs)   docs=$((docs + 1)) ;;
      test)   test=$((test + 1)) ;;
      config) config=$((config + 1)) ;;
      other)  other=$((other + 1)) ;;
    esac
  done <<< "$files_list"

  echo "$total $code $docs $test $config $other"
}

# ─── Extract branch prefix ───────────────────────────────────────────────────

PREFIX="${BRANCH%%/*}"

# Skip check for prefixes without clear expectations
if echo "$PREFIX" | grep -qE '^(release|main|master|develop|HEAD)$'; then
  exit 0
fi

# ─── Get file list ───────────────────────────────────────────────────────────

FILES=""

if [[ "$MODE" == "--staged" ]]; then
  FILES=$(git -C "$REPO_DIR" diff --cached --name-only 2>/dev/null || true)
elif [[ "$MODE" == "--branch" ]]; then
  # Try origin/main, then main, then origin/master, then master
  for base in origin/main main origin/master master origin/develop develop; do
    if git -C "$REPO_DIR" rev-parse --verify "$base" >/dev/null 2>&1; then
      FILES=$(git -C "$REPO_DIR" diff --name-only "${base}..HEAD" 2>/dev/null || true)
      break
    fi
  done
fi

# No files to check — nothing staged or no base branch
if [[ -z "$FILES" ]]; then
  exit 0
fi

# Count files
read -r total code docs test config other <<< "$(count_types "$FILES")"

# Skip if very few files (not enough signal)
if [[ "$total" -lt 2 ]]; then
  exit 0
fi

# ─── Mismatch detection ──────────────────────────────────────────────────────

# Compute percentage for each type (integer math, round down)
pct_code=0
pct_docs=0
pct_test=0
pct_config=0

[[ $total -gt 0 ]] && pct_code=$(( code * 100 / total ))
[[ $total -gt 0 ]] && pct_docs=$(( docs * 100 / total ))
[[ $total -gt 0 ]] && pct_test=$(( test * 100 / total ))
[[ $total -gt 0 ]] && pct_config=$(( config * 100 / total ))

# Thresholds
if [[ "$MODE" == "--staged" ]]; then
  THRESHOLD=80
else
  THRESHOLD=50
fi

MISMATCH=""

case "$PREFIX" in
  feature|bugfix|hotfix|refactor)
    # Expect code (and tests). Suspicious if only docs and no code at all.
    if [[ $pct_docs -ge $THRESHOLD ]] && [[ $code -eq 0 ]]; then
      MISMATCH="Branch '$BRANCH' ($PREFIX) usually contains code changes, but ${pct_docs}% of files are documentation (${docs}/${total} files). Is this intentional?"
    fi
    ;;
  docs)
    # Expect markdown/docs. Suspicious if mostly code files.
    if [[ $pct_code -ge $THRESHOLD ]]; then
      MISMATCH="Branch '$BRANCH' ($PREFIX) is a docs branch, but ${pct_code}% of files are code files (${code}/${total} files). Consider using a 'feature/' or 'refactor/' prefix instead."
    fi
    ;;
  test)
    # Expect test files. Suspicious if no test files at all.
    if [[ $test -eq 0 ]] && [[ $total -ge 2 ]]; then
      MISMATCH="Branch '$BRANCH' ($PREFIX) is a test branch, but none of the ${total} changed files look like test files. Is this intentional?"
    fi
    ;;
  chore)
    # Expect config/CI. Suspicious if mostly application source code.
    if [[ $pct_code -ge $THRESHOLD ]]; then
      MISMATCH="Branch '$BRANCH' ($PREFIX) is a chore branch (config, CI, deps), but ${pct_code}% of files are application source code (${code}/${total} files). Consider using a 'feature/' or 'refactor/' prefix instead."
    fi
    ;;
esac

# Add commit message analysis for --branch mode
if [[ "$MODE" == "--branch" ]] && [[ -z "$MISMATCH" ]]; then
  COMMITS=$(git -C "$REPO_DIR" log "${base:-main}..HEAD" --format='%s' 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)
  if [[ -n "$COMMITS" ]]; then
    # Define keyword sets per prefix
    case "$PREFIX" in
      feature)
        EXPECTED_KEYWORDS="feat|add|implement|create|new"
        UNEXPECTED_KEYWORDS="fix|patch|resolve|correct"
        ;;
      bugfix|hotfix)
        EXPECTED_KEYWORDS="fix|resolve|patch|correct|repair"
        UNEXPECTED_KEYWORDS="feat|add|implement|create"
        ;;
      refactor)
        EXPECTED_KEYWORDS="refactor|restructure|reorganize|rename|move|extract"
        UNEXPECTED_KEYWORDS=""
        ;;
      docs)
        EXPECTED_KEYWORDS="doc|readme|update doc|clarif|comment|typo"
        UNEXPECTED_KEYWORDS=""
        ;;
      test)
        EXPECTED_KEYWORDS="test|spec|coverage|assert"
        UNEXPECTED_KEYWORDS=""
        ;;
      chore)
        EXPECTED_KEYWORDS="chore|dep|ci|config|bump|upgrade|update|build"
        UNEXPECTED_KEYWORDS=""
        ;;
      *)
        EXPECTED_KEYWORDS=""
        UNEXPECTED_KEYWORDS=""
        ;;
    esac

    if [[ -n "$EXPECTED_KEYWORDS" ]]; then
      MATCHING=$(echo "$COMMITS" | grep -cE "$EXPECTED_KEYWORDS" || true)
      TOTAL_COMMITS=$(echo "$COMMITS" | grep -c . || true)
      if [[ $TOTAL_COMMITS -gt 0 ]]; then
        PCT_MATCH=$(( MATCHING * 100 / TOTAL_COMMITS ))
        if [[ $PCT_MATCH -lt $((100 - THRESHOLD)) ]] && [[ $TOTAL_COMMITS -ge 2 ]]; then
          MISMATCH="Branch '$BRANCH' ($PREFIX) has commit messages that don't align well with the branch type. Only ${MATCHING}/${TOTAL_COMMITS} commits mention expected keywords (${EXPECTED_KEYWORDS}). Is the branch named correctly?"
        fi
      fi
    fi
  fi
fi

if [[ -n "$MISMATCH" ]]; then
  echo "$MISMATCH"
fi

exit 0
