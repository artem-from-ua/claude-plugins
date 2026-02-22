---
name: branch-naming-guide
description: >
  Invoked automatically when creating git branches to suggest proper names.
  Covers prefixes: feature/, bugfix/, hotfix/, release/, docs/, test/, chore/, refactor/.
  Do NOT create branches without following this naming guide.
  Keywords: branch name, create branch, naming convention, branch prefix, git branch.
---

# Git Branch Naming Guide

## Format

```
<prefix>/<kebab-case-description>
```

## Prefix Reference

| Prefix | When to use | Example |
|--------|-------------|---------|
| `feature/` | New functionality, user-facing changes | `feature/user-auth` |
| `bugfix/` | Non-critical bug fixes | `bugfix/fix-login-redirect` |
| `hotfix/` | Urgent production fixes | `hotfix/fix-payment-crash` |
| `release/` | Release preparation | `release/1.2.0` |
| `docs/` | Documentation only | `docs/update-api-readme` |
| `test/` | Tests only (no feature code) | `test/add-auth-coverage` |
| `chore/` | Config, CI, deps, tooling | `chore/upgrade-dependencies` |
| `refactor/` | Code restructuring (no behavior change) | `refactor/extract-auth-service` |

## Rules

1. **Prefix required** — always use one of the prefixes above
2. **Kebab-case** — lowercase only, hyphens as separators, no underscores or spaces
3. **Descriptive** — brief but clear (`feature/auth` is too short; `feature/add-oauth2-google-login` is good)
4. **Max 60 characters** (project default, configurable)
5. **Ticket number** — include if required by project config (e.g., `feature/JIRA-123-add-oauth`)

## Quick Naming Tips

- Use present tense: `feature/add-login` not `feature/added-login`
- Be specific: `bugfix/fix-null-pointer-in-cart` not `bugfix/fix-bug`
- Skip "the", "a", "an": `feature/user-settings` not `feature/the-user-settings-page`

## Good vs Bad Examples

| Bad | Good | Reason |
|-----|------|--------|
| `my-feature` | `feature/my-feature` | Missing prefix |
| `Feature/UserAuth` | `feature/user-auth` | Wrong case |
| `feature/user_auth` | `feature/user-auth` | Underscore → hyphen |
| `fix` | `bugfix/fix-login-error` | Too vague, missing prefix |
| `feature/implementing-the-new-very-long-user-authentication-flow-page` | `feature/user-oauth-login` | Too long |

## Checking Project Config

If `.claude/git-branch-naming.json` exists in the project, it may override:
- Allowed prefixes
- Required ticket pattern (e.g., `JIRA-\d+`, `#\d+`)
- Max branch name length
- Enforcement mode (`ask` vs `deny`)

Run `/git-branch-naming:setup` to view or update project configuration.
