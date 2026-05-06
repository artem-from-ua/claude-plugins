# Playbook

> [!TIP]
> ✨ ***Inject curated coding guidelines into every Claude Code session — per project, per team.***

Playbook lets you define **presets** — sets of coding rules, workflow conventions, and best practices — that Claude follows automatically. No more repeating "always use squash merge" or "update docs after every change" in every conversation.

> [!NOTE]
> [📦 Installation](#installation) · [📋 Presets](#available-presets) · [⚡ Commands](#commands) · [🔧 Configuration](#configuration) · [✏️ Custom Presets](#custom-presets)

## ⚙️ How it works <a name="how-it-works"></a>

Each preset is a markdown file with two zones:

- **RULES** (~120 tokens) — injected into every session automatically via `SessionStart` hook
- **REFERENCE** — full reference loaded on demand via `/playbook-browse`

Claude sees the active rules in every session and follows them without being asked.

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add artem-from-ua/claude-plugins
/plugin install playbook@artem-from-ua
/plugin
```

Select **playbook** → enable **auto-update**.

Then in the next session, run `/playbook-setup` to choose which presets to enable. Restart — done.

> **Auto-update** keeps presets in sync with the latest fixes automatically on each Claude Code restart.

## 📋 Available Presets <a name="available-presets"></a>

| Preset | What it enforces |
|--------|-----------------|
| [`action-over-planning`](https://github.com/artem-from-ua/claude-plugins/blob/main/plugins/playbook/presets/action-over-planning.md) | Bias toward implementation: max 1 planning round, then code |
| [`debugging-discipline`](https://github.com/artem-from-ua/claude-plugins/blob/main/plugins/playbook/presets/debugging-discipline.md) | gather→diagnose→confirm→fix; never modify live state during debugging |
| [`documentation-principles`](https://github.com/artem-from-ua/claude-plugins/blob/main/plugins/playbook/presets/documentation-principles.md) | Doc hierarchy, commit checklist, ADR policy, ripple analysis, automation reflection |
| [`git-safety`](https://github.com/artem-from-ua/claude-plugins/blob/main/plugins/playbook/presets/git-safety.md) | force-with-lease, confirm before destructive ops, no --no-verify bypass |
| [`github-workflow`](https://github.com/artem-from-ua/claude-plugins/blob/main/plugins/playbook/presets/github-workflow.md) | Squash merge, post-merge cleanup, PR description updates, issue linking |
| [`macos-python`](https://github.com/artem-from-ua/claude-plugins/blob/main/plugins/playbook/presets/macos-python.md) | Python 3.12 targeting, no system Python, CWD isolation |
| [`macos-zsh-quirks`](https://github.com/artem-from-ua/claude-plugins/blob/main/plugins/playbook/presets/macos-zsh-quirks.md) | Zsh/Bash tool quirks: CWD, `echo` escapes, absolute paths |
| [`readme`](https://github.com/artem-from-ua/claude-plugins/blob/main/plugins/playbook/presets/readme.md) | README as landing page: 5-second test, compact structure, cross-links |
| [`shell-scripting-safety`](https://github.com/artem-from-ua/claude-plugins/blob/main/plugins/playbook/presets/shell-scripting-safety.md) | Prevent common pitfalls in generated shell scripts |
| [`verify-before-relay`](https://github.com/artem-from-ua/claude-plugins/blob/main/plugins/playbook/presets/verify-before-relay.md) | Verify subagent URLs before relaying to user |

Use `/playbook-browse` to read the full reference for any preset.

## ⚡ Commands <a name="commands"></a>

| Command | What it does |
|---------|-------------|
| `/playbook-setup` | Interactive wizard — enable/disable presets, global or per-project |
| `/playbook-browse` | Read the full REFERENCE zone of any preset |

## 🔧 Configuration <a name="configuration"></a>

**Global** (`~/.claude/playbook.json`) — applies to all projects:

```json
{ "presets": ["documentation-principles", "github-workflow"] }
```

**Project** (`.claude-plugin/playbook.json`) — committed to git, applies only here:

```json
{ "presets": ["readme"], "exclude": ["macos-python"] }
```

Project config takes priority. Use `"exclude"` to suppress global presets in a specific project.

## ✏️ Custom Presets <a name="custom-presets"></a>

You can write your own presets for team-specific conventions. See [AUTHORING.md](../../docs/AUTHORING.md) for the format, rule patterns, token budget, and anti-patterns.
