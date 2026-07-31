# Statusline Compact Plugin Acceptance Tests

## Purpose

Verify that `statusline-compact` renders a correct single-line statusline from the JSON Claude Code
pipes in, using only `jq` and `git` — no network, no `python3`. Tests are driven by captured
fixtures that represent real worktree and non-worktree sessions.

Each test feeds a JSON fixture (or a synthetic one) to the renderer on stdin:

```bash
cat FIXTURE.json | bash plugins/statusline-compact/scripts/statusline-compact.sh
```

ANSI codes are stripped for content assertions with:

```bash
sed $'s/\x1b\\[[0-9;]*m//g'
```

## Test Execution Order

1. Static checks (manifest, permissions, no forbidden dependencies)
2. Unit tests (helpers: humanize, model palette, ctx% thresholds, cost)
3. Integration tests (full render per fixture)
4. Git tests (branch, dirty, non-git)
5. Setup / conflict-detection tests

## Automation Status

| Category | Status |
|----------|--------|
| Static checks | ✅ automated |
| Unit tests | ✅ automated |
| Integration (fixtures) | ✅ automated |
| Git tests | ✅ automated (mktemp repo) |
| Setup / conflict detection | 🟡 partial — settings-mutation steps are scripted; the AskUserQuestion confirmation is manual |

## Test Categories

### 1. Static Checks

#### 1.1 Plugin Manifest Validation

```bash
jq empty plugins/statusline-compact/.claude-plugin/plugin.json
jq -r '.name, .version' plugins/statusline-compact/.claude-plugin/plugin.json
```

**Acceptance criteria:**
- ✅ Valid JSON
- ✅ `name` == `statusline-compact`
- ✅ `version` is semver (first release `0.1.0`)

#### 1.2 Script Permissions

```bash
test -x plugins/statusline-compact/scripts/statusline-compact.sh
test -x plugins/statusline-compact/scripts/setup-statusline-compact.sh
```

**Acceptance criteria:** ✅ both scripts executable.

#### 1.3 No Forbidden Dependencies

```bash
# Ignore comment lines; expect 0 real invocations
grep -vE '^\s*#' plugins/statusline-compact/scripts/statusline-compact.sh \
  | grep -cE 'curl|python3|python '   # expect 0
```

**Acceptance criteria:** ✅ no `curl`, no `python`/`python3`, no network calls anywhere in the renderer.

### 2. Unit Tests

#### 2.1 Context-size Humanize

Source the script's `humanize_ctx` (or exercise via synthetic stdin) and assert:

| Input | Output |
|-------|--------|
| `1000000` | `1M` |
| `200000` | `200K` |
| `128000` | `128K` |
| `1500000` | `1.5M` |
| `999` | `999` (verbatim) |
| `` (empty) | `` |

**Acceptance criteria:** ✅ suffix `K`/`M` is dimmed; ✅ a sub-1M number (`200K`, `128K`, `999`)
is wrapped in yellow `38;5;178`; ✅ a full 1M+ number (`1M`, `1.5M`) carries no color on the number.

#### 2.2 Model Palette

Feed synthetic `display_name`s and assert the SGR code wrapping each keyword:

| Model | Expected code |
|-------|---------------|
| `Opus 4.8 (1M context)` | `38;5;71` (green) |
| `Fable 5` | `38;5;167` (red) |
| `Sonnet 4.6` | `38;5;37` (cyan) |
| `Haiku 4.5` | `38;5;33` (blue) |

```bash
printf '{"model":{"display_name":"Opus 4.8 (1M context)"},"cost":{"total_cost_usd":0},"context_window":{"context_window_size":1000000,"used_percentage":50}}' \
  | bash plugins/statusline-compact/scripts/statusline-compact.sh
```

**Acceptance criteria:**
- ✅ keyword wrapped in the expected color
- ✅ version `\d+\.\d+` wrapped in `38;5;240` (dim)
- ✅ a plain space (not `･`) between the keyword and the version
- ✅ trailing ` (1M context)` trimmed

#### 2.3 Context % Thresholds

Synthetic `used_percentage` of 50 / 65 / 85:

**Acceptance criteria:**
- ✅ 50 → no color on the number
- ✅ 65 → yellow `38;5;178`
- ✅ 85 → red `38;5;167`
- ✅ `%` always dimmed

#### 2.4 Session Cost

**Acceptance criteria:**
- ✅ `2.612795…` → `$2.61`
- ✅ `0` → `$0.00` (always shown)
- ✅ `$` and `.frac` dimmed; integer part bright
- ✅ dot decimal even in a comma locale (`LC_NUMERIC=C`)

#### 2.5 Effort Palette

Feed synthetic `.effort.level` values and assert the SGR code wrapping the level word:

| Level | Expected code |
|-------|---------------|
| `low` | `38;5;33` (blue) |
| `medium` | `38;5;37` (cyan) |
| `high` | `38;5;71` (green) |
| `xhigh` | `38;5;178` (yellow) |
| `max` | `38;5;167` (red) |

**Acceptance criteria:**
- ✅ each known level wrapped in the expected color
- ✅ an unknown level renders plain (no color)
- ✅ an absent `.effort.level` omits the segment entirely

#### 2.6 Ultra-mode Effort (violet `ultra`)

When the last genuine `/effort` this session selected an ultra mode (`ultracode`/`ultraplan`), the
effort segment is **replaced** by a single violet (`38;5;135`) `ultra` token — instead of the coarse
`xhigh` level. Otherwise the normal color-coded effort level shows. Build synthetic JSONL transcripts
and point `.transcript_path` at each:

```bash
TD=$(mktemp -d)
# genuine last /effort = ultracode, with a LATER assistant line quoting "…to max" (prose trap)
printf '%s\n' \
  '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<local-command-stdout>Set effort level to ultracode (this session only): xhigh + orchestration</local-command-stdout>"}]}}' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"note: Set effort level to max — just prose"}]}}' \
  > "$TD/ultracode.jsonl"
# genuine last /effort = max, later assistant prose quotes "…to ultraplan" (the false-match bug)
printf '%s\n' \
  '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<local-command-stdout>Set effort level to max (this session only): Maximum</local-command-stdout>"}]}}' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"the grep gave Set effort level to ultraplan from prose"}]}}' \
  > "$TD/max-prose-trap.jsonl"

pay(){ printf '{"cwd":"/tmp","workspace":{"repo":{"name":"demo"}},"model":{"display_name":"Opus 4.8"},"effort":{"level":"%s"},"cost":{"total_cost_usd":1},"context_window":{"context_window_size":1000000,"used_percentage":20},"transcript_path":"%s"}' "$1" "$2"; }
S=plugins/statusline-compact/scripts/statusline-compact.sh

pay xhigh "$TD/ultracode.jsonl"     | bash "$S"   # effort segment = violet 38;5;135 "ultra" (no xhigh)
pay max   "$TD/max-prose-trap.jsonl" | bash "$S"   # effort segment = normal "max" (prose ignored)
pay high  "$TD/NOPE.jsonl"           | bash "$S"   # missing transcript → normal "high", no error
```

**Acceptance criteria:**
- ✅ last `/effort` = `ultracode`/`ultraplan` → effort segment is the single word `ultra` in violet `38;5;135` (the coarse `xhigh` is NOT shown, and there is no separate ultracode/ultraplan token)
- ✅ **prose immunity**: a later assistant message quoting `Set effort level to <word>` does NOT change the result (only `type:"user"` `/effort` echoes count)
- ✅ last `/effort` = a normal level → normal color-coded effort level shown (no `ultra`)
- ✅ no `/effort` line / missing `.transcript_path` / unreadable file → normal effort from `.effort.level`, no stderr
- ✅ the violet SGR `38;5;135` and the word `ultra` appear **only** in an ultra case
- ✅ detection is grep-narrow + `jq`-filter (binary-safe `grep -a`), ~7ms on a 2.6MB transcript

### 3. Integration Tests (fixtures)

Fixtures capture real sessions. Every fixture must produce **exactly one line** (`wc -l == 1`).

#### 3.1 Non-worktree, repo.name ≠ cwd basename

Fixture `01`: `cwd` basename is `cc-timer` but `.workspace.repo.name` is `tokenpace`.

**Acceptance criteria:**
- ✅ the line starts with repo `tokenpace` (proves `.workspace.repo.name` precedence)
- ✅ yellow `Root` badge (no `.workspace.git_worktree`), colored `38;5;178`, attached to the branch with a tight `･`
- ✅ the line == `tokenpace ･ Root･main ･ Opus･4.8･high ･ 1M･8% ･ $2.61` (badge･branch, model･version･effort and size･% are tight pairs)

#### 3.2 Fresh session, `used_percentage: null`

Fixture `02`.

**Acceptance criteria:**
- ✅ context-% segment **omitted** (no `%` in the output)
- ✅ cost shown as `$0.00`
- ✅ no placeholder gap — the line == `claude-plugins ･ Root･main ･ Opus･4.8･high ･ 1M ･ $0.00`
  (branch depends on the fixture cwd's git state; the load-bearing checks are "no `%` segment" and "`$0.00` shown")

#### 3.3 Active non-worktree

Fixture `03`.

**Acceptance criteria:** ✅ repo `claude-plugins`, yellow `Root` badge, `5%`, `$0.52`.

#### 3.4 Non-worktree with an open PR

Fixture `04` contains a `.pr` object.

**Acceptance criteria:** ✅ `.pr` does **not** leak into the output; `7%`, `$2.46`.

#### 3.5 Worktree

Fixture `05`.

**Acceptance criteria:**
- ✅ gray `Worktree` badge (`.workspace.git_worktree` present), colored `38;5;240`, attached to the branch with a tight `･` (`Worktree･<branch>`)
- ✅ repo == `claude-plugins` (NOT the worktree name — repo.name precedence in a worktree)
- ✅ the worktree name itself is NOT rendered (replaced by the fixed `Worktree` badge)
- ✅ `5%`, `$0.69`

#### 3.6 Conditional-Segment Stability

Diff the ANSI-stripped line across the worktree and non-worktree fixtures.

**Acceptance criteria:** ✅ the checkout badge is always present (gray `Worktree` vs yellow `Root`),
and genuinely-absent segments (branch) are omitted, not replaced by placeholders, so the line never jumps.

### 4. Git Tests

Run against a temporary repo (`git init` in `mktemp -d`), feeding a fixture whose `cwd` points at it.

**Acceptance criteria:**
- ✅ current branch appears in the line
- ✅ `cwd` that is not a git repo → branch segment (and its separator) omitted entirely; the checkout
  badge still shows as its own segment

#### 4.1 `[CPM]` Status Block

The `[CPM]` block follows the branch after a tight `･` (`branch･[CPM]`): **red letters**
(`38;5;167`), **gray brackets** (`38;5;240`). Each letter shows only when its condition holds; no
active letters → no block at all (no brackets, no separator). Build temporary repos to exercise each
combination.

**C / P (local, no network):**

```bash
strip(){ sed $'s/\x1b\\[[0-9;]*m//g'; }
S=plugins/statusline-compact/scripts/statusline-compact.sh
pay(){ printf '{"cwd":"%s","workspace":{"repo":{"name":"demo"}},"model":{"display_name":"Opus 4.8"},"cost":{"total_cost_usd":0},"context_window":{"context_window_size":1000000,"used_percentage":10}}' "$1"; }

TD=$(mktemp -d)
# clean, no upstream, HEAD carries a commit on no remote → P
R1="$TD/r1"; git -C "$R1" init -q 2>/dev/null || { mkdir -p "$R1"; git -C "$R1" init -q; }
git -C "$R1" config user.email t@t; git -C "$R1" config user.name t
echo a > "$R1/a"; git -C "$R1" add -A; git -C "$R1" commit -qm init
pay "$R1" | bash "$S" | strip           # expect [P]
echo b >> "$R1/a"
pay "$R1" | bash "$S" | strip           # expect [CP]

# pushed & clean via a bare remote → no block
BARE="$TD/bare.git"; git init -q --bare "$BARE"
R2="$TD/r2"; git clone -q "$BARE" "$R2"
git -C "$R2" config user.email t@t; git -C "$R2" config user.name t
echo x > "$R2/x"; git -C "$R2" add -A; git -C "$R2" commit -qm init
git -C "$R2" push -q -u origin HEAD
pay "$R2" | bash "$S" | strip           # expect NO block
echo y > "$R2/y"; git -C "$R2" add -A; git -C "$R2" commit -qm second
pay "$R2" | bash "$S" | strip           # expect [P] (1 commit ahead)

# pushed → PR merged → remote branch deleted (upstream CONFIG stays, tracking ref gone) → no block.
# This is the normal end-of-feature state (`gh pr merge --squash --delete-branch`); the local HEAD is
# the squash source, already in main, so there is nothing to push. `@{upstream}` now points at a gone
# ref and `rev-list` fails — but `branch.<name>.remote` config still exists, so it is NOT "never pushed".
git -C "$R2" checkout -q -b feature/gone
echo z > "$R2/z"; git -C "$R2" add -A; git -C "$R2" commit -qm feat
git -C "$R2" push -q -u origin feature/gone
git -C "$R2" push -q origin --delete feature/gone
git -C "$R2" update-ref -d refs/remotes/origin/feature/gone   # simulate the tracking ref being pruned
pay "$R2" | bash "$S" | strip           # expect NO block (branch is merged+deleted, not unpushed)

# fresh branch cut off origin/main with NO own commits → no block (#358). This is the
# `git worktree add` / `EnterWorktree` case: local main may be behind origin, so HEAD is
# "ahead of local main" yet every one of its commits is already on origin → nothing to push.
# `--no-track` gives a TRUE State 1 (no `branch.<name>.remote` config at all), like EnterWorktree.
git -C "$R2" checkout -q -b feature/fresh --no-track origin/main
pay "$R2" | bash "$S" | strip           # expect NO block (rev-list HEAD --not --remotes == 0)
echo w > "$R2/w"; git -C "$R2" add -A; git -C "$R2" commit -qm own
pay "$R2" | bash "$S" | strip           # expect [P] (first own commit not on any remote)
```

**Acceptance criteria (C / P):**
- ✅ clean + no upstream, HEAD carries a commit on no remote → `[P]`
- ✅ + uncommitted change → `[CP]`
- ✅ pushed & clean → **no block** (no brackets)
- ✅ 1 commit ahead of upstream → `[P]`
- ✅ pushed → merged → remote branch deleted (upstream config stays, tracking ref gone) → **no block**
  (regression: #353 — the two empty-`rev-list` states, "never pushed" vs "pushed-then-deleted", are
  told apart by whether `branch.<name>.remote` config exists — present ⇒ not unpushed)
- ✅ fresh branch off `origin/main` with **no own commits** (worktree / `EnterWorktree` case,
  local main behind) → **no block** — no `P` (#358). In State 1 (no upstream config) `P` now
  fires only when `rev-list --count HEAD --not --remotes > 0`; a first own commit on top → `[P]`
- ✅ uncommitted change on a merged+deleted branch → `[C]` only (never `[CP]`)
- ✅ letters are `38;5;167` (red); brackets are `38;5;240` (gray)

**M (gated + cache-driven, never blocks the render):** `M` has two **separate** purely-local gates,
deliberately distinct:

1. **Protected branches** (`main` / `master` / `develop`) never carry a feature PR → no `M`, and `gh`
   is never invoked for them regardless of what the cache holds.
2. **Whether `gh` may REFRESH the cache** is gated on the branch being *fully pushed* (has an upstream
   *and* no unpushed commits). The **display** of an already-known state is NOT gated on this: a branch
   with an upstream serves whatever the cache knows even with unpushed commits on top — so an existing
   (draft) PR keeps `M` lit after you add a local commit. The unpushed state blocks the *network
   refresh*, not the *display*. A branch with **no upstream** was never on the remote, so no PR could
   target it that we haven't already seen → no `M` at all.

Once display engages, the render only *reads* the cache file at
`~/.claude/.statusline-compact-pr-cache/<repo>-<branch-slug>` (line format `<state> <unix-epoch>`,
states: `merged` / `unmerged` / `none`); a detached background `gh` refreshes it when the refresh gate
is open. Seed the cache directly to test each state (repo needs an `origin` remote and a pushed branch
that is NOT `main`/`master`/`develop` for M to engage):

```bash
CACHE="$HOME/.claude/.statusline-compact-pr-cache"; mkdir -p "$CACHE"
# M only engages off protected branches, so move R2 onto a feature branch first.
# R2 has origin "bare"; branch "feature/x" → slug "bare-feature_x"
git -C "$R2" checkout -q -b feature/x; git -C "$R2" push -q -u origin feature/x
cf="$CACHE/bare-feature_x"; now=$(date +%s)
printf 'unmerged %s\n' "$now" > "$cf"; pay "$R2" | bash "$S" | strip   # expect [M] (P clean)
printf 'merged %s\n'   "$now" > "$cf"; pay "$R2" | bash "$S" | strip   # expect NO block (terminal)
printf 'none %s\n'     "$now" > "$cf"; pay "$R2" | bash "$S" | strip   # expect NO block
```

**Acceptance criteria (M):**
- ✅ cache `unmerged` (fresh) → `[M]`
- ✅ cache `merged` → **no block** (merged is terminal; never re-checked, never `gh`-called again)
- ✅ cache `none` → **no block**
- ✅ cache `unmerged` **stale** (old epoch) → still serves `[M]` from cache *and* triggers a detached
  background refresh (the render does not wait for it)
- ✅ **render never blocks**: with a slow `gh` shim on `PATH` (`sleep 3; echo OPEN`) and a stale cache,
  render wall-time is well under 1s (measured ~0.16s), i.e. the background `gh` never blocks the render
- ✅ no `origin` remote, or `gh` absent → no `M` letter, no error
- ✅ background refresh: after a stale non-terminal cache, a fast `gh` shim returning `OPEN` rewrites
  the cache to `unmerged`; returning `MERGED` rewrites to `merged`; `CLOSED`/no-PR → `none`

**Acceptance criteria (M gates — purely local, no `gh`):** two observable behaviours — whether `M`
*displays*, and whether the background `gh` *refresh* fires (proven by whether a seeded stale cache is
left **untouched** or **rewritten**). Seed the cache with a bogus stale sentinel
(`printf 'SENTINEL 111' > "$cf"`) or a fresh `unmerged`, render, wait ~1s, then diff:
- ✅ **protected branch** (`main`/`master`/`develop`) → **no `M`** even with a fresh `unmerged` cache;
  cache untouched (no background `gh` ran)
- ✅ **no upstream** (never pushed) → no `M`; cache untouched; block shows `[P]` (even if the seeded
  cache said `unmerged`) — a never-pushed branch had no PR target we could have missed
- ✅ **upstream + unpushed commit, cache `unmerged`** → block shows **`[PM]`** — `M` served from cache
  (an existing draft/open PR stays flagged), but the cache is left **untouched** (no background `gh`)
- ✅ **upstream + unpushed commit, cache `none`/absent** → block shows `[P]`, never `[M]`; cache
  untouched (unpushed blocks the refresh, so a stale/missing entry is not re-queried)
- ✅ **upstream + fully pushed & clean** → cache **rewritten** by the background `gh` (refresh gate open)
- ✅ **pushed → merged → remote branch deleted** (tracking ref gone, config stays) → no `M`; cache
  untouched — `rev-list @{upstream}..HEAD` fails so `has_upstream` stays unset, closing the refresh
  gate. No `gh` is called for a branch whose remote is gone (and P is already suppressed, see above)
- ✅ the gates are git-only (branch-name check + `@{upstream}` resolves + `rev-list @{upstream}..HEAD`);
  they fire no network call by themselves

### 5. Setup / Conflict Detection

Exercise `/statusline-compact:statusline-compact-setup` logic against three `settings.json` states:

| State | Expected |
|-------|----------|
| No `.statusLine` | Set to `~/.claude/statusline-compact.sh`; other keys preserved |
| `.statusLine.command == ~/.claude/statusline.sh` | Detected as the `statusline` plugin; requires explicit confirmation before overwrite |
| `.statusLine.command == ~/.claude/statusline-compact.sh` | Left intact (idempotent); other keys preserved |

**Acceptance criteria:**
- ✅ never overwrites a conflicting command without confirmation
- ✅ preserves all unrelated `settings.json` keys
- ✅ SessionStart copier writes `~/.claude/statusline-compact.sh` and never touches `~/.claude/statusline.sh`

## Known Limitations

- The checkout badge relies on `.workspace.git_worktree`, which Claude Code only supplies for
  worktree sessions; a manually-created worktree opened without that field would show the yellow `Root`
  badge instead of gray `Worktree` (the branch still renders from local `git`).
- The AskUserQuestion confirmation in the setup flow is interactive and cannot be fully automated.
- The `M` letter is eventually-consistent: it reflects the last background `gh` refresh, so it can lag
  a just-opened or just-merged PR by up to the 5-minute TTL (a merged result then sticks permanently).
  This is deliberate — it keeps the render off the network's critical path.

## Version History

| Version | Change |
|---------|--------|
| 0.1.0 | Initial release — single-line renderer, SessionStart copier, setup command with conflict detection |
| 0.2.0 | Pink `ultracode`/`ultraplan` ultra-mode marker — detected from the session transcript's last `/effort` command (prose-immune via `type:"user"` filter) |
| 0.2.1 | Ultra marker recolored to blue-violet (`38;5;135`); collapsed to a single `ultra` token |
| 0.2.2 | Model palette recolor (Opus=green, Fable=red, Sonnet=cyan, Haiku=blue); sub-1M context size number flagged yellow |
| 0.3.0 | Checkout badge replaces the worktree name — green `Worktree` in a worktree, gray `Root` in the main checkout |
| 0.3.1 | Swap checkout-badge colors (gray `Worktree`, yellow `Root`); attach the badge tightly to the branch (`badge･branch`) instead of the repo |
| 0.4.0 | `[CPM]` status block after the branch (red letters, gray brackets): **C** uncommitted, **P** unpushed, **M** PR-not-merged. C/P local-only; M is **gated on a local signal** (only checked once the branch is pushed & clean — no `gh` before that) and then cache-driven with a detached background `gh` refresh (7-min TTL, merged cached permanently), so the render never blocks on the network. Replaces the old dirty `!`. |
| 0.4.1 | Shorten the M-cache TTL from 7 min to 5 min so a newly-opened/closed PR is reflected sooner |
| 0.4.2 | Docs: README `[CPM]` lifecycle demo walking one terminal through `[C]`→`[P]`→`[M]` |
| 0.5.0 | `M` now stays lit for an existing (draft/open) PR after you add a local commit on top — the unpushed-commit gate blocks the background `gh` *refresh*, no longer the *display* of an already-known `unmerged` (so `[PM]` is now possible). Protected branches (`main`/`master`/`develop`) are skipped entirely: no `M`, no `gh`. |
| 0.5.1 | Fix false `P` after a merged branch's remote is deleted (#353): a pushed→merged→deleted branch keeps its `branch.<name>.remote` config, so `rev-list @{upstream}..HEAD` fails on a gone tracking ref just like a never-pushed branch — the two are now told apart by that config (present ⇒ not unpushed ⇒ no `P`, and the `M` refresh gate stays closed). |
| 0.6.1 | Fix false `P` on a fresh no-upstream branch cut off `origin/main` with no own commits (#358): in State 1 (no `branch.<name>.remote` config) `P` now fires only when `rev-list --count HEAD --not --remotes > 0` — a `git worktree add` / `EnterWorktree` branch whose commits are all already on origin no longer flags `P`; the first own commit on top restores it. Purely local check, no network. |
