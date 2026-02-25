# Playbook

> Inject curated coding guidelines into every Claude Code session — per project, per team.

Playbook lets you define **presets** — sets of coding rules, workflow conventions, and best practices — that Claude follows automatically. No more repeating "always use squash merge" or "update docs after every change" in every conversation.

## How it works

Each preset is a markdown file with two zones:

- **RULES** (~120 tokens) — injected into every session automatically via `SessionStart` hook
- **REFERENCE** — full reference loaded on demand via `/playbook-browse`

Claude sees the active rules in every session and follows them without being asked.

## Installation

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install playbook@tribe-coding
/plugin
```

Select **playbook** → enable **auto-update**.

Then in the next session, run `/playbook-setup` to choose which presets to enable. Restart — done.

> **Auto-update** keeps presets in sync with the latest fixes automatically on each Claude Code restart.

## Available Presets

| Preset | What it enforces |
|--------|-----------------|
| [`documentation-principles`](https://github.com/Tribe-Coding/claude-plugins/blob/main/plugins/playbook/presets/documentation-principles.md) | Doc hierarchy, commit checklist, ADR policy, no TODO-in-code |
| [`github-workflow`](https://github.com/Tribe-Coding/claude-plugins/blob/main/plugins/playbook/presets/github-workflow.md) | Squash merge, PR description updates, issue linking |
| [`macos-python`](https://github.com/Tribe-Coding/claude-plugins/blob/main/plugins/playbook/presets/macos-python.md) | Python 3.12 targeting, no system Python, CWD isolation |
| [`macos-zsh-quirks`](https://github.com/Tribe-Coding/claude-plugins/blob/main/plugins/playbook/presets/macos-zsh-quirks.md) | Zsh/Bash tool quirks: CWD, `echo` escapes, absolute paths |
| [`readme`](https://github.com/Tribe-Coding/claude-plugins/blob/main/plugins/playbook/presets/readme.md) | README as landing page: 5-second test, compact structure, cross-links |

Use `/playbook-browse` to read the full reference for any preset.

## Commands

| Command | What it does |
|---------|-------------|
| `/playbook-setup` | Interactive wizard — enable/disable presets, global or per-project |
| `/playbook-browse` | Read the full REFERENCE zone of any preset |

## Configuration

**Global** (`~/.claude/playbook.json`) — applies to all projects:

```json
{ "presets": ["documentation-principles", "github-workflow"] }
```

**Project** (`.claude-plugin/playbook.json`) — committed to git, applies only here:

```json
{ "presets": ["readme"], "exclude": ["macos-python"] }
```

Project config takes priority. Use `"exclude"` to suppress global presets in a specific project.

## Custom Presets

You can write your own presets for team-specific conventions. See [AUTHORING.md](../../docs/AUTHORING.md) for the format, rule patterns, token budget, and anti-patterns.

## License

MIT
