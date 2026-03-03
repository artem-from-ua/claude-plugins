# Context

> [!TIP]
> ✨ ***See exactly what's loaded into your Claude Code session — and how much context budget each source consumes.***

`/ctx-show` collects everything Claude Code loads at session start — CLAUDE.md files, auto-memory, SessionStart hook output, and skill listings — and writes it to a single `.md` snapshot file. A summary table breaks down token usage per source so you know exactly what's filling your context window.

`/ctx-dump` takes the complementary approach: it dumps the **verbatim context from Claude's memory** — exactly what Claude received at session start, including gitStatus and currentDate that `/ctx-show` cannot access.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [🔀 ctx-show vs ctx-dump](#ctx-show-vs-ctx-dump) · [📋 Sources](#sources) · [📊 Summary Table Columns](#summary-table-columns) · [⚡ Commands](#commands) · [📦 Installation](#installation)

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
| Project | Plugin hook     | plantuml@tribe-coding (v1.6.3) · inject-rules |    49 |     836 |       7% |
| Project | Playbook Preset | playbook@tribe-coding (v0.5.5) · documentation-principles |    16 |     308 |       2% |
| Project | Playbook Preset | playbook@tribe-coding (v0.5.5) · github-workflow          |    12 |     178 |       1% |
| Project | Playbook Preset | playbook@tribe-coding (v0.5.5) · macos-python             |    13 |     191 |       1% |
| Project | Playbook Preset | playbook@tribe-coding (v0.5.5) · macos-zsh-quirks         |    13 |     212 |       1% |
| Project | Playbook Preset | playbook@tribe-coding (v0.5.5) · readme                   |    17 |     375 |       3% |
| Project | Plugin hook     | semver@tribe-coding (v0.2.1) · inject-rules        |    20 |     265 |       2% |
| Project | Plugin hook     | retroscope@tribe-coding (v0.2.3) · inject-rules    |     8 |     115 |       1% |
| User    | Skill           | interview-simple                                               |     1 |       5 |       0% |
| Project | Skill           | plantuml@tribe-coding (v1.6.3) · plantuml-diagram-guide       |     1 |      98 |       0% |
| Project | Skill           | semver@tribe-coding (v0.2.1) · semver-guide                   |     1 |      96 |       0% |
| Project | Skill           | context@tribe-coding (v0.6.3) · ctx-show                      |     1 |      95 |       0% |
|         | **TOTAL**       |                                                    |   933 |  11,808 |     100% |

⚠️  Context load (11808 tokens) exceeds threshold (10000 tokens = 5% of 200k context window)

Skills: names + descriptions loaded at session start (full SKILL.md on-demand)

Summary:
- ./CLAUDE.md dominates — 72% of context (8,545 tokens)
- Loaded plugins: plantuml (v1.6.3), semver (v0.2.1), retroscope (v0.2.3)
- Active Playbook presets: 5 presets from playbook@tribe-coding (v0.5.5)
- Total context load: ~11,800 tokens
```

## 🔀 ctx-show vs ctx-dump <a name="ctx-show-vs-ctx-dump"></a>

| Aspect | `/ctx-show` | `/ctx-dump` |
|--------|-------------|-------------|
| Data source | Re-reads files from disk, re-executes hooks | Dumps what Claude actually has in memory |
| Implementation | Bash script (`ctx-show.sh`) | Pure SKILL.md (Claude uses Write tool) |
| Token metrics | Summary table with lines/tokens/context% | No metrics (raw content only) |
| Includes gitStatus, currentDate | No | Yes |
| Use case | Audit what's on disk right now | See exactly what Claude received at session start |
| When they differ | Hook output changed since session start | `/ctx-dump` shows the original version |

## ⚙️ How it works <a name="how-it-works"></a>

The plugin runs `ctx-show.sh`, which:

1. Reads all CLAUDE.md files (global and project)
2. Reads auto-memory (`MEMORY.md`) for the current project
3. Discovers SessionStart hooks from `~/.claude/settings.json` and `.claude/settings.json`
4. Scans enabled plugins in `~/.claude/plugins/cache/` and executes their SessionStart hooks
5. Discovers skills from user dirs (`~/.claude/commands/`, `~/.claude/skills/`), enabled plugins, and project (`{project}/.claude/commands/`)
6. Wraps each source in `<!-- Source: ... -->` comment markers
7. Writes the assembled context to `/tmp/claude-context-{timestamp}.md`
8. Prints the summary table to stderr

Missing files are noted but do not cause errors.

## 📋 Sources <a name="sources"></a>

Collected in load order:

1. `~/.claude/CLAUDE.md` — global user instructions
2. `{project}/CLAUDE.md` — project instructions
3. `~/.claude/projects/{hash}/memory/MEMORY.md` — auto-memory
4. Global SessionStart hooks (from `~/.claude/settings.json`)
5. Project SessionStart hooks (from `{project}/.claude/settings.json`)
6. Plugin SessionStart hooks (enabled plugins in `~/.claude/plugins/cache/`)
7. Skills — SKILL.md listings from user (`~/.claude/commands/`, `~/.claude/skills/`), plugins, and project

## 📊 Summary Table Columns <a name="summary-table-columns"></a>

| Column | Description |
|--------|-------------|
| Scope | `User` (global `~/.claude/`) or `Project` (project-level + plugins) |
| Type | CLAUDE.md · Memory · Plugin hook · User hook · Project hook · Playbook Preset · Skill |
| Source/ID | Shortened path (`~/`, `./`) or plugin identifier `name@marketplace (vX.Y.Z)` |
| Status | Content present · missing/empty · command failed |
| Lines | Line count of the source content |
| ~Tokens | Estimated token count (≈ bytes/3.8) |
| Context% | Each source's share of total context |

Playbook presets appear as individual rows when using playbook plugin v0.3.1+.

**Threshold Warning:** When total tokens exceed 5% of the context window (default 10,000 of 200K), a ⚠️ warning is printed after the TOTAL row. Override with `CTX_CONTEXT_WINDOW` and `CTX_WARN_THRESHOLD` env vars.

## ⚡ Commands <a name="commands"></a>

| Command | Flags | Description |
|---------|-------|-------------|
| `/ctx-show` | `--file` (default) | Write context to `/tmp/claude-context-{timestamp}.md` and print path |
| `/ctx-show` | `--stdout` | Print full context content to terminal |
| `/ctx-dump` | `--file` (default) | Write in-memory context to `/tmp/claude-context-dump-{timestamp}.md` |
| `/ctx-dump` | `--stdout` | Print in-memory context to terminal |

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install context@tribe-coding
/plugin
```

Select **context** → enable **auto-update**.

**Requirements:** `bash`, `jq` (static sources are shown even without `jq`)
