# statusline

> [!TIP]
> ✨ ***Know your API limits, context, and git state at a glance — without leaving Claude Code.***

Three-line Claude Code statusline with real-time API usage, progress bars, and session info.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [📦 Installation](#installation) · [🔧 Setup](#setup) · [📚 Reference](#reference)

## 🎬 Demo <a name="demo"></a>

```markdown
5h/10m････■■■■■■■■■■■■■̿■■■■■■■■■■■■■■■■■■･･3h42m      🤖･Sonnet･4.6       ✏️･clever-zooming-firefly
7d/6h･････････■■■■■■■■■■■■■■■■■■■■■■■■■̿■■■･･~5d        📚･32%              📁･my-project
1M/1d･⏸️･■■■■■■■■■■■■■■■■■■■■■■■■■■■■̿･･¤4.79       💵･$4.79            🌿･main･⚠️
```

**Line 1:** 5h limit (30 blocks/10min) · model · session name
**Line 2:** 7d limit (28 blocks/6h) · context window % · directory
**Line 3:** extra usage (N blocks/1day) · session cost · git branch

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
/plugin marketplace add artem-from-ua/claude-plugins
/plugin install statusline@artem-from-ua
```

Select **statusline** in `/plugin` → enable **auto-update**.

**Requirements:** `jq`, `curl`, `python3`; macOS Keychain or `~/.claude/.credentials.json` (for Anthropic OAuth token)

## 🔧 Setup <a name="setup"></a>

```bash
/statusline:statusline-setup
```

The wizard:
- **Copies** `statusline.sh` to `~/.claude/`
- **Configures** the `statusLine` field in `~/.claude/settings.json`
- **Verifies** `jq` and `curl` are available

Restart your session after setup.

## 📚 Reference <a name="reference"></a>

- [`docs/ACCEPTANCE_TESTS.md`](docs/ACCEPTANCE_TESTS.md) — test suite
- [`docs/STDIN_JSON.md`](docs/STDIN_JSON.md) — all JSON fields piped by Claude Code to `statusline.sh`
