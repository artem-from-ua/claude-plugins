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
- After merging a PR → delete the source branch (remote + local)
- Before first commit on a branch → run `gh pr list --head <branch> --state open --json number,title,author`; if open PR exists → check: (a) different author, or (b) your changes don't match the PR topic — in either case, ask user whether to commit here or create a new branch
- **Before EVERY commit** → verify your changes match the branch scope (name + existing commits). If changes are unrelated to the branch topic → stop and ask whether to create a new branch. This applies even when there is no open PR — the branch name itself defines the scope
- After committing on a PR branch → offer to update the PR description
- After committing on a branch with no open PR → offer to create a PR
- When creating PR without linked issue → ask user to create one first
- "Not mergeable" after another PR merged → `git fetch origin main && git rebase origin/main && git push --force-with-lease`
- When using `gh` commands (issue, pr, api) — NEVER specify `--repo` manually if CWD is inside the target repository; let `gh` auto-detect from git remote. If you need a different repo, run `gh repo view --json nameWithOwner` first to get the correct owner/name
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

## Scope check before every commit

Before creating **any** commit, verify that your staged changes match the branch scope:

1. Determine branch scope from:
   - **Branch name** — e.g., `feature/plantuml-sequence-ack-rules` means only sequence ACK rule changes belong here
   - **Existing commits** — `git log main..HEAD --oneline` shows what the branch is about
   - **Open PR title/description** (if exists)

2. Compare your staged changes against that scope. Ask yourself: "Would this change make sense in a PR titled after this branch?"

3. If the answer is no → **do NOT commit**. Instead, ask the user:
   > "These changes (X) don't match the branch scope (Y). Should I create a separate branch?"

This is the **most important** pre-commit check. Mixing unrelated changes on a branch creates messy PRs, complicates reviews, and makes git history harder to follow.

## Checking for open PRs before committing

Before first commit on any branch, check if an open PR already exists:

1. Check current branch:
   ```bash
   BRANCH=$(git branch --show-current)
   PR_DATA=$(gh pr list --head "$BRANCH" --state open --json number,title,author --jq '.[0]')
   ```

2. If PR exists, evaluate two conditions:
   - **Different author?** Compare `PR_AUTHOR` vs your `gh api user --jq '.login'`
   - **Topic mismatch?** Compare the PR title/description with the changes you're about to commit — if your changes are unrelated to the PR's scope, this is a red flag even if you're the author

3. If either condition is true → ask the user with `AskUserQuestion`:
   - **Commit here** — continue on this branch (e.g., collaborating, or expanding scope)
   - **New branch** — auto-generate a suggested branch name based on your staged changes (e.g., `bugfix/fix-navbar-placement`), show it as the option label; the user can pick it or type their own via "Other"

4. If `gh` unavailable or not authenticated → skip (the git-branch-naming hook provides a separate automated guard for the different-author case).

## Offering to create a PR after committing on a new branch

After committing on a branch that has **no open PR**, offer to create one:

1. Check if current branch has an open PR:
   ```bash
   gh pr list --head $(git branch --show-current) --state open --json number,title
   ```

2. If no PR exists and branch is not `main`/`master`/`develop`, ask the user:
   > "No PR exists for this branch. Want me to create one?"

3. If yes, follow the standard PR creation flow (title from commits, summary, test plan).

4. If `gh` unavailable or not authenticated → skip silently.

## Every PR should have a linked issue

When creating a PR without a linked issue:
- Ask the user if they want to create an issue first
- If yes, create the issue, then link it with `Closes #N`

## Post-merge branch cleanup

After a PR is merged, clean up the branch:

```bash
# Delete remote branch (if not auto-deleted by GitHub)
gh pr view <N> --json headRefName --jq '.headRefName' | xargs git push origin --delete

# Switch to main and delete local branch
git checkout main
git pull origin main
git branch -d <branch-name>
```

If GitHub has "Automatically delete head branches" enabled, skip the remote delete step.

## Repository auto-detection with `gh`

The `gh` CLI automatically resolves the repository from the git remote of the current directory. Specifying `--repo` manually is error-prone — you may guess the wrong owner or org name.

```bash
# Wrong — guessing the owner
gh issue view 268 --repo some-user/my-repo

# Wrong — hardcoding a different repo by mistake
gh issue view 268 --repo anthropics/claude-code

# Correct — let gh detect from CWD's git remote
gh issue view 268

# If you genuinely need a different repo, confirm first
gh repo view --json nameWithOwner --jq '.nameWithOwner'
# Then use the result
gh issue view 268 --repo Org/actual-repo-name
```

Common failure mode: running `gh issue view N` and getting an issue from the wrong repository because `--repo` was specified with a guessed owner name. This wastes time and can lead to acting on the wrong issue.
<!-- /REFERENCE -->
