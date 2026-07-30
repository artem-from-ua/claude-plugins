# statusline-compact

> [!TIP]
> ✨ ***A minimal single-line statusline — repo, branch, model, context, and cost at a glance. No network, just `jq` and `git`.***

A lightweight sibling of the [`statusline`](../statusline/README.md) plugin: one line rendered
entirely from the JSON Claude Code already pipes in, plus local `git`. No API calls, no `python3`,
no progress bars.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [🎨 Layout](#layout) · [📦 Installation](#installation) · [🔧 Setup](#setup) · [📚 Reference](#reference)

## 🎬 Demo <a name="demo"></a>

In the main checkout (yellow `Root` badge, attached to the branch):

```markdown
claude-plugins ･ Root･main ･ Opus･4.8･high ･ 1M･5% ･ $0.52
```

Inside a git worktree (gray `Worktree` badge, with uncommitted changes):

```markdown
claude-plugins ･ Worktree･feature/statusline-compact･! ･ Opus･4.8･high ･ 1M･5% ･ $0.69
```

In an ultra effort mode, the effort level is replaced by a single violet `ultra` token:

```markdown
claude-plugins ･ Root･main ･ Opus･4.8･ultra ･ 1M･5% ･ $0.52
```

Segments, left to right: repo name · checkout badge (gray `Worktree` / yellow `Root`) attached to the
git branch (red `!` when dirty) · model · effort (or `ultra` in an ultra mode) · context-window size ·
context used % · session cost.

## ⚙️ How it works <a name="how-it-works"></a>

| Trigger | What happens |
|---------|-------------|
| SessionStart | Installs `statusline-compact.sh` to `~/.claude/` |
| Every prompt | Renders a single line from stdin JSON + local `git` — no network |

Every value comes straight from the JSON Claude Code pipes to the statusline command
(`.workspace.repo.name`, `.workspace.git_worktree`, `.model.display_name`, `.effort.level`,
`.context_window.*`, `.cost.total_cost_usd`); the git branch and dirty flag are read locally. The
ultra detection additionally scans the session transcript (`.transcript_path`) for the last `/effort`
command — still no network, just a fast grep + `jq` over the local JSONL file.
There are **no** network requests and **no** `python3` dependency — a deliberate contrast with the
full three-line `statusline` plugin.

## 🎨 Layout <a name="layout"></a>

- **Repo name** — from `.workspace.repo.name` (falls back to the project directory / cwd basename).
  Correct even inside a worktree, where the project directory points at the worktree, not the repo root.
- **Checkout badge** — a fixed marker showing which kind of checkout the session is in, attached to
  the **branch** with a tight `･` (badge`･`branch): gray **`Worktree`** in a git worktree, yellow
  **`Root`** in the main checkout. Keyed off the presence of `.workspace.git_worktree` (set only in
  worktree sessions). Outside a git repo (no branch) the badge stands alone as its own segment.
- **Branch** — the real checked-out branch (`git branch --show-current`); prefix color-coded
  (`feature`, `fix`, `release`, `refactor`, …), slash dimmed. A red `!` is appended when the tree is dirty.
- **Model** — color-coded: **Opus = green, Fable = red, Sonnet = cyan, Haiku = blue**; version dimmed;
  the trailing ` (… context)` is trimmed since context size is shown separately.
- **Effort** — `.effort.level`, color-coded along a low→max gradient:
  **low = blue, medium = cyan, high = green, xhigh = yellow, max = red** (hidden when absent).
  In an **ultra mode** the effort level is replaced by a single **violet** `ultra` token. Ultra
  (ultracode in normal mode, ultraplan in plan mode) is one effort slot that the `.effort` field and
  statusline payload only report as the coarse `xhigh`; the real ultra state lives only in the
  session transcript, so it is detected by scanning `.transcript_path` for the last genuine `/effort`
  command — filtered by record type, so our own chat mentions of the phrase don't trigger a false
  positive. Falls back to the normal effort level when the last `/effort` was a normal level or no
  transcript is available.
- **Context size** — `1000000 → 1M`, `200000 → 200K`. The number is **yellow** for any window
  below 1M (a reduced context) and left in the terminal default at a full 1M+; the `K`/`M` suffix is dimmed.
- **Context used %** — yellow ≥ 60%, red ≥ 80% (hidden when unavailable, e.g. a fresh session).
- **Session cost** — always shown, even `$0.00`.

Absent segments are omitted entirely, so the line never shifts position. Tightly-related pairs
share a spaceless `･` separator to read as one unit — badge`･`branch`･`dirty-`!`,
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
