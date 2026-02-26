# Retroscope

> Review what you accomplished today — structured retros from your Claude Code sessions.

A Claude Code plugin that generates retrospective summary reports from your Claude Code sessions. Review what you accomplished, track open questions, and get insights into your productivity and communication patterns.

> **Scroll to: [⚡ Quick Start](#quick-start) · [⚙️ How it works](#how-it-works) · [⚙️ Configuration](#configuration)**

## What it does

- **`/retro session`** — Summarize the current session from conversation context (display only)
- **`/retro today`** — Aggregate report for all today's sessions, saved to your storage repo
- **`/retro yesterday`** — Aggregate report for yesterday's sessions, saved to your storage repo

Reports include: task outcomes, decisions made, open questions, GitHub/PR references, productivity metrics, and suggestions for improving your Claude Code workflow.

## ⚡ Quick Start <a name="quick-start"></a>

1. Install the plugin: `/plugin install retroscope@tribe-coding`
2. Start a Claude Code session
3. Run `/retro` — if no config is found, it will offer to run setup automatically
4. Work normally in Claude Code
5. Run `/retro today` at end of day

> **Tip:** You can also run `/retroscope:setup` directly at any time to configure or update settings.

## Report Format

```markdown
# 📋 Retroscope: my-project — 2026-02-23

## 📊 Overview
| Metric | Value |
|--------|-------|
| ⏱️ Duration | 10:15–13:42 (3h 27m) |
| 💬 Sessions | 2 |
| 🤖 Model | claude-sonnet-4-6 |
| 🌿 Branch(es) | feature/retroscope, main |

## 🎯 Performance Assessment
Highly productive session focused on new plugin development...

## 📝 Tasks & Outcomes
| Status | Task | Links |
|--------|------|-------|
| ✅ Done | Implement find-sessions.py | 📌 PR #70 |
| 🚧 In progress | ACCEPTANCE_TESTS.md | — |
| ❓ Open | Weekly rollup design | — |

## 📄 Documentation Changes
| Change | File(s) |
|--------|---------|
| Added acceptance tests | `docs/ACCEPTANCE_TESTS.md` |

## 💬 Communication Insights
...

## 📈 Productivity Metrics
- Token usage: 1.2M input / 45K output
- Estimated cost: $4.84 actual / $32.36 naive (6.7x cache savings)
- Tool breakdown: Read: 42, Bash: 18, Edit: 15, Write: 7

## 🔮 Next Steps
- Implement /retro this-week
- Add streak tracking
```

## Storage Structure

Reports are saved as git-tracked markdown files:

```
{storageDir}/
└── reports/
    └── {project-name}/
        └── daily/
            └── 2026/
                └── 02/
                    └── 23/
                        └── summary.md
```

## ⚙️ Configuration <a name="configuration"></a>

Config is stored at `~/.claude/retroscope.json` (user-level) and `.claude-plugin/retroscope.json` (project-level overrides).

| Field | Default | Description |
|-------|---------|-------------|
| `storageDir` | — | Path to storage git repo (required) |
| `remoteUrl` | `""` | Git remote for pushing reports |
| `language` | `"en"` | Report language |
| `timezone` | system | IANA timezone name |
| `model` | `"haiku"` | Report model: `haiku`, `sonnet`, or `inherit` |
| `extractMode` | `true` | Pre-filter to text-only (reduces tokens 80–90%) |
| `sessionSource` | `"logs"` | `/retro session` data source: `logs` (full JSONL file, reliable even after `/compact` or `/clear`) or `context` (current conversation memory, faster but may miss earlier turns) |
| `suggestRetroOnExit` | `true` | Show `/retro` reminder on session exit |
| `autoPush` | `false` | Auto-push after each report commit |

## ⚙️ How it works <a name="how-it-works"></a>

1. **Session discovery** — `find-sessions.py` locates JSONL session files in `~/.claude/projects/` for the target date
2. **Content extraction** — Filters user prompts and assistant responses (skips tool inputs/outputs when extract mode is on)
3. **Statistics** — Aggregates token usage, tool calls, duration across sessions; calculates two cost estimates: *actual* (with cache discounts) and *naive* (all tokens at full input rate, as reported by Claude Code). Pricing fetched from Anthropic docs, cached 24h, with hardcoded fallback
4. **Report generation** — Claude generates the report using the template, optionally using a haiku subagent for cost efficiency
5. **Storage** — Saves to the configured storage repo and creates a git commit
6. **Caching** — If a report already exists and is newer than all session files, displays cached version instantly

## Cost Estimates

| Config | Sessions | Est. Cost |
|--------|----------|----------|
| Haiku + extract mode ON | 2 avg sessions | ~$0.01–0.03 |
| Haiku + extract mode OFF | 2 avg sessions | ~$0.05–0.15 |
| Sonnet + extract mode ON | 2 avg sessions | ~$0.05–0.15 |
| Sonnet + extract mode OFF | 2 avg sessions | ~$0.20–0.60 |

## Future Roadmap (v0.2.0+)

- `/retro this-week` — aggregate daily reports Mon–today
- `/retro last-week` — Mon–Sun of previous week
- Streak tracking — consecutive productive days, activity heatmap
- CLAUDE.md audit — suggest rules based on repeated session patterns
- Cost tracking per day/week rollup (per-session cost already tracked in v0.1.1)
- Focus score — on-task vs tangential exchange ratio
- Git stats integration — lines changed, commits per session
- Export formats — JSON, CSV for external dashboards
- Team mode — shared storage repo, aggregated reports
- Smart reminders — detect recurring open questions across sessions
- Session tagging — auto-tag by activity type (debugging, feature dev, docs, review)
- Burnout detection — flag long low-productivity sessions

## Troubleshooting

**No sessions found for today:**
- Check that `CLAUDE_PROJECT_DIR` matches your project path
- Sessions are stored per-project in `~/.claude/projects/<encoded-path>/`
- Encoded path: `/Users/artem/devel/foo` → `-Users-artem-devel-foo`

**Storage dir not initialized:**
- Run `/retro` and choose "Yes, run setup now" when prompted, or run `/retroscope:setup` directly

**Report quality is poor:**
- Switch from `haiku` to `sonnet` model in config
- Disable extract mode for more detailed context
- For session mode, run during the session (not after)

**Plugin not loading:**
- Verify `retroscope` is in your enabled plugins in `~/.claude/settings.json`
- Restart Claude Code to pick up the latest plugin cache
