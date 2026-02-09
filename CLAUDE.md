# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A marketplace of reusable Claude Code plugins (`Tribe Coding`). Each plugin lives under `plugins/<name>/` and follows the Claude Code plugin spec. The marketplace manifest is `.claude-plugin/marketplace.json`.

## Plugins

### plantuml-sync
Keeps PlantUML diagram image URLs in sync with their source blocks in markdown files.

Key components:
- `scripts/plantuml-encode.py` — core encoder/validator. Modes: `--sync` (auto-fix), `--check` (CI validation), stdin (encode raw text). Uses zlib deflate + PlantUML's custom base64 alphabet.
- `scripts/sync-plantuml.sh` — PostToolUse hook (runs after every Write/Edit on `.md` files), calls `plantuml-encode.py --sync`
- `scripts/inject-base-rules.sh` — SessionStart hook, outputs ~200 tokens of formatting rules so Claude knows the two-part pattern (code block + image link)
- `scripts/setup-project.sh` — SessionStart hook, installs git pre-commit hook in `.githooks/` and sets `core.hooksPath`
- `templates/pre-commit` — blocks commits when PlantUML URLs are stale
- `templates/plantuml-sync.yml` — GitHub Actions workflow for PR checks
- `skills/plantuml-diagram-guide/` — on-demand skill with full diagram type catalog
- `commands/plantuml-validate/` — user-invocable `/plantuml-validate` command

### statusline
Custom Claude Code statusline showing real-time session info.

Key components:
- `scripts/statusline.sh` — main script, reads JSON from stdin (piped by Claude Code), outputs ANSI-colored status line. Fetches Anthropic OAuth usage API (cached 60s in `/tmp/claude-statusline-usage-cache`), reads OAuth token from macOS Keychain
- `scripts/setup-statusline.sh` — SessionStart hook, copies `statusline.sh` to `~/.claude/statusline.sh`
- `commands/statusline-setup/` — user-invocable `/statusline-setup` command, configures `~/.claude/settings.json`

## Plugin Structure Convention

```
plugins/<name>/
├── .claude-plugin/plugin.json    # manifest (name, version, commands, skills, hooks)
├── hooks/hooks.json              # hook definitions (PostToolUse, SessionStart)
├── scripts/                      # shell/python scripts called by hooks
├── commands/<cmd>/SKILL.md       # user-invocable slash commands
├── skills/<skill>/SKILL.md       # on-demand context-efficient skills
└── templates/                    # project templates (pre-commit, CI)
```

## Skills Standard

All SKILL.md files must follow the [agentskills.io specification](https://agentskills.io/specification):
- YAML frontmatter with `name` and `description` is required
- Optional: `compatibility`, `license`, `metadata`
- When creating or editing SKILL.md files, always include valid frontmatter

## Adding a New Plugin

1. Create `plugins/<name>/` with the structure above
2. Add `.claude-plugin/plugin.json` manifest
3. All SKILL.md files must include YAML frontmatter per the [agentskills.io spec](https://agentskills.io/specification)
4. Register in `.claude-plugin/marketplace.json`

## Dependencies

- plantuml-sync: Python 3.x, git
- statusline: jq, curl, macOS Keychain (for Anthropic OAuth token)
