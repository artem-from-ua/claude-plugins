---
name: statusline-compact-setup
description: >
  Configure the minimal single-line compact Claude Code statusline
  (repo, worktree, branch, model, effort, context window, context %, and
  session cost). Detects and resolves conflicts with an existing statusline
  before switching.
compatibility: Requires jq and git. macOS and Linux supported. No python3, no network.
---

# Statusline Compact Setup

Wire the compact single-line statusline into `~/.claude/settings.json`, resolving any
conflict with a statusline that is already configured.

## Instructions

1. **Ensure the renderer is installed.** If `~/.claude/statusline-compact.sh` is
   missing, copy it from the plugin and make it executable:
   ```bash
   cp "$(dirname "$0")/../../scripts/statusline-compact.sh" ~/.claude/statusline-compact.sh
   chmod +x ~/.claude/statusline-compact.sh
   ```
   (The SessionStart hook normally does this automatically; this is a fallback.)

2. **Read the current statusline command** from `~/.claude/settings.json`:
   ```bash
   existing=$(jq -r '.statusLine.command // empty' ~/.claude/settings.json 2>/dev/null)
   ```

3. **Conflict detection** — branch on `$existing`:

   - **No conflict** — `$existing` is empty, the file is missing, or it already
     equals `~/.claude/statusline-compact.sh` → go straight to step 4 (idempotent).

   - **Conflict** — `$existing` points at something else. Identify the likely owner
     by inspecting the path:
     - basename ends in `statusline.sh` (i.e. NOT `statusline-compact.sh`)
       → most likely the **`statusline`** plugin (the full three-line statusline
       with API rate-limit bars).
     - anything else → a user-custom or third-party statusline.

     Report to the user exactly what is currently configured (`$existing`) and the
     detected owner, then **ask** them to choose (use AskUserQuestion):
     - **(a) Keep the existing statusline** — abort this setup without changes. If it
       is the `statusline` plugin and they want it gone, tell them to disable it via
       `/plugin` first.
     - **(b) Overwrite** — replace `.statusLine.command` with the compact script.

     Only proceed to step 4 on **explicit** confirmation of option (b). Never
     overwrite silently.

4. **Write the statusLine field**, preserving all other keys. Seed `{}` first if the
   file does not exist:
   ```bash
   [ -f ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json
   tmp=$(mktemp)
   jq '.statusLine = {"type":"command","command":"~/.claude/statusline-compact.sh"}' \
     ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
   ```

5. **Verify dependencies.** Check that `jq` and `git` are on `PATH`; warn (do not fail)
   if either is missing. No `python3` and no network access are required.

6. **Confirm** and summarize the single line's segments: repo name, a yellow `Root` badge in
   the main checkout (a worktree shows no badge — its branch already reads `worktree-…`; the
   gray `Worktree` badge returns only if a worktree has some other branch checked out), the
   current git branch followed by a `[CPM]` status block (red letters, gray brackets — **C** uncommitted
   changes, **P** unpushed commits, **M** PR-not-merged; omitted entirely when none apply),
   model (Opus=green, Fable=red, Sonnet=cyan, Haiku=blue), effort level (low=blue, medium=cyan,
   high=green, xhigh=yellow, max=red), context-window size (yellow below 1M), context used %
   (yellow ≥60%, red ≥80%), and session cost. Note the `M` letter needs `gh` (optional) and is
   served from a background-refreshed cache so the render never blocks.

   Tell the user to restart the session (or start a new one) for the change to apply.

## To revert

- **Disable the compact statusline** — remove the `statusLine` key:
  ```bash
  jq 'del(.statusLine)' ~/.claude/settings.json > /tmp/s && mv /tmp/s ~/.claude/settings.json
  ```
- **Switch back to the full three-line statusline** — run `/statusline:statusline-setup`,
  which re-points `.statusLine.command` at `~/.claude/statusline.sh`.
