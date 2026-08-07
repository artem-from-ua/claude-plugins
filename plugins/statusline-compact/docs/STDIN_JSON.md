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
| `.workspace.git_worktree` | checkout badge + branch colorization | Present **only** in worktree sessions — no `git rev-parse` needed. When absent, the yellow `Root` badge is shown. When set, the badge is dropped (the branch already reads `worktree-…`) and the branch is colorized with the worktree layout: dim `worktree-` head, `+` as the prefix delimiter. A worktree whose branch is *not* named `worktree-…` falls back to the gray `Worktree` badge. The field's **value** is never rendered — the branch text comes from local `git`. |
| `.model.display_name` | model | e.g. `"Opus 4.8 (1M context)"`. The trailing ` (… context)` is trimmed; the keyword is color-coded and the version dimmed. |
| `.effort.level` | effort | One of `low`, `medium`, `high`, `xhigh`, `max` (least→most). Color-coded blue→cyan→green→yellow→red. Hidden when absent. |
| `.transcript_path` | ultra-mode effort (violet `ultra`) | Path to the session JSONL. Scanned for the last genuine `/effort` command (`Set effort level to <word>` inside a `type:"user"` record). When it is `ultracode`/`ultraplan`, the effort segment is replaced by a violet `ultra` token; these words exist ONLY as this transcript text — `.effort` never carries them (ultra maps to `xhigh`). Falls back to the normal `.effort.level` when the last `/effort` was a normal level, the file is missing, or the field is absent. |
| `.context_window.context_window_size` | context size | e.g. `1000000 → 1M`, `200000 → 200K`. |
| `.context_window.used_percentage` | context used % | Integer. Can be `null` on a fresh session → the segment is hidden. Yellow ≥ 60%, red ≥ 80%. |
| `.cost.total_cost_usd` | session cost | Formatted `$X.XX`; always shown, even `$0.00`. |

The git branch and the `[CPM]` status block are **not** read from stdin. Branch, **C** (uncommitted)
and **P** (unpushed) are computed locally — `git branch --show-current`, `git status --porcelain`,
`git rev-list --count @{upstream}..HEAD` — with no network. **M** (PR-not-merged) is **gated** on the
same local refs (only checked once the branch has an upstream and no unpushed commits) and then read
from a small per-branch cache file that a detached background `gh` refreshes, so the render never
blocks on the network (see the `[CPM]` section in the README and ACCEPTANCE_TESTS).

## Ultra-mode detection (why it needs the transcript)

`ultracode` / `ultraplan` are **not** structured values anywhere in the payload — `.effort.level`
only ever holds the coarse enum (`low`/`medium`/`high`/`xhigh`/`max`), and ultra maps down to
`xhigh`. The native Claude Code UI shows the same coarse level. The **only** signal that the user is
in an ultra mode is the plain-text echo the `/effort` command writes into a message body:

```
Set effort level to ultracode (this session only): xhigh + dynamic workflow orchestration
```

The plugin scans `.transcript_path` (the session JSONL) for the last such line. A naive
`grep 'Set effort level to' | tail -1` is **wrong**: the transcript also contains assistant/user
prose that quotes the phrase (e.g. this very document), and `tail -1` would pick the most-recently
*quoted* word rather than the last real selection — observed returning `ultraplan`/`ultrathink`
while the real `/effort` was `max`. The fix is to filter by record type: a genuine `/effort` echo is
a `type:"user"` record carrying `<local-command-stdout>`. So the detector is a fast `grep` to narrow
to candidate lines, then `jq` over just those, keeping `type=="user"`:

```bash
grep -aE '<local-command-stdout>Set effort level to' "$transcript" \
  | jq -rc 'select(.type=="user")
      | (.message.content // empty)
      | (if type=="array" then (map(.text // "") | join("\n")) else tostring end)
      | (capture("<local-command-stdout>Set effort level to (?<w>[a-z]+)").w // empty)' \
  | tail -1
```

`ultracode` and `ultraplan` are one effort slot renamed by permission mode (normal → `ultracode`,
plan → `ultraplan`), so the last `/effort` word is always exactly one of them — both render the same
way: the effort segment becomes a single violet `ultra` token. `ultrathink` is a per-turn keyword on
a different axis; it is never an `/effort` word and is deliberately **not** reflected here.

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
name. The `git_worktree` value is never read for display: the rendered branch comes from local
`git branch --show-current`, which in a Claude Code worktree happens to be `worktree-<git_worktree>`
(here `worktree-feature+x`). What the field does is suppress the yellow `Root` badge and switch the
branch to the worktree colorization — dim `worktree-` head, `+` as the prefix delimiter. If a
worktree session has a branch *not* named `worktree-…`, the gray `Worktree` badge is shown instead,
so the worktree is still identifiable.
