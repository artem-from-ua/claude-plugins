#!/bin/bash
# Claude Code compact statusline (SINGLE-LINE LAYOUT)
# Reads JSON from stdin (piped by Claude Code). Dependencies: jq, git.
# No network calls, no python3 — uses only stdin fields plus local git.
#
# Layout (one line, top-level segments joined with three spaces):
#   repo-name   [badge･]branch[･CPM]   model･effort   ctx-size･ctx-used%   $cost
#   (checkout badge: yellow "Root" in the main checkout, attached to the branch
#    with a tight "･". A worktree shows no badge — its branch already reads
#    "worktree-<name>" — unless you switched to a branch not named that way, in
#    which case a gray "Worktree" badge returns.)
#
# Highlighting conventions (shared with the statusline plugin):
#   separators   -> very_dim (237)
#   units/punct  -> dim (242): % $ / .frac K/M brackets
#   token        -> bright/colored: repo, branch, numbers, model keyword

# Force a dot decimal separator so awk "%.2f" is stable in comma locales.
export LC_NUMERIC=C

input=$(cat)

# ANSI colors
rst=$(printf '\033[0m')
dim=$(printf '\033[38;5;240m')
very_dim=$(printf '\033[38;5;237m')
bright_green=$(printf '\033[38;5;71m')
bright_red=$(printf '\033[38;5;167m')
yellow=$(printf '\033[38;5;178m')
ultra_color=$(printf '\033[38;5;135m') # ultracode/ultraplan marker — violet, distinct from 167/178

# Separator between the two halves of a tight pair — U+FF65 halfwidth middle dot,
# very_dim (Root･main, Opus･5･high, 1M･18%, branch･[CPM]).
SEP="${very_dim}･${rst}"
# Separator between top-level segments — three plain spaces. Whitespace needs no
# SGR, so this carries none and leaves no color state open.
WIDE_SEP="   "

# ---------------------------------------------------------------------------
# Field extraction. `// empty` also turns JSON null into "", so [ -z ] guards
# work for fields like context_window.used_percentage that can be null.
# ---------------------------------------------------------------------------
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // .workspace.project_dir // empty')

# repo-name: prefer .workspace.repo.name (correct even inside a worktree, where
# project_dir points at the worktree dir, not the repo root), then basenames.
repo_name=$(echo "$input" | jq -r '.workspace.repo.name // empty')
if [ -z "$repo_name" ]; then
  proj_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
  [ -n "$proj_dir" ] && repo_name=$(basename "$proj_dir")
fi
[ -z "$repo_name" ] && [ -n "$cwd" ] && repo_name=$(basename "$cwd")

# worktree-name: present only in worktree sessions
worktree=$(echo "$input" | jq -r '.workspace.git_worktree // empty')

model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')

# ---------------------------------------------------------------------------
# M-letter (PR-not-merged) cache. The render must never block on the network,
# so it only ever READS a small per-repo/per-branch cache file; a detached
# background `gh` refreshes it. Two cache states matter:
#
#   merged     terminal — a merged PR never un-merges, so once we learn a branch
#              is merged we cache it forever and never call gh for it again.
#   unmerged   an open PR exists but is not merged yet; re-checked when the
#              cache entry is older than PR_CACHE_TTL (5 min).
#
# A branch with NO PR is cached as "none" (also TTL'd) and yields no M letter —
# an un-PR'd branch is already flagged by P.
#
# Cache file: ~/.claude/.statusline-compact-pr-cache/<repo>-<branch-slug>
# Line format: "<state> <unix-epoch-written>". We avoid Date/clock builtins that
# aren't available and use `date +%s` (always present on macOS/Linux).
PR_CACHE_TTL=300  # 5 minutes, in seconds
PR_CACHE_DIR="$HOME/.claude/.statusline-compact-pr-cache"

# Compute the cache file path for a repo+branch. Slugifies unsafe chars.
pr_cache_file() {
  local repo="$1" branch="$2" slug
  slug=$(printf '%s-%s' "$repo" "$branch" | tr '/ ' '__' | tr -cd 'A-Za-z0-9._-')
  printf '%s/%s' "$PR_CACHE_DIR" "$slug"
}

# Read the cached M-state and, when stale (and not terminally "merged") AND a
# refresh is permitted, kick off a detached background refresh. Echoes "1" when
# the M letter should show (state == unmerged), nothing otherwise. Never calls
# gh synchronously.
#
# $3 (allow_refresh): "1" → the branch is fully pushed, so gh may be queried to
# refresh a stale cache; "" → the branch has unpushed work (or no upstream), so
# we must NOT query gh (no remote branch a PR could target that we haven't seen
# yet) — but we STILL serve a previously-learned "unmerged" from the cache. This
# is what keeps M lit for an existing (draft) PR after you add a local commit on
# top: the gate blocks the network call, not the display of what we already know.
pr_cache_status() {
  local cwd="$1" branch="$2" allow_refresh="$3"
  # Need a repo slug for the cache key; derive from the origin remote URL basename.
  local remote repo
  remote=$(git -C "$cwd" config --get remote.origin.url 2>/dev/null)
  [ -z "$remote" ] && return 0   # no remote → no PR concept → no M
  repo=$(basename -s .git "$remote")
  local file state age now
  file=$(pr_cache_file "$repo" "$branch")

  state=""
  if [ -f "$file" ]; then
    state=$(cut -d' ' -f1 "$file" 2>/dev/null)
    local written
    written=$(cut -d' ' -f2 "$file" 2>/dev/null)
    now=$(date +%s 2>/dev/null)
    if [ -n "$written" ] && [ -n "$now" ]; then
      age=$((now - written))
    else
      age=$PR_CACHE_TTL  # unparseable → treat as stale
    fi
  else
    age=$PR_CACHE_TTL    # missing → stale
  fi

  # "merged" is terminal: serve from cache forever, never refresh.
  if [ "$state" = "merged" ]; then
    return 0
  fi

  # Stale (or missing) and not terminal → refresh in the background, but only
  # when a refresh is permitted (branch fully pushed). A branch with unpushed
  # work keeps serving its last-known state without touching gh.
  if [ -n "$allow_refresh" ] && [ "${age:-$PR_CACHE_TTL}" -ge "$PR_CACHE_TTL" ] 2>/dev/null; then
    pr_cache_refresh "$cwd" "$branch" "$file" &
  fi

  # Serve whatever we currently know. Only "unmerged" lights the M letter.
  [ "$state" = "unmerged" ] && printf '1'
  return 0
}

# Detached background refresh: query gh for the branch's PR state and rewrite
# the cache file. Runs disconnected from the render; its latency never matters.
# Requires `gh`; silently no-ops (leaving the stale cache) if gh is absent or
# the network is down.
pr_cache_refresh() {
  local cwd="$1" branch="$2" file="$3"
  command -v gh > /dev/null 2>&1 || return 0
  mkdir -p "$PR_CACHE_DIR" 2>/dev/null
  local state now json merged
  # --state all so we still see a merged PR; take the most recent match.
  json=$(cd "$cwd" && gh pr list --head "$branch" --state all \
           --json state --limit 1 --jq '.[0].state' 2>/dev/null)
  case "$json" in
    MERGED)          state="merged" ;;
    OPEN|CLOSED)     state="unmerged" ;;  # CLOSED-unmerged still "not merged"
    *)               state="none" ;;      # no PR / gh error
  esac
  # A CLOSED (not merged) PR shouldn't nag forever; treat only OPEN as unmerged.
  [ "$json" = "CLOSED" ] && state="none"
  now=$(date +%s 2>/dev/null)
  printf '%s %s\n' "$state" "${now:-0}" > "$file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Git branch + a [CPM] status block (all computed locally + a cache file; the
# render NEVER blocks on the network — see the M note below).
#
#   C  local Changes not committed  (uncommitted work in the tree)
#   P  local commits not Pushed     (commits ahead of the upstream branch)
#   M  PR not Merged                (an open, unmerged PR exists — only checked
#                                    once the branch is fully pushed; see gate)
#
# Each letter shows only when its condition holds; an all-clear branch shows no
# block at all (not even the "[]" brackets). The letters are red; the brackets
# are gray.
#
# M kill-switch: the M letter is the only thing that shells out to `gh` (via a
# detached background refresh). It is DISABLED BY DEFAULT while we measure `gh`
# load across cases — under suspicion that the background refresh overloads `gh`.
# Set  STATUSLINE_COMPACT_ENABLE_PR_CHECK=1  to re-enable it (e.g. to take those
# measurements). With it unset/0 the entire M block is skipped — no cache read,
# no gate evaluation, no gh invocation ever — and the C/P letters are unaffected.
# Measurement plan / re-enable criteria:
#   https://github.com/artem-from-ua/claude-plugins/issues/356
# ---------------------------------------------------------------------------
branch=""
committed_dirty=""   # C: uncommitted changes in the working tree
unpushed=""          # P: local commits not on the upstream branch
pr_unmerged=""       # M: an open, unmerged PR exists (from the cache file)
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    # C — uncommitted changes (staged, unstaged, or untracked)
    if [ -n "$(git -C "$cwd" status --porcelain=v1 --untracked-files=normal 2>/dev/null)" ]; then
      committed_dirty="1"
    fi
    # P — commits ahead of the upstream. Reads only local refs (no network).
    # `rev-list '@{upstream}..HEAD'` returns empty on failure, which happens in
    # TWO distinct states that must be told apart:
    #   1. never pushed  — no `branch.<name>.remote` config at all. Flag P only
    #                       if HEAD carries commits absent from EVERY remote-
    #                       tracking branch; a fresh branch cut from origin/main
    #                       (while local main is behind) has none → no P.
    #   2. pushed→deleted — the branch was pushed, its PR merged, and the remote
    #                       branch deleted (`gh pr merge --delete-branch`). The
    #                       `branch.<name>.remote`/`.merge` config STAYS, so
    #                       `@{upstream}` points at a now-gone tracking ref and
    #                       rev-list fails — but the work is already in main, so
    #                       there is nothing to push → do NOT flag P.
    # `git config --get branch.<name>.remote` is a purely-local read that tells
    # the two apart: absent → state 1 (P), present → state 2 (no P). In state 2
    # `has_upstream` stays "" so the M gate below also skips (no gh for a branch
    # whose remote is gone).
    has_upstream=""
    ahead=$(git -C "$cwd" rev-list --count '@{upstream}..HEAD' 2>/dev/null)
    if [ -n "$ahead" ]; then
      # Upstream resolved and rev-list succeeded → normal case.
      has_upstream="1"
      [ "$ahead" -gt 0 ] 2>/dev/null && unpushed="1"
    elif [ -z "$(git -C "$cwd" config --get "branch.$branch.remote" 2>/dev/null)" ]; then
      # State 1: no upstream config. Flag P only if HEAD carries commits that are
      # on NO remote-tracking branch — otherwise there is genuinely nothing to
      # push (e.g. a fresh worktree branched off origin/main while local main is
      # behind). Purely local, no network; works for any remote layout.
      local_only=$(git -C "$cwd" rev-list --count HEAD --not --remotes 2>/dev/null)
      [ -n "$local_only" ] && [ "$local_only" -gt 0 ] 2>/dev/null && unpushed="1"
    fi
    # else State 2: upstream config exists but its tracking ref is gone
    # (pushed→merged→deleted). Nothing to push → leave unpushed/has_upstream unset.
    # M — PR-not-merged, resolved from a cache file the render only READS. Two
    # separate git-only gates, deliberately distinct:
    #
    #   1. Protected branches (main/master/develop) never carry a feature PR, so
    #      they get no M at all and never call gh.
    #   2. Whether gh may be queried to REFRESH the cache is gated on the branch
    #      being fully pushed (has_upstream AND nothing unpushed) — until it is on
    #      the remote there is no branch a PR could target that we haven't already
    #      seen. But an already-known "unmerged" (e.g. an existing draft PR) STILL
    #      lights M even after you add a local commit on top; the unpushed state
    #      blocks the network refresh, not the display of what the cache knows.
    #
    # The merged/open distinction still needs gh, done via a detached background
    # refresh so the render never waits on api.github.com.
    # M is opt-in while we measure gh load (see the kill-switch note above).
    # Unless STATUSLINE_COMPACT_ENABLE_PR_CHECK is truthy, the whole block is
    # skipped so `gh` is never invoked. C/P above are already computed.
    case "${STATUSLINE_COMPACT_ENABLE_PR_CHECK:-0}" in
      1|true|yes|on)
        case "$branch" in
          main|master|develop) : ;;   # protected → no M, no gh
          *)
            if [ -n "$has_upstream" ]; then
              fully_pushed=""
              [ -z "$unpushed" ] && fully_pushed="1"
              pr_unmerged=$(pr_cache_status "$cwd" "$branch" "$fully_pushed")
            fi
            ;;
        esac
        ;;
    esac
  fi
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Colorize model name by keyword. Opus=71 (green), Fable=167 (red),
# Sonnet=37 (cyan), Haiku=33 (blue).
# Trims a trailing " (… context)" parenthetical (ctx-size is its own segment)
# and dims the version number.
colorize_model() {
  local name="$1"
  # "Opus 4.8 (1M context)" -> "Opus 4.8"
  name=$(echo "$name" | sed -E 's/ *\([^)]*context\)$//')
  # Drop a leading "Claude " if present
  name=$(echo "$name" | sed 's/^Claude //')

  local color="" keyword=""
  if echo "$name" | grep -qi "fable"; then
    color=$(printf '\033[38;5;167m'); keyword="Fable"
  elif echo "$name" | grep -qi "opus"; then
    color=$(printf '\033[38;5;71m'); keyword="Opus"
  elif echo "$name" | grep -qi "sonnet"; then
    color=$(printf '\033[38;5;37m'); keyword="Sonnet"
  elif echo "$name" | grep -qi "haiku"; then
    color=$(printf '\033[38;5;33m'); keyword="Haiku"
  fi

  # Dim the version number (e.g. 4.8)
  local out
  out=$(echo "$name" | sed -E "s/([0-9]+\.[0-9]+)/${dim}\1${rst}/g")
  # Color the keyword token (display_name is canonical-cased, no /I flag needed)
  [ -n "$color" ] && out=$(echo "$out" | sed "s/${keyword}/${color}${keyword}${rst}/")
  # Join the keyword and version with a tight separator (e.g. Opus･4.8)
  echo "$out" | sed "s/ /${SEP}/g"
}

# Map a branch-type prefix token to its color.
branch_prefix_color() {
  case "$1" in
    feature|feat)               printf '\033[38;5;114m' ;;
    fix|bugfix|hotfix)          printf '\033[38;5;203m' ;;
    release|chore|revert)       printf '\033[38;5;221m' ;;
    refactor|docs|test|ci|wip|exp|experiment|dev|develop) printf '\033[38;5;110m' ;;
    *)                          printf '\033[38;5;245m' ;;
  esac
}

# Colorize a git branch: color the prefix token by type, dim the delimiter.
#
#   $1  branch name
#   $2  non-empty when this is a worktree session (.workspace.git_worktree set)
#
# Two delimiter conventions, same color rules:
#   normal    feature/login          -> 114 "feature" + dim "/" + "login"
#   worktree  worktree-fix+a-b-267   -> dim "worktree-" + 203 "fix" + dim "+" + "a-b-267"
# Claude Code names a worktree branch "worktree-<git_worktree>" and slugifies the
# worktree name's "/" to "+", so "+" is that layout's prefix delimiter. Both the
# dim "worktree-" head and the "+" split apply ONLY to a branch that really starts
# with "worktree-" in a real worktree session, so a branch merely containing "+"
# (feature/a+b) or one named "worktree-…" in the main checkout keeps plain "/"
# rendering. A worktree branch with no "+" (worktree-experiments) gets the dim
# head and nothing else — there is no prefix token to classify.
colorize_branch() {
  local branch="$1" is_worktree="$2"
  local head="" rest="$branch" prefix suffix color

  if [ -n "$is_worktree" ] && [ "${branch#worktree-}" != "$branch" ]; then
    head="${dim}worktree-${rst}"
    rest="${branch#worktree-}"
  fi

  if [ -n "$head" ] && [ "${rest#*+}" != "$rest" ]; then
    prefix="${rest%%+*}"; suffix="${rest#*+}"
    color=$(branch_prefix_color "$prefix")
    echo "${head}${color}${prefix}${rst}${dim}+${rst}${suffix}"
  elif [ "${rest#*/}" != "$rest" ]; then
    prefix="${rest%%/*}"; suffix="${rest#*/}"
    color=$(branch_prefix_color "$prefix")
    echo "${head}${color}${prefix}${rst}${dim}/${rst}${suffix}"
  else
    echo "${head}${rest}"
  fi
}

# Humanize a context-window size: 1000000 -> 1M, 200000 -> 200K, 1500000 -> 1.5M.
# The K/M suffix is dim. Contexts below 1M color the number yellow to flag the
# reduced window; a full 1M+ context leaves the number in the terminal default.
# Pure bash integer math (no awk/python).
humanize_ctx() {
  local n="$1"
  case "$n" in ''|*[!0-9]*) echo "$n"; return ;; esac
  local whole rem
  local yellow=$(printf '\033[38;5;178m')
  if [ "$n" -ge 1000000 ]; then
    whole=$((n / 1000000)); rem=$(((n % 1000000) / 100000))
    [ "$rem" -eq 0 ] && echo "${whole}${dim}M${rst}" || echo "${whole}.${rem}${dim}M${rst}"
  elif [ "$n" -ge 1000 ]; then
    whole=$((n / 1000)); rem=$(((n % 1000) / 100))
    [ "$rem" -eq 0 ] && echo "${yellow}${whole}${rst}${dim}K${rst}" || echo "${yellow}${whole}.${rem}${rst}${dim}K${rst}"
  else
    echo "${yellow}${n}${rst}"
  fi
}

# Colorize the reasoning-effort level along a low→max gradient.
# Known levels (least→most): low, medium, high, xhigh, max.
# low=blue, medium=cyan, high=green, xhigh=yellow, max=red.
# An unknown level renders plain.
colorize_effort() {
  local level="$1" color=""
  case "$level" in
    low)    color=$(printf '\033[38;5;33m')  ;;   # blue
    medium) color=$(printf '\033[38;5;37m')  ;;   # cyan
    high)   color=$(printf '\033[38;5;71m')  ;;   # green
    xhigh)  color=$(printf '\033[38;5;178m') ;;   # yellow
    max)    color=$(printf '\033[38;5;167m') ;;   # red
  esac
  [ -n "$color" ] && echo "${color}${level}${rst}" || echo "$level"
}

# Detect whether the most recent /effort this session selected an ultra mode.
# Prints "ultracode"/"ultraplan" (the raw word) when so, nothing otherwise — the
# caller renders a single violet "ultra" token in place of the effort level.
# Rationale + why it needs jq, not a bare grep:
#
#   The /effort command echoes plain text — "Set effort level to <word>" — into a
#   message body. ultracode/ultraplan exist ONLY as that free text; the structured
#   .effort enum never holds them (it is low/medium/high/xhigh/max), so the sole
#   signal is the transcript. BUT a naive `grep 'Set effort level to' | tail -1`
#   also matches our own assistant prose that quotes the phrase, and picks the
#   wrong (most-recent-quoted) word — verified: it returned "ultraplan"/"ultrathink"
#   while the real /effort was "max". The only reliable filter is the record type:
#   a genuine /effort echo is a type=="user" record carrying <local-command-stdout>.
#
#   grep -a narrows the JSONL to candidate lines fast (binary-safe; JSONL can carry
#   odd bytes, else grep may print "Binary file matches"); jq then parses ONLY those
#   few lines, keeps type=="user", and extracts the word. tail -1 = most recent.
#   Cost ~7ms on a 2.6MB transcript. ultracode and ultraplan are one effort slot
#   renamed by permission mode (normal->ultracode, plan->ultraplan), so at most one
#   is ever current.
ultra_detect() {
  local tp="$1" word
  [ -f "$tp" ] && [ -r "$tp" ] || return 0
  word=$(grep -aE '<local-command-stdout>Set effort level to' "$tp" 2>/dev/null \
    | jq -rc 'select(.type=="user")
        | (.message.content // empty)
        | (if type=="array" then (map(.text // "") | join("\n")) else tostring end)
        | (capture("<local-command-stdout>Set effort level to (?<w>[a-z]+)").w // empty)' 2>/dev/null \
    | tail -1)
  case "$word" in
    ultracode|ultraplan) printf '%s' "$word" ;;
  esac
  return 0
}

# ---------------------------------------------------------------------------
# Single line, top-level segments joined with WIDE_SEP (three spaces):
#   repo   [badge･]branch･[CPM]   model･effort   ctx-size･ctx-used%   $cost
# The checkout badge, when shown, attaches to the branch with a tight "･"; the [CPM] status
# block follows the branch with a tight "･" too. Everything else is SEP-joined.
# Absent optional segments are omitted so nothing shifts.
# ---------------------------------------------------------------------------
line=""
# append() joins top-level segments with three spaces; append_tight() joins with a
# tight "･" (no surrounding spaces) for segments that read as a pair.
append() { [ -z "$line" ] && line="$1" || line="${line}${WIDE_SEP}$1"; }
append_tight() { [ -z "$line" ] && line="$1" || line="${line}${SEP}$1"; }

# repo name as the first (spaced) segment.
append "$repo_name"

# Checkout marker, attached to the branch with a tight "･" (badge･branch).
# Presence of .workspace.git_worktree is the worktree signal (set only in worktree
# sessions); the branch name decides whether a badge is needed at all:
#   main checkout          -> yellow "Root"
#   worktree, "worktree-*" -> no badge; the branch already reads "worktree-<name>"
#                             (colorize_branch dims that head), so a badge would
#                             only repeat it.
#   worktree, other branch -> gray "Worktree" comes back: you switched branches
#                             inside the worktree, so nothing else on the line
#                             would hint that this is a worktree.
if [ -z "$worktree" ]; then
  badge="${yellow}Root${rst}"
elif [ -n "$branch" ] && [ "${branch#worktree-}" != "$branch" ]; then
  badge=""
else
  badge="${dim}Worktree${rst}"
fi

# Build the [CPM] status block: red letters for each active condition, gray
# brackets. No active letters → no block at all (not even the brackets).
#   C committed_dirty · P unpushed · M pr_unmerged
cpm=""
[ -n "$committed_dirty" ] && cpm="${cpm}C"
[ -n "$unpushed" ]        && cpm="${cpm}P"
[ -n "$pr_unmerged" ]     && cpm="${cpm}M"
status_block=""
[ -n "$cpm" ] && status_block="${dim}[${rst}${bright_red}${cpm}${rst}${dim}]${rst}"

# branch (+ optional [CPM] block), preceded tightly by the badge when there is one.
# When there is no branch (cwd is not a git repo), the badge stands alone as its
# own segment.
if [ -n "$branch" ]; then
  branch_disp="$(colorize_branch "$branch" "$worktree")"
  [ -n "$badge" ] && branch_disp="${badge}${SEP}${branch_disp}"
  [ -n "$status_block" ] && branch_disp="${branch_disp}${SEP}${status_block}"
  append "$branch_disp"
else
  append "$badge"
fi

[ -n "$model" ]  && append "$(colorize_model "$model")"
# effort attaches tightly to the model (model･effort). In an ultra mode the effort
# segment is REPLACED by a single violet "ultra" token (instead of showing the
# coarse xhigh level plus a separate ultracode/ultraplan marker); otherwise the
# normal color-coded effort level is shown.
if [ -n "$(ultra_detect "$transcript")" ]; then
  append_tight "${ultra_color}ultra${rst}"
elif [ -n "$effort" ]; then
  append_tight "$(colorize_effort "$effort")"
fi
[ -n "$ctx_size" ] && append "$(humanize_ctx "$ctx_size")"

# context used % attaches tightly to the context size (ctx-size･ctx-used%)
if [ -n "$used_pct" ]; then
  ci=${used_pct%.*}
  if [ "$ci" -ge 80 ] 2>/dev/null; then
    append_tight "${bright_red}${used_pct}${rst}${dim}%${rst}"
  elif [ "$ci" -ge 60 ] 2>/dev/null; then
    append_tight "${yellow}${used_pct}${rst}${dim}%${rst}"
  else
    append_tight "${used_pct}${dim}%${rst}"
  fi
fi

# session cost — always shown, even $0.00
cost_fmt=$(awk "BEGIN{printf \"%.2f\", $cost}")
cost_int=${cost_fmt%.*}
cost_frac=".${cost_fmt#*.}"
append "${dim}\$${rst}${cost_int}${dim}${cost_frac}${rst}"

printf '%s\n' "$line"
