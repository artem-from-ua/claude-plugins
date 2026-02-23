---
name: retroscope-setup
description: >
  Interactive setup wizard for retroscope retrospective reports.
  Creates or updates ~/.claude/retroscope.json and .claude/retroscope.json.
  Run this command to configure storage directory, language, model, and options.
  Keywords: retroscope setup, configure retro, retroscope config, setup retrospective.
---

# /retroscope:setup — Retroscope Configuration Wizard

Interactive wizard to configure the retroscope plugin for your environment and project.

## What this command does

1. Checks for existing configuration
2. Asks setup questions via dialog
3. Creates/updates config files
4. Initializes storage repository if needed
5. Shows next steps

## Step 1: Check Existing Config

Read existing configs (show current values as defaults):
- `~/.claude/retroscope.json` — user-level (global defaults)
- `.claude/retroscope.json` — project-level (overrides)

## Step 2: Ask Configuration Questions

Use `AskUserQuestion` to collect settings.

**Question 1 — Storage directory:**

Ask: "Where should retroscope store reports?"

Provide a text input field. Suggest: `/Users/<username>/devel/retroscope` or `~/retroscope`.

If the directory doesn't exist: offer to create it and run `git init`.

**Question 2 — Remote URL (optional):**

Detect GitHub username:
```bash
gh api user -q .login 2>/dev/null
```

Options:
- `https://github.com/{username}/retroscope` — use detected GitHub repo (if username found)
- Enter custom URL
- Skip (no remote)

**Question 3 — Report language:**

Options:
- System default (from `~/.claude/settings.json` locale or `$LANG`) — Recommended
- English
- Custom (ask for language name)

**Question 4 — Report generation model:**

Options:
- `haiku` — Claude Haiku (fastest, cheapest; ~$0.01–0.03 per daily report) — Recommended
- `sonnet` — Claude Sonnet (higher quality; ~$0.05–0.15 per daily report)
- `inherit` — Use current session model (no subagent spawned)

**Question 5 — Extract mode:**

Options:
- On (default) — Pre-filter sessions to user prompts + assistant responses only. Reduces tokens by ~80–90%. Good for task tracking, decisions, and status overviews.
- Off — Send complete session data including tool inputs/outputs, file contents, error messages. ~5–10x more tokens. Better for detailed debugging insights and nuanced communication analysis.

**Question 6 — Suggest /retro on exit?**

Options:
- Yes — SessionEnd hook shows reminder before exiting (default)
- No — Silent exit

**Question 7 — Auto-push reports?**

Options:
- No — Commit locally only (default, recommended)
- Yes — Push to remote after each report commit

## Step 3: Write Config Files

### User-level config: `~/.claude/retroscope.json`

Write global defaults (storageDir, language, timezone):

```json
{
  "storageDir": "{chosen_path}",
  "remoteUrl": "{remote_url_or_empty}",
  "language": "{language}",
  "timezone": "{detected_timezone}",
  "model": "{haiku|sonnet|inherit}",
  "extractMode": {true|false},
  "suggestRetroOnExit": {true|false},
  "autoPush": {false|true}
}
```

Detect timezone:
```bash
python3 -c "import datetime; print(datetime.datetime.now().astimezone().tzname())"
# or on macOS:
readlink /etc/localtime | sed 's|.*/zoneinfo/||'
```

### Project-level config: `.claude/retroscope.json`

Create `.claude/` if needed, write project-level overrides. By default, identical to user-level config (user can manually edit to override per project later).

## Step 4: Initialize Storage Repository

If storage directory doesn't exist:
```bash
mkdir -p "{storageDir}"
git -C "{storageDir}" init
```

If remote URL provided:
```bash
git -C "{storageDir}" remote add origin "{remoteUrl}"
```

Create initial `.gitignore` in storage dir (if it doesn't exist):
```
.DS_Store
*.tmp
```

Create initial commit if repo is empty:
```bash
git -C "{storageDir}" add .gitignore
git -C "{storageDir}" commit -m "chore: initialize retroscope storage"
```

## Step 5: Show Confirmation

```
✅ Retroscope configured successfully!

Storage:  {storageDir}
Remote:   {remoteUrl or "none (local only)"}
Language: {language}
Model:    {model}
Extract:  {on/off}

Next steps:
1. Run /retro session — summarize current session (display only)
2. Run /retro today — generate today's report (saved to storage)
3. Run /retro yesterday — generate yesterday's report

Tip: Reports are saved to:
  {storageDir}/reports/{project}/daily/{YYYY}/{MM}/{DD}/summary.md
```

## Config Schema Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `storageDir` | string | — | Absolute path to storage git repo (REQUIRED) |
| `remoteUrl` | string | `""` | Git remote URL for pushing reports |
| `language` | string | `"en"` | Report language code (e.g. "en", "uk", "de") |
| `timezone` | string | system TZ | IANA timezone name (e.g. "Europe/Kyiv") |
| `model` | string | `"haiku"` | Report model: `haiku`, `sonnet`, or `inherit` |
| `extractMode` | boolean | `true` | Pre-filter sessions to text-only content |
| `suggestRetroOnExit` | boolean | `true` | Show /retro reminder in SessionEnd hook |
| `autoPush` | boolean | `false` | Git push after each report commit |
