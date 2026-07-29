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

**Acceptance criteria:** ✅ suffix `K`/`M` is dimmed; the number is bright.

#### 2.2 Model Palette

Feed synthetic `display_name`s and assert the SGR code wrapping each keyword:

| Model | Expected code |
|-------|---------------|
| `Fable 5` | `38;5;167` (red) |
| `Opus 4.8 (1M context)` | `38;5;178` (yellow) |
| `Sonnet 4.6` | `38;5;71` (green) |
| `Haiku 4.5` | `38;5;37` (cyan) |

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

#### 2.6 Ultra-mode Segment (pink `ultracode`/`ultraplan`)

The renderer scans `.transcript_path` for the last genuine `/effort` command and, if it selected an
ultra mode, appends a pink (`38;5;205`) `ultracode`/`ultraplan` segment right after effort. Build
synthetic JSONL transcripts and point `.transcript_path` at each:

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

pay xhigh "$TD/ultracode.jsonl"     | bash "$S"   # expect pink 38;5;205 "ultracode"
pay max   "$TD/max-prose-trap.jsonl" | bash "$S"   # expect NO ultra segment (prose ignored)
pay high  "$TD/NOPE.jsonl"           | bash "$S"   # missing transcript → no segment, no error
```

**Acceptance criteria:**
- ✅ last `/effort` = `ultracode`/`ultraplan` → pink `38;5;205` segment with that exact word, right after effort
- ✅ **prose immunity**: a later assistant message quoting `Set effort level to <word>` does NOT change the result (only `type:"user"` `/effort` echoes count)
- ✅ last `/effort` = a normal level → ultra segment omitted (the normal effort segment still shows)
- ✅ no `/effort` line / missing `.transcript_path` / unreadable file → segment omitted, no stderr
- ✅ the pink SGR `38;5;205` appears **only** in an ultra case
- ✅ detection is grep-narrow + `jq`-filter (binary-safe `grep -a`), ~7ms on a 2.6MB transcript

### 3. Integration Tests (fixtures)

Fixtures capture real sessions. Every fixture must produce **exactly one line** (`wc -l == 1`).

#### 3.1 Non-worktree, repo.name ≠ cwd basename

Fixture `01`: `cwd` basename is `cc-timer` but `.workspace.repo.name` is `tokenpace`.

**Acceptance criteria:**
- ✅ the line starts with repo `tokenpace` (proves `.workspace.repo.name` precedence)
- ✅ no worktree segment
- ✅ the line == `tokenpace · main · Opus 4.8 · high · 1M · 8% · $2.61`

#### 3.2 Fresh session, `used_percentage: null`

Fixture `02`.

**Acceptance criteria:**
- ✅ context-% segment **omitted** (no `%` in the output)
- ✅ cost shown as `$0.00`
- ✅ no placeholder gap — the line == `claude-plugins · main · Opus 4.8 · high · 1M · $0.00`
  (branch depends on the fixture cwd's git state; the load-bearing checks are "no `%` segment" and "`$0.00` shown")

#### 3.3 Active non-worktree

Fixture `03`.

**Acceptance criteria:** ✅ repo `claude-plugins`, no worktree segment, `5%`, `$0.52`.

#### 3.4 Non-worktree with an open PR

Fixture `04` contains a `.pr` object.

**Acceptance criteria:** ✅ `.pr` does **not** leak into the output; `7%`, `$2.46`.

#### 3.5 Worktree

Fixture `05`.

**Acceptance criteria:**
- ✅ the line contains the worktree name `feature+statusline-compact` (from `.workspace.git_worktree`)
- ✅ repo == `claude-plugins` (NOT `feature+statusline-compact` — repo.name precedence in a worktree)
- ✅ `5%`, `$0.69`

#### 3.6 Conditional-Segment Stability

Diff the ANSI-stripped line across the worktree and non-worktree fixtures.

**Acceptance criteria:** ✅ absent segments (worktree name, branch) are omitted, not replaced by
placeholders, so the line never jumps.

### 4. Git Tests

Run against a temporary repo (`git init` in `mktemp -d`), feeding a fixture whose `cwd` points at it.

**Acceptance criteria:**
- ✅ current branch appears in the line
- ✅ dirty working tree → trailing `!` colored `38;5;167`
- ✅ clean working tree → no `!`
- ✅ `cwd` that is not a git repo → branch segment (and its separator) omitted entirely

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

- The worktree segment relies on `.workspace.git_worktree`, which Claude Code only supplies for
  worktree sessions; a manually-created worktree opened without that field would show no worktree
  name (the branch still renders from local `git`).
- The AskUserQuestion confirmation in the setup flow is interactive and cannot be fully automated.

## Version History

| Version | Change |
|---------|--------|
| 0.1.0 | Initial release — single-line renderer, SessionStart copier, setup command with conflict detection |
| 0.2.0 | Pink `ultracode`/`ultraplan` ultra-mode marker — detected from the session transcript's last `/effort` command (prose-immune via `type:"user"` filter) |
