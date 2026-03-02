# statusline-compact

> [!TIP]
> ✨ ***All the essentials in one line — the most space-efficient Claude Code statusline.***

Single-line statusline with brightness-coded API usage values.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [📦 Installation](#installation) · [🔧 Setup](#setup) · [⚖️ Compared to statusline](#compared-to-statusline) · [📚 Reference](#reference)

## 🎬 Demo <a name="demo"></a>

```markdown
5h 92% 50m !!   7d 22% ~5d   extra $4.79   Sonnet 4.6   context 30%   my-project/   main*   session my-feature !!
```

Values dim at low usage and brighten as they climb: yellow above 90%, red at 100%.
`!!` = warning, `XX` = exhausted. Session `!!` = no custom name set (use `/rename` to fix).

## ⚙️ How it works <a name="how-it-works"></a>

| Trigger | What happens |
|---------|-------------|
| SessionStart | Installs compact statusline script to `~/.claude/` |
| Every prompt | Reads API usage from Anthropic OAuth API (cached 60s) |

**Brightness coding:**
- Model brightness = capability tier: Opus bright, Sonnet default, Haiku dim
- Usage values: dim at low, brighten as they climb, yellow > 90%, red at 100%

**Tracked values:** 5h rate limit · 7d rate limit · extra usage ($ amount) · context % · directory · git branch · model name · session name

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install statusline-compact@tribe-coding
```

Select **statusline-compact** in `/plugin` → enable **auto-update**.

**Requirements:** `jq`, `curl`, `python3`; macOS Keychain or `~/.claude/.credentials.json` (for Anthropic OAuth token)

## 🔧 Setup <a name="setup"></a>

```bash
/statusline-compact:statusline-setup
```

The wizard:
- **Copies** the compact statusline script to `~/.claude/`
- **Configures** the `statusLine` field in `~/.claude/settings.json`
- **Verifies** `jq` and `curl` are available

Restart your session after setup.

## ⚖️ Compared to statusline <a name="compared-to-statusline"></a>

| | statusline | statusline-compact |
|-|------------|-------------------|
| Layout | 3 lines | 1 line |
| Progress bars | Yes (visual) | No (% only) |
| Space usage | More | Less |
| Choose when | You want visual progress bars | You want minimal terminal footprint |

## 📚 Reference <a name="reference"></a>

- [`docs/ACCEPTANCE_TESTS.md`](docs/ACCEPTANCE_TESTS.md) — test suite
