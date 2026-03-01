# Content Mismatch Detection

The plugin checks that files you're committing/pushing match what the branch name implies.

## Two checkpoints

| Checkpoint | What's checked | Threshold | Default |
|------------|---------------|-----------|---------|
| `git commit` | Staged files vs branch prefix | >80% type mismatch | `ask` |
| `git push` | Full branch diff + commit messages | >50% mismatch | `ask` |

## Example warnings

> **`docs/` branch with code files:**
> "Branch 'docs/update-api' is a docs branch, but 90% of files are code files (9/10 files). Consider using a 'feature/' or 'refactor/' prefix instead."

> **`feature/` branch with only docs:**
> "Branch 'feature/add-login' usually contains code changes, but 85% of files are documentation. Is this intentional?"

## Prefix-to-content mapping

| Prefix | Expected | Warning condition |
|--------|----------|-------------------|
| `feature/`, `bugfix/`, `hotfix/` | Code + tests | Only docs, no code (>80%) |
| `docs/` | Markdown, rst, txt | Code files (>80%) |
| `test/` | Test files | No test files at all |
| `chore/` | Config, CI, deps | Application source code (>80%) |
| `refactor/` | Code | (checks only for `--branch` mode) |
| `release/` | Any | No check |
