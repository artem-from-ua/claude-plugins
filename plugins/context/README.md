# Context

> [!TIP]
> ✨ ***See exactly what's loaded into your Claude Code session — and how much context budget each source consumes.***

`/ctx-show` collects everything Claude Code loads at session start — CLAUDE.md files, auto-memory, and SessionStart hook output — and writes it to a single `.md` snapshot file. A summary table breaks down token usage per source so you know exactly what's filling your context window.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [📋 Sources](#sources) · [📊 Summary Table Columns](#summary-table-columns) · [⚡ Commands](#commands) · [📦 Installation](#installation)

## 🎬 Demo <a name="demo"></a>

```markdown
> /ctx-show

● Bash(bash ".../scripts/ctx-show.sh")
  Context file saved: /tmp/claude-context-20260225-232455.md

| Scope   | Type            | Source/ID                                          | Lines | ~Tokens | Context% |
|---------|-----------------|----------------------------------------------------|------:|--------:|---------:|
| User    | CLAUDE.md       | ~/.claude/CLAUDE.md                                |    15 |     191 |       1% |
| Project | CLAUDE.md       | ./CLAUDE.md                                        |   752 |   8,545 |      74% |
| Project | Memory          | ~/.claude/projects/.../memory/MEMORY.md            |    14 |     198 |       1% |
| Project | Plugin hook     | plantuml@tribe-coding (v1.6.3) · inject-base-rules |    49 |     836 |       7% |
| Project | Playbook Preset | documentation-principles                           |    16 |     308 |       2% |
| Project | Playbook Preset | github-workflow                                    |    12 |     178 |       1% |
| Project | Playbook Preset | macos-python                                       |    13 |     191 |       1% |
| Project | Playbook Preset | macos-zsh-quirks                                   |    13 |     212 |       1% |
| Project | Playbook Preset | readme                                             |    17 |     375 |       3% |
| Project | Plugin hook     | semver@tribe-coding (v0.2.1) · inject-rules        |    20 |     265 |       2% |
| Project | Plugin hook     | retroscope@tribe-coding (v0.2.3) · inject-rules    |     8 |     115 |       1% |
|         | **TOTAL**       |                                                    |   929 |  11,414 |     100% |

Playbook Presets injected by playbook@tribe-coding (v0.5.5)

Summary:
- ./CLAUDE.md dominates — 74% of context (8,545 tokens)
- Loaded plugins: plantuml (v1.6.3), semver (v0.2.1), retroscope (v0.2.3)
- Active Playbook presets: 5 presets from playbook@tribe-coding (v0.5.5)
- Total context load: ~11,400 tokens
```

## ⚙️ How it works <a name="how-it-works"></a>

The plugin runs `ctx-show.sh`, which:

1. Reads all CLAUDE.md files (global and project)
2. Reads auto-memory (`MEMORY.md`) for the current project
3. Discovers SessionStart hooks from `~/.claude/settings.json` and `.claude/settings.json`
4. Scans enabled plugins in `~/.claude/plugins/cache/` and executes their SessionStart hooks
5. Wraps each source in `<!-- Source: ... -->` comment markers
6. Writes the assembled context to `/tmp/claude-context-{timestamp}.md`
7. Prints the summary table to stderr

Missing files are noted but do not cause errors.

## 📋 Sources <a name="sources"></a>

Collected in load order:

1. `~/.claude/CLAUDE.md` — global user instructions
2. `{project}/CLAUDE.md` — project instructions
3. `~/.claude/projects/{hash}/memory/MEMORY.md` — auto-memory
4. Global SessionStart hooks (from `~/.claude/settings.json`)
5. Project SessionStart hooks (from `{project}/.claude/settings.json`)
6. Plugin SessionStart hooks (enabled plugins in `~/.claude/plugins/cache/`)

## 📊 Summary Table Columns <a name="summary-table-columns"></a>

| Column | Description |
|--------|-------------|
| Scope | `User` (global `~/.claude/`) or `Project` (project-level + plugins) |
| Type | CLAUDE.md · Memory · Plugin hook · User hook · Project hook · Playbook Preset |
| Source/ID | Shortened path (`~/`, `./`) or plugin identifier `name@marketplace (vX.Y.Z)` |
| Status | Content present · missing/empty · command failed |
| Lines | Line count of the source content |
| ~Tokens | Estimated token count (≈ chars/4) |
| Context% | Each source's share of total context |

Playbook presets appear as individual rows when using playbook plugin v0.3.1+.

## ⚡ Commands <a name="commands"></a>

| Command | Flags | Description |
|---------|-------|-------------|
| `/ctx-show` | `--file` (default) | Write context to `/tmp/claude-context-{timestamp}.md` and print path |
| `/ctx-show` | `--stdout` | Print full context content to terminal |

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install context@tribe-coding
/plugin
```

Select **context** → enable **auto-update**.

**Requirements:** `bash`, `jq` (static sources are shown even without `jq`)
