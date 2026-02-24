#!/bin/bash
# SessionStart hook: inject git branch naming rules into Claude's context.
# Outputs ~130 tokens so Claude enforces conventions without user prompting.

# Resolve plugin root path (works both as hook and standalone)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

cat <<'RULES'
## Git Branch Naming — Base Rules

MANDATORY: Follow these rules whenever creating or renaming git branches.

**Branch name format:** `<prefix>/<kebab-case-description>`
Valid prefixes: `feature`, `bugfix`, `hotfix`, `release`, `docs`, `test`, `chore`, `refactor`

Examples:
- ✅ `feature/user-auth`
- ✅ `bugfix/fix-login-redirect`
- ✅ `docs/update-readme`
- ❌ `my-feature` (missing prefix)
- ❌ `Feature/UserAuth` (wrong case)
- ❌ `feature/user_auth` (underscores not allowed)

Rules:
- ALWAYS use a valid prefix from the list above
- ALWAYS use kebab-case (lowercase, hyphens only — no underscores, no spaces)
- NEVER commit directly to `main`, `master`, or `develop` — always use a feature branch
- NEVER push directly to `main`, `master`, or `develop` without confirmation
- Check `.claude-plugin/git-branch-naming.json` for project-specific rules (ticket patterns, custom prefixes, enforcement levels)
- Before commit/push, verify your staged files match the branch type (e.g., `docs/` branch should not contain only code files)
- Run `/git-branch-naming:setup` to create or update project configuration
RULES
