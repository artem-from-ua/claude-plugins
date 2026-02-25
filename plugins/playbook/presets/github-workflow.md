---
name: github-workflow
description: "PR merge rules, PR description updates, issue linking"
tags: [github, pr, workflow]
---

<!-- RULES -->
## GitHub Workflow — Base Rules

MANDATORY: Follow these rules for all PR and branch operations.

- ALWAYS use `--squash` for PR merge (unless repo explicitly uses merge/rebase)
- Before using `gh pr merge --auto` → check `gh api repos/OWNER/REPO --jq '.allow_auto_merge'`
- After committing on a PR branch → offer to update the PR description
- When creating PR without linked issue → ask user to create one first
- "Not mergeable" after another PR merged → `git fetch origin main && git rebase origin/main && git push --force-with-lease`
- **ALWAYS invoke the `playbook-browse github-workflow` skill BEFORE performing PR or branch operations** to load full guidelines. This is MANDATORY — do not skip this step.
<!-- /RULES -->

<!-- REFERENCE -->
## PR Merge

- **Never use `gh pr merge --auto`** without first checking if the repo has auto-merge enabled (`gh api repos/OWNER/REPO --jq '.allow_auto_merge'`). Most repos have it disabled — `--auto` will fail.
- **Always use `--squash`** unless the repo explicitly uses merge commits or rebase strategy.
- **"Not mergeable" after another PR merged**: happens when two branches diverge after squash merge of the first. Fix:
  ```bash
  git fetch origin main
  git rebase origin/main
  git push --force-with-lease origin <branch>
  # then retry: gh pr merge <N> --squash
  ```
- **`--force-with-lease` is safer than `--force`**: fails if the remote was updated by someone else since your last fetch.

## After committing to a branch with an open PR

After creating a commit on a branch that has an open PR, **always offer to update the PR description**:

1. Check if current branch has an open PR:
   ```bash
   gh pr list --head $(git branch --show-current) --state open --json number,title
   ```

2. If PR exists, ask the user:
   > "PR #N exists for this branch. Do you want me to update its description to reflect all commits?"

3. If yes, regenerate the PR body:
   - Analyze ALL commits: `git log main..HEAD`
   - Update summary to reflect the full scope of changes
   - Keep existing issue links (`Closes #N`)
   - Use `gh pr edit <NUMBER> --body "..."`

## Every PR should have a linked issue

When creating a PR without a linked issue:
- Ask the user if they want to create an issue first
- If yes, create the issue, then link it with `Closes #N`
<!-- /REFERENCE -->
