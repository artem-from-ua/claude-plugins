# statusline

> [!TIP]
> ✨ ***Know your API limits, context, and git state at a glance — without leaving Claude Code.***

Three-line Claude Code statusline with real-time API usage, progress bars, and session info.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [📦 Installation](#installation)

## 🎬 Demo

```
5h/10m････■■■■■■■■■■■■■̿■■■■■■■■■■■■■■■■■■･･3h42m      🤖･Sonnet･4.6       📁･my-project
7d/6h･････････■■■■■■■■■■■■■■■■■■■■■■■■■̿■■■･･~5d        📚･32%              🌿･main･⚠️
1M/1d･⏸️･■■■■■■■■■■■■■■■■■■■■■■■■■■■■̿･･¤4.79       💵･$4.79
```

**Line 1:** 5h limit (30 blocks/10min) · model · directory
**Line 2:** 7d limit (28 blocks/6h) · context window % · git branch
**Line 3:** extra usage (N blocks/1day) · session cost

## ⚙️ How it works <a name="how-it-works"></a>

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
| 5h | 30 | 10 min/block |
| 7d | 28 | 6 h/block |
| Extra | days in month | 1 day/block |

Cache refresh: 60s (all bars).

## 📦 Installation <a name="installation"></a>

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
