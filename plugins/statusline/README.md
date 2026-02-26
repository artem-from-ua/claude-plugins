# statusline

> Know your API limits, context, and git state at a glance — without leaving Claude Code.

Two-line Claude Code statusline with real-time API usage, progress bars, and session info.

## 🎬 Demo

```
⏳ [████████░░░░░░░░░░░░] 3h 42m   📅 [████░░░░░░░░░░░░░░░░░] ~5d 8h   💸 [██░░░░░░░░░░░░░] $4.79
📁 my-project/   🌿 main*   🤖 claude-sonnet-4-6   📚 32%
```

**Line 1:** 5-hour limit · 7-day limit · extra usage (monthly billing with $ spent)
**Line 2:** directory · git branch (yellow when dirty) · model · context window %

## ⚙️ How it works

| Trigger | What happens |
|---------|-------------|
| SessionStart | Installs `statusline.sh` to `~/.claude/` |
| Every prompt | Reads API usage from Anthropic OAuth API (cached 60s) |

Model color-coding: Opus = red, Sonnet = green, Haiku = blue.
Context warning thresholds: yellow ≥ 60%, red ≥ 80%.
Warning icons: ⚠️ above 90%, ❌ at 100%.

**Progress bar resolution:**

| Bar | Blocks | Resolution |
|-----|--------|-----------|
| 5h | 20 | 15 min/block |
| 7d | 21 | 8 h/block |
| Extra | days in month | 1 day/block |

Cache refresh: 60s (all bars).

## 📦 Installation

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install statusline@tribe-coding
```

Then run the setup command to configure `~/.claude/settings.json`:

```bash
/statusline:statusline-setup
```

Select **statusline** in `/plugin` → enable **auto-update**. Restart your session — done.

**Requirements:** `jq`, `curl`, `python3`; macOS Keychain or `~/.claude/.credentials.json` (for Anthropic OAuth token)

## Reference

- [`docs/ACCEPTANCE_TESTS.md`](docs/ACCEPTANCE_TESTS.md) — test suite
- [`docs/STDIN_JSON.md`](docs/STDIN_JSON.md) — all JSON fields piped by Claude Code to `statusline.sh`
