---
name: retroscope-setup
description: >
  Interactive setup wizard for retroscope retrospective reports.
  Creates or updates ~/.claude/retroscope.json and .claude-plugin/retroscope.json.
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
- `.claude-plugin/retroscope.json` — project-level (overrides)

## Step 2: Ask Configuration Questions

Use `AskUserQuestion` to collect settings in this order:

1. **Storage directory** — where to store reports. Suggest: `~/devel/retroscope`. If doesn't exist: offer to create + `git init`.
2. **Remote URL** (optional) — detect GitHub username via `gh api user -q .login`, offer `https://github.com/{username}/retroscope`, custom URL, or skip.
3. **Report language** — system default (recommended), English, or custom.
4. **Report generation model** — `haiku` (fastest, ~$0.01–0.03/report, recommended), `sonnet` (higher quality, ~$0.05–0.15/report), or `inherit` (current session model).
5. **Extract mode** — On (default, pre-filter to text-only, ~80–90% token reduction) or Off (full session data, ~5–10x more tokens, better for debugging insights).
6. **Session data source** — `logs` (default, reads full JSONL, reliable even after `/compact` or `/clear`) or `context` (current conversation, faster but may be incomplete).
7. **Suggest /retro on exit?** — Yes (default) or No.
8. **Auto-push reports?** — No (default, commit locally only) or Yes.
9. **Report scope** — `project` (default, reports cover current project only) or `all` (cross-project daily reports aggregating sessions from all projects).

For full field descriptions and defaults, see `${SKILL_DIR}/references/config-schema.md`.

## Step 3: Write Config Files

### User-level: `~/.claude/retroscope.json`

```json
{
  "storageDir": "{chosen_path}",
  "remoteUrl": "{remote_url_or_empty}",
  "language": "{language}",
  "timezone": "{detected_timezone}",
  "model": "{haiku|sonnet|inherit}",
  "extractMode": true,
  "sessionSource": "logs",
  "scope": "{project|all}",
  "suggestRetroOnExit": true,
  "autoPush": false
}
```

Detect timezone:
```bash
readlink /etc/localtime | sed 's|.*/zoneinfo/||'
# fallback:
python3 -c "import datetime; print(datetime.datetime.now().astimezone().tzname())"
```

### Project-level: `.claude-plugin/retroscope.json`

Create `.claude-plugin/` if needed. By default, identical to user-level (user can override per-project later).

## Step 4: Initialize Storage Repository

```bash
mkdir -p "{storageDir}"
git -C "{storageDir}" init
# if remote URL provided:
git -C "{storageDir}" remote add origin "{remoteUrl}"
```

Create `.gitignore` (if missing) with `.DS_Store` and `*.tmp`. Create initial commit if repo is empty.

## Step 5: Show Confirmation

```
✅ Retroscope configured successfully!

Storage:        {storageDir}
Remote:         {remoteUrl or "none (local only)"}
Language:       {language}
Model:          {model}
Extract mode:   {on/off}
Session source: {logs/context}

Next steps:
1. Run /retro session — summarize current session (display only)
2. Run /retro today — generate today's report (saved to storage)
3. Run /retro yesterday — generate yesterday's report
```
