# statusline-compact

> All the essentials in one line — the most space-efficient Claude Code statusline.

Single-line statusline with brightness-coded API usage values.

## 🎬 Demo

```
5h 92% 50m !!   7d 22% ~5d   extra $4.79   Sonnet 4.6   context 30%   my-project/   main*
```

Values dim at low usage and brighten as they climb: yellow above 90%, red at 100%.
`!!` = warning, `XX` = exhausted.

## ⚙️ How it works

| Trigger | What happens |
|---------|-------------|
| SessionStart | Installs compact statusline script to `~/.claude/` |
| Every prompt | Reads API usage from Anthropic OAuth API (cached 60s) |

**Brightness coding:**
- Model brightness = capability tier: Opus bright, Sonnet default, Haiku dim
- Usage values: dim at low, brighten as they climb, yellow > 90%, red at 100%

**Tracked values:** 5h rate limit · 7d rate limit · extra usage ($ amount) · context % · directory · git branch · model name

## 📦 Installation

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install statusline-compact@tribe-coding
```

Then run the setup command to configure `~/.claude/settings.json`:

```bash
/statusline-compact:statusline-setup
```

Select **statusline-compact** in `/plugin` → enable **auto-update**. Restart your session — done.

**Requirements:** `jq`, `curl`, `python3`; macOS Keychain or `~/.claude/.credentials.json` (for Anthropic OAuth token)

## Compared to statusline

| | statusline | statusline-compact |
|-|------------|-------------------|
| Layout | 2 lines | 1 line |
| Progress bars | Yes (visual) | No (% only) |
| Space usage | More | Less |
| Choose when | You want visual progress bars | You want minimal terminal footprint |

## Reference

- [`docs/ACCEPTANCE_TESTS.md`](docs/ACCEPTANCE_TESTS.md) — test suite
