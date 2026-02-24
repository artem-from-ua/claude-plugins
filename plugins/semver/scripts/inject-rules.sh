#!/bin/bash
# SessionStart hook: inject SemVer rules into Claude's context.
# Outputs ~150 tokens so Claude enforces version bumps automatically.
# Silent on errors — never block session start.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

_new="${CLAUDE_PROJECT_DIR:-.}/.claude-plugin/semver.json"
_old="${CLAUDE_PROJECT_DIR:-.}/.claude/semver.json"
if [[ -f "$_new" ]]; then
  PROJECT_CONFIG="$_new"
elif [[ -f "$_old" ]]; then
  PROJECT_CONFIG="$_old"
else
  PROJECT_CONFIG="$_new"
fi
GLOBAL_CONFIG="$HOME/.claude/semver.json"

# Read trigger strategy from config (project takes priority over global)
TRIGGER="auto"
if [[ -f "$PROJECT_CONFIG" ]]; then
  _t=$(jq -r '.triggerStrategy // empty' "$PROJECT_CONFIG" 2>/dev/null || true)
  [[ -n "$_t" ]] && TRIGGER="$_t"
elif [[ -f "$GLOBAL_CONFIG" ]]; then
  _t=$(jq -r '.triggerStrategy // empty' "$GLOBAL_CONFIG" 2>/dev/null || true)
  [[ -n "$_t" ]] && TRIGGER="$_t"
fi

# Build strategy-specific rule line
case "$TRIGGER" in
  always)
    STRATEGY_RULE="- Every commit with source changes MUST include a version bump — no exceptions"
    ;;
  *)
    STRATEGY_RULE="- Evaluate each commit: new feature → MINOR, bug fix → PATCH, breaking change → MAJOR, docs/config only → skip"
    ;;
esac

cat <<RULES
## Semantic Versioning — Base Rules

MANDATORY: Follow SemVer 2.0.0 when modifying project code.

**Version format:** MAJOR.MINOR.PATCH
- MAJOR: breaking changes (incompatible API changes)
- MINOR: new features (backwards-compatible)
- PATCH: bug fixes (backwards-compatible)

**Trigger strategy: ${TRIGGER}**
${STRATEGY_RULE}

**Before committing or pushing:**
1. Check \`.claude-plugin/semver.json\` for version file location(s) and base branch
2. Run \`git diff <baseBranch>...HEAD --name-only -- <versionFile>\` to see if already bumped
3. If not bumped and changes warrant it — bump, stage, and commit together with source changes
4. On rebase conflict: check base branch version first, increment from there (not your original)

- Run \`/semver:setup\` to configure versioning for this project
- Run \`/semver:guide\` for full SemVer 2.0.0 reference and decision tree
RULES
