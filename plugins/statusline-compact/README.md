# statusline-compact

> [!TIP]
> ✨ ***A minimal single-line statusline — repo, branch, model, context, and cost at a glance. No network, just `jq` and `git`.***

A lightweight sibling of the [`statusline`](../statusline/README.md) plugin: one line rendered
entirely from the JSON Claude Code already pipes in, plus local `git`. No API calls, no `python3`,
no progress bars.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [🎨 Layout](#layout) · [📦 Installation](#installation) · [🔧 Setup](#setup) · [📚 Reference](#reference)

## 🎬 Demo <a name="demo"></a>

Outside a worktree:

```markdown
claude-plugins ･ main ･ Opus･4.8･high ･ 1M･5% ･ $0.52
```

Inside a git worktree (with uncommitted changes):

```markdown
claude-plugins･feature+statusline-compact ･ feature/statusline-compact･! ･ Opus･4.8･high ･ 1M･5% ･ $0.69
```

In an ultra effort mode, a blue-violet `ultracode` (or `ultraplan` in plan mode) marker follows the effort:

```markdown
claude-plugins ･ main ･ Opus･4.8･xhigh ･ ultracode ･ 1M･5% ･ $0.52
```

Segments, left to right: repo name · worktree name (worktrees only) · git branch (red `!` when
dirty) · model · effort · ultra marker (only in an ultra mode) · context-window size ·
context used % · session cost.

## ⚙️ How it works <a name="how-it-works"></a>

| Trigger | What happens |
|---------|-------------|
| SessionStart | Installs `statusline-compact.sh` to `~/.claude/` |
| Every prompt | Renders a single line from stdin JSON + local `git` — no network |

Every value comes straight from the JSON Claude Code pipes to the statusline command
(`.workspace.repo.name`, `.workspace.git_worktree`, `.model.display_name`, `.effort.level`,
`.context_window.*`, `.cost.total_cost_usd`); the git branch and dirty flag are read locally. The
ultra marker additionally scans the session transcript (`.transcript_path`) for the last `/effort`
command — still no network, just a fast grep + `jq` over the local JSONL file.
There are **no** network requests and **no** `python3` dependency — a deliberate contrast with the
full three-line `statusline` plugin.

## 🎨 Layout <a name="layout"></a>

- **Repo name** — from `.workspace.repo.name` (falls back to the project directory / cwd basename).
  Correct even inside a worktree, where the project directory points at the worktree, not the repo root.
- **Worktree name** — shown (dimmed) only in a git worktree, from `.workspace.git_worktree`.
- **Branch** — the real checked-out branch (`git branch --show-current`); prefix color-coded
  (`feature`, `fix`, `release`, `refactor`, …), slash dimmed. A red `!` is appended when the tree is dirty.
- **Model** — color-coded: **Fable = red, Opus = yellow, Sonnet = green, Haiku = cyan**; version dimmed;
  the trailing ` (… context)` is trimmed since context size is shown separately.
- **Effort** — `.effort.level`, color-coded along a low→max gradient:
  **low = blue, medium = cyan, high = green, xhigh = yellow, max = red** (hidden when absent).
- **Ultra mode** — a **blue-violet** `ultracode` / `ultraplan` marker, shown right after effort when the
  most recent `/effort` this session selected an ultra mode. These are one effort slot renamed by
  permission mode (normal → `ultracode`, plan → `ultraplan`), so exactly one ever shows. The
  `.effort` field and the statusline payload only carry the coarse level (ultra maps to `xhigh`), so
  the marker is detected by scanning the session transcript (`.transcript_path`) for the last
  genuine `/effort` command — filtered by record type, so our own chat mentions of the phrase don't
  trigger a false positive. Omitted when the last `/effort` was a normal level or no transcript is
  available.
- **Context size** — `1000000 → 1M`, `200000 → 200K`.
- **Context used %** — yellow ≥ 60%, red ≥ 80% (hidden when unavailable, e.g. a fresh session).
- **Session cost** — always shown, even `$0.00`.

Absent segments are omitted entirely, so the line never shifts position. Tightly-related pairs
share a spaceless `･` separator to read as one unit — repo`･`worktree, branch`･`dirty-`!`,
model`･`version`･`effort, and context-size`･`used-% — while the top-level segments are joined by a
spaced ` ･ `.

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add artem-from-ua/claude-plugins
/plugin install statusline-compact@artem-from-ua
```

Select **statusline-compact** in `/plugin` → enable **auto-update**.

**Requirements:** `jq`, `git`. No `curl`, no `python3`, no network access.

## 🔧 Setup <a name="setup"></a>

```bash
/statusline-compact:statusline-compact-setup
```

The wizard:
- **Copies** `statusline-compact.sh` to `~/.claude/`
- **Configures** the `statusLine` field in `~/.claude/settings.json`
- **Detects conflicts** — if another statusline (e.g. the `statusline` plugin) is already wired in,
  it reports the likely owner and asks before overwriting
- **Verifies** `jq` and `git` are available

Restart your session after setup. To switch back to the full three-line statusline, run
`/statusline:statusline-setup`.

## 📚 Reference <a name="reference"></a>

- [`docs/ACCEPTANCE_TESTS.md`](docs/ACCEPTANCE_TESTS.md) — test suite
- [`docs/STDIN_JSON.md`](docs/STDIN_JSON.md) — the JSON fields consumed from Claude Code's stdin
