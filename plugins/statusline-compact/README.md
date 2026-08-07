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
claude-plugins   Root･main   Opus･4.8･high   1M･5%   $0.52
```

Inside a git worktree there is no badge — the branch itself reads `worktree-<name>`, with the
`worktree-` head and the `+` dimmed (`[CP]` = uncommitted changes + unpushed commits):

```markdown
claude-plugins   worktree-feature+statusline-compact･[CP]   Opus･4.8･high   1M･5%   $0.69
```

In an ultra effort mode, the effort level is replaced by a single violet `ultra` token:

```markdown
claude-plugins   Root･main   Opus･4.8･ultra   1M･5%   $0.52
```

### The `[CPM]` block over one feature's lifecycle

> **`M` is disabled by default.** The `M` letter is the only part that shells out to `gh`, and
> it's temporarily off while we measure `gh` load across cases (it's under suspicion of
> overloading `gh`). `C` and `P` work unchanged. To opt back in — e.g. to take measurements —
> set `STATUSLINE_COMPACT_ENABLE_PR_CHECK=1` in the environment the statusline runs in. The
> examples below show the full `[CPM]` behaviour as it works with `M` enabled.

Watch the same terminal as you take a change from edit to merge — the block flips through
`[C]` → `[P]` → `[M]` and then disappears. Each letter is red, the brackets gray; the whole block
(and its `･`) is omitted the moment nothing applies.

```markdown
# 1. you edit a file — uncommitted work → C
claude-plugins   worktree-feature+login･[C]   Opus･4.8･high   1M･12%   $0.30

# 2. you commit locally — C clears, but the commit isn't on the remote yet → P
claude-plugins   worktree-feature+login･[P]   Opus･4.8･high   1M･14%   $0.41

# 3. you push — nothing is out of sync, so the block vanishes for a moment
claude-plugins   worktree-feature+login   Opus･4.8･high   1M･15%   $0.48

# 4. you open a PR — the branch is pushed & clean, so M is now checked (background gh);
#    the open PR isn't merged yet → M
claude-plugins   worktree-feature+login･[M]   Opus･4.8･high   1M･18%   $0.55

# 4b. you commit a fixup on top — not pushed yet → P, but the PR is still open → M stays → PM
claude-plugins   worktree-feature+login･[PM]   Opus･4.8･high   1M･19%   $0.58

# 5. the PR merges — M clears (a merged result is cached permanently); block gone
claude-plugins   worktree-feature+login   Opus･4.8･high   1M･20%   $0.61
```

If you commit *without* pushing while a change is still uncommitted, letters stack — e.g. `[CP]`.
`M` first lights up only once the branch is fully pushed (step 4 onward): before there's a remote
branch, `gh` isn't called and `P` already tells you the branch isn't pushed. But once a PR exists and
`M` is known, adding a local commit on top keeps `M` lit alongside `P` — you'll see `[PM]`. Protected
branches (`main`/`master`/`develop`) never show `M`.

Segments, left to right: repo name · the git branch, preceded by a yellow `Root` badge in the main
checkout (a worktree needs none — its branch says so itself) · a `[CPM]` status block (red letters,
gray brackets) · model · effort (or `ultra` in an ultra mode) · context-window size · context used %
· session cost.

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
- **Checkout badge** — a yellow **`Root`** marker in the main checkout, attached to the **branch**
  with a tight `･` (`Root･main`). A worktree session normally shows **no badge**: its branch is
  already named `worktree-<name>`, so a badge would only repeat it. The gray **`Worktree`** badge
  does return in one case — a worktree whose checked-out branch is *not* named `worktree-…` (you
  switched branches inside it), where nothing else on the line would reveal it's a worktree. Keyed
  off the presence of `.workspace.git_worktree` (set only in worktree sessions). Outside a git repo
  (no branch) the badge stands alone as its own segment.
- **Branch** — the real checked-out branch (`git branch --show-current`); the prefix token is
  color-coded (`feature`, `fix`, `release`, `refactor`, …) and the delimiter dimmed. Two layouts,
  same colors: a normal branch splits on `/` (`feature/login`), while a worktree branch splits on
  `+` and gets its literal `worktree-` head dimmed too — `worktree-fix+stub-fallback-267` renders as
  dim `worktree-`, red `fix`, dim `+`, plain `stub-fallback-267`. (Claude Code names a worktree
  branch `worktree-<worktree name>` and slugifies the name's `/` into `+`.) A worktree branch with
  no `+` — `worktree-experiments` — gets the dim head and nothing else; there is no prefix token to
  classify. The `+` split applies *only* to a real `worktree-…` branch in a worktree session, so a
  branch that merely contains a `+` (`feature/a+b`) is unaffected.
- **`[CPM]` status block** — follows the branch after a tight `･`, with **red letters** and **gray
  brackets**. Each letter shows only when its condition holds; if none hold, the whole block
  (brackets included, and its separator) is omitted:
  - **`C`** — local **c**hanges not committed (uncommitted work in the tree).
  - **`P`** — local commits not **p**ushed (commits ahead of the upstream, or a never-pushed branch
    that carries commits absent from every remote). A branch whose PR merged and whose remote branch
    was then deleted is **not** flagged — its work is already in `main`, so there is nothing to push.
    Nor is a fresh branch cut off `origin/main` with no own commits (the `git worktree add` /
    `EnterWorktree` case, even when local `main` lags origin) — those commits are already on origin.
  - **`M`** — an open PR that is not **m**erged yet. No PR → no `M` (an un-PR'd branch is already
    flagged by `P`). **Disabled by default** (set `STATUSLINE_COMPACT_ENABLE_PR_CHECK=1` to enable)
    while `gh` load is being measured — it's the only letter that invokes `gh`; the rest of this
    subsection describes the behaviour when it's enabled.

  `C` and `P` are computed from local `git` only (no network). `M` has two **purely-local** gates,
  deliberately kept separate:
  - Protected branches (`main`/`master`/`develop`) never carry a feature PR → no `M`, and `gh` is
    never called for them.
  - Whether `gh` may **refresh** the cache is gated on the branch being fully pushed (an upstream
    *and* no unpushed commits, both read from local refs) — until it's on the remote there's no PR
    target we could have missed. But the **display** of an already-known `M` is *not* gated on this:
    once a (draft or open) PR is in the cache, `M` stays lit even after you add a local commit on
    top, so `[PM]` is possible. The unpushed state blocks the network refresh, not the display.

  `M` is resolved from a tiny per-branch **cache file** that the render only *reads* — a detached
  background `gh` refreshes it (when the refresh gate is open), so the render **never blocks on the
  network**. A *merged* result is cached permanently (a merged PR never un-merges); an *open* or
  *no-PR* result is re-checked when the cache entry is older than 5 minutes. Requires `gh` for the
  `M` letter only; without `gh`, `C` and `P` still work.
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
share a spaceless `･` separator to read as one unit — `Root･main･[CPM]`, `Opus･4.8･high`, and
`1M･5%` — while the top-level segments are separated by three plain spaces, so the gap between
widgets never reads as one of those pairs.

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add artem-from-ua/claude-plugins
/plugin install statusline-compact@artem-from-ua
```

Select **statusline-compact** in `/plugin` → enable **auto-update**.

**Requirements:** `jq`, `git`. No `curl`, no `python3`. The render itself makes **no network calls**.
The only optional network use is the `M` letter's detached background `gh` refresh — and that is
**disabled by default** while `gh` load is being measured (opt in with
`STATUSLINE_COMPACT_ENABLE_PR_CHECK=1`). Even when enabled it runs disconnected from the render (see
the `[CPM]` block above); without `gh`, or with `M` disabled, everything else works.

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
