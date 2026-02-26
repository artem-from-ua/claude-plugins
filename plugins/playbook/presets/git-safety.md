---
name: git-safety
description: "Safe git practices: force-with-lease, evidence preservation, confirm before destructive ops"
tags: [git, safety, destructive-operations]
---

<!-- RULES -->
## Git Safety — Base Rules

MANDATORY: Follow these rules for all git operations.

- ALWAYS use `--force-with-lease` instead of `--force` when force-pushing
- NEVER run destructive operations (`reset --hard`, `checkout .`, `restore .`, `clean -f`) without explicit user confirmation
- Before overwriting or deleting: check if it represents in-progress work (stash, WIP commit, branch with unmerged changes)
- If you encounter unexpected state (unfamiliar files, branches, conflicts) → investigate first, don't overwrite
- Merge conflicts → resolve them; do NOT discard with `checkout .` or `restore .`
- Lock files → investigate what holds the lock; do NOT delete blindly
- NEVER skip hooks with `--no-verify` unless the user explicitly requests it
<!-- /RULES -->

<!-- REFERENCE -->
## Force Push Safety

`--force-with-lease` vs `--force`:
- `--force` overwrites regardless of remote state — can destroy others' work
- `--force-with-lease` fails if remote was updated since your last fetch — safe for shared branches

```bash
# Safe
git push --force-with-lease origin <branch>

# Dangerous — only if you KNOW you want to overwrite remote unconditionally
git push --force origin <branch>
```

## Before Destructive Operations

Always ask: "What am I about to destroy, and is that what the user wants?"

```bash
# Check what reset --hard would remove
git diff HEAD
git status

# Check for stashed work
git stash list

# Check if there are commits not pushed
git log origin/<branch>..HEAD
```

## Merge Conflict Resolution

Conflicts are information — they show where two changes diverged. Don't discard them.

Steps:
1. `git status` — see which files conflict
2. Open each conflicting file, review both sides
3. Resolve manually (or with merge tool)
4. `git add <resolved-files>`
5. `git commit` (or `git rebase --continue`)

If you're unsure how to resolve a specific conflict, ask the user.

## When to Skip Hooks

`--no-verify` bypasses pre-commit and commit-msg hooks. Only skip if:
- The user explicitly says "skip hooks" or "use --no-verify"
- You've diagnosed a hook that is broken/irrelevant and the user confirms skipping

If a hook fails → investigate and fix the underlying issue first.
<!-- /REFERENCE -->
