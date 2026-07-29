#!/bin/bash
# Claude Code compact statusline (SINGLE-LINE LAYOUT)
# Reads JSON from stdin (piped by Claude Code). Dependencies: jq, git.
# No network calls, no python3 — uses only stdin fields plus local git.
#
# Layout (one line, segments joined with ･):
#   repo-name worktree ･ branch ! ･ model ･ effort ･ ctx-size ･ ctx-used% ･ $cost
#   (worktree name is dimmed and attached to the repo with a plain space)
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

# Separator between widgets — U+FF65 halfwidth middle dot, very_dim
SEP="${very_dim}･${rst}"

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

# ---------------------------------------------------------------------------
# Git branch + dirty indicator (computed locally, like the statusline plugin).
# ---------------------------------------------------------------------------
branch=""
dirty=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    if [ -n "$(git -C "$cwd" status --porcelain=v1 --untracked-files=normal 2>/dev/null)" ]; then
      dirty="1"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Colorize model name by keyword. Fable=167, Opus=178, Sonnet=71, Haiku=37.
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
    color=$(printf '\033[38;5;178m'); keyword="Opus"
  elif echo "$name" | grep -qi "sonnet"; then
    color=$(printf '\033[38;5;71m'); keyword="Sonnet"
  elif echo "$name" | grep -qi "haiku"; then
    color=$(printf '\033[38;5;37m'); keyword="Haiku"
  fi

  # Dim the version number (e.g. 4.8)
  local out
  out=$(echo "$name" | sed -E "s/([0-9]+\.[0-9]+)/${dim}\1${rst}/g")
  # Color the keyword token (display_name is canonical-cased, no /I flag needed)
  [ -n "$color" ] && out=$(echo "$out" | sed "s/${keyword}/${color}${keyword}${rst}/")
  # Keep the plain space between keyword and version (e.g. Opus 4.8)
  echo "$out"
}

# Colorize git branch: color the prefix by type, dim the slash.
colorize_branch() {
  local branch="$1"
  local c_feature=$(printf '\033[38;5;114m')
  local c_fix=$(printf '\033[38;5;203m')
  local c_release=$(printf '\033[38;5;221m')
  local c_refactor=$(printf '\033[38;5;110m')
  local c_default=$(printf '\033[38;5;245m')

  local prefix color suffix
  if echo "$branch" | grep -q '/'; then
    prefix="${branch%%/*}"
    suffix="${branch#*/}"
    case "$prefix" in
      feature|feat)               color="$c_feature" ;;
      fix|bugfix|hotfix)          color="$c_fix" ;;
      release|chore|revert)       color="$c_release" ;;
      refactor|docs|test|ci|wip|exp|experiment|dev|develop) color="$c_refactor" ;;
      *)                          color="$c_default" ;;
    esac
    echo "${color}${prefix}${rst}${dim}/${rst}${suffix}"
  else
    echo "$branch"
  fi
}

# Humanize a context-window size: 1000000 -> 1M, 200000 -> 200K, 1500000 -> 1.5M.
# Number is bright, the K/M suffix is dim. Pure bash integer math (no awk/python).
humanize_ctx() {
  local n="$1"
  case "$n" in ''|*[!0-9]*) echo "$n"; return ;; esac
  local whole rem
  if [ "$n" -ge 1000000 ]; then
    whole=$((n / 1000000)); rem=$(((n % 1000000) / 100000))
    [ "$rem" -eq 0 ] && echo "${whole}${dim}M${rst}" || echo "${whole}.${rem}${dim}M${rst}"
  elif [ "$n" -ge 1000 ]; then
    whole=$((n / 1000)); rem=$(((n % 1000) / 100))
    [ "$rem" -eq 0 ] && echo "${whole}${dim}K${rst}" || echo "${whole}.${rem}${dim}K${rst}"
  else
    echo "$n"
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

# ---------------------------------------------------------------------------
# Single line, segments joined with SEP:
#   repo worktree ･ branch ! ･ model ･ effort ･ ctx-size ･ ctx-used% ･ $cost
# The dimmed worktree name attaches to the repo with a plain space; the dirty "!"
# attaches to the branch with a plain space. Everything else is SEP-joined.
# Absent optional segments are omitted so nothing shifts.
# ---------------------------------------------------------------------------
line=""
append() { [ -z "$line" ] && line="$1" || line="${line} ${SEP} $1"; }

# repo (+ optional dimmed worktree name) as the first segment
repo_seg="$repo_name"
[ -n "$worktree" ] && repo_seg="${repo_seg} ${dim}${worktree}${rst}"
append "$repo_seg"

# branch (+ optional dirty "!")
if [ -n "$branch" ]; then
  branch_disp=$(colorize_branch "$branch")
  [ -n "$dirty" ] && branch_disp="${branch_disp} ${bright_red}!${rst}"
  append "$branch_disp"
fi

[ -n "$model" ]  && append "$(colorize_model "$model")"
[ -n "$effort" ] && append "$(colorize_effort "$effort")"
[ -n "$ctx_size" ] && append "$(humanize_ctx "$ctx_size")"

if [ -n "$used_pct" ]; then
  ci=${used_pct%.*}
  if [ "$ci" -ge 80 ] 2>/dev/null; then
    append "${bright_red}${used_pct}${rst}${dim}%${rst}"
  elif [ "$ci" -ge 60 ] 2>/dev/null; then
    append "${yellow}${used_pct}${rst}${dim}%${rst}"
  else
    append "${used_pct}${dim}%${rst}"
  fi
fi

# session cost — always shown, even $0.00
cost_fmt=$(awk "BEGIN{printf \"%.2f\", $cost}")
cost_int=${cost_fmt%.*}
cost_frac=".${cost_fmt#*.}"
append "${dim}\$${rst}${cost_int}${dim}${cost_frac}${rst}"

printf '%s\n' "$line"
