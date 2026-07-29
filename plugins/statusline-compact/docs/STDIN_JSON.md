# statusline-compact stdin JSON Reference

Claude Code pipes JSON to the statusline command via stdin before every render. This document
lists only the fields `statusline-compact.sh` consumes. For the full field catalogue, see the
[`statusline` plugin's reference](../../statusline/docs/STDIN_JSON.md) and the
[official Claude Code documentation](https://code.claude.com/docs/en/statusline).

## Fields consumed

| Field | Used for | Notes |
|-------|----------|-------|
| `.workspace.repo.name` | repo name | Preferred source; correct even inside a worktree. |
| `.workspace.project_dir` | repo-name fallback | Basename used only when `repo.name` is absent. Inside a worktree this is the worktree dir, not the repo root — hence the `repo.name` preference. |
| `.cwd` | repo-name fallback + git | Basename is the last-resort repo name; also the directory `git` is run in. |
| `.workspace.git_worktree` | worktree segment | Present **only** in worktree sessions. Its presence is how the plugin knows it is in a worktree — no `git rev-parse` needed. |
| `.model.display_name` | model | e.g. `"Opus 4.8 (1M context)"`. The trailing ` (… context)` is trimmed; the keyword is color-coded and the version dimmed. |
| `.effort.level` | effort | One of `low`, `medium`, `high`, `xhigh`, `max` (least→most). Color-coded blue→cyan→green→yellow→red. Hidden when absent. |
| `.context_window.context_window_size` | context size | e.g. `1000000 → 1M`, `200000 → 200K`. |
| `.context_window.used_percentage` | context used % | Integer. Can be `null` on a fresh session → the segment is hidden. Yellow ≥ 60%, red ≥ 80%. |
| `.cost.total_cost_usd` | session cost | Formatted `$X.XX`; always shown, even `$0.00`. |

The git branch and dirty flag are **not** read from stdin — they are computed locally with
`git -C "$cwd" branch --show-current` and `git status --porcelain`, matching the `statusline` plugin.

## Worktree detection

The only structural difference between a worktree and a non-worktree session is the presence of
`.workspace.git_worktree` (and a top-level `.worktree` object). The plugin keys off
`.workspace.git_worktree` alone.

Non-worktree session (abridged):

```json
{
  "cwd": "/home/user/devel/my-project",
  "workspace": {
    "project_dir": "/home/user/devel/my-project",
    "repo": { "host": "github.com", "owner": "me", "name": "my-project" }
  },
  "model": { "display_name": "Opus 4.8 (1M context)" },
  "effort": { "level": "high" },
  "context_window": { "context_window_size": 1000000, "used_percentage": 5 },
  "cost": { "total_cost_usd": 0.52 }
}
```

Worktree session (abridged) — note `git_worktree` and the top-level `worktree` block:

```json
{
  "cwd": "/home/user/devel/my-project/.claude/worktrees/feature+x",
  "workspace": {
    "project_dir": "/home/user/devel/my-project/.claude/worktrees/feature+x",
    "git_worktree": "feature+x",
    "repo": { "host": "github.com", "owner": "me", "name": "my-project" }
  },
  "worktree": {
    "name": "feature/x",
    "path": "/home/user/devel/my-project/.claude/worktrees/feature+x",
    "branch": "worktree-feature+x",
    "original_cwd": "/home/user/devel/my-project",
    "original_branch": "main"
  },
  "model": { "display_name": "Opus 4.8 (1M context)" },
  "effort": { "level": "high" },
  "context_window": { "context_window_size": 1000000, "used_percentage": 5 },
  "cost": { "total_cost_usd": 0.69 }
}
```

In the worktree case, `repo.name` is still `my-project`, while the basename of `project_dir` /
`cwd` would be `feature+x` — which is why the plugin prefers `.workspace.repo.name` for the repo
name and surfaces the worktree name separately (dimmed) as `feature+x`.
