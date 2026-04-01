#!/bin/bash
# Claude Code compact statusline (SINGLE-LINE LAYOUT)
# Reads JSON from stdin (piped by Claude Code)
#
# Layout:
#   5h 12% ~2h14m  7d 45% ~3d5h  $0.42  Sonnet 4.5  52%  my-project/  main
#
# Progressive hiding: when terminal is narrow, drops segments to leave room
# for Claude Code system notifications. Drop order: dir, cost.
#
# Brightness-coded values: dim at low usage, brighter as they climb,
# yellow >90%, red at 100%. Text indicators: !! warning, XX exhausted.
#
# Data source: rate_limits from Claude Code statusline input JSON (v2.1.80+)

input=$(cat)

# ANSI colors
rst=$(printf '\033[0m')
dim=$(printf '\033[38;5;242m')
very_dim=$(printf '\033[38;5;237m')
bright_red=$(printf '\033[38;5;167m')
yellow=$(printf '\033[38;5;178m')

DOLLAR='$'

# Measure visual width of a string (strip ANSI escape sequences)
visual_width() {
  printf '%s' "$1" | sed $'s/\x1b\\[[0-9;]*m//g' | wc -m | tr -d ' '
}

# Join non-empty segments with 2-space gaps
assemble_line() {
  local line=""
  for seg in "$@"; do
    if [ -n "$seg" ]; then
      if [ -n "$line" ]; then
        line="${line}  ${seg}"
      else
        line="${seg}"
      fi
    fi
  done
  printf '%s' "$line"
}

# Brightness gradient for percentage values
# Low usage fades into background, high usage draws attention
pct_color() {
  local val=$1
  if [ "$val" -ge 100 ] 2>/dev/null; then
    printf '\033[38;5;167m'    # red - exhausted
  elif [ "$val" -gt 90 ] 2>/dev/null; then
    printf '\033[38;5;178m'    # yellow - warning
  elif [ "$val" -ge 60 ] 2>/dev/null; then
    printf '\033[0m'           # default - notable
  elif [ "$val" -ge 30 ] 2>/dev/null; then
    printf '\033[38;5;246m'    # light dim - moderate
  else
    printf '\033[38;5;240m'    # dim - low, fade out
  fi
}

# Colorize model name
# Brightness = capability tier: Opus bright, Sonnet default, Haiku dim
colorize_model() {
  local name="$1"
  local color=""
  local keyword=""
  if echo "$name" | grep -qi "opus"; then
    color=$(printf '\033[1;97m'); keyword="Opus"
  elif echo "$name" | grep -qi "sonnet"; then
    color=$(printf '\033[38;5;252m'); keyword="Sonnet"
  elif echo "$name" | grep -qi "haiku"; then
    color=$(printf '\033[38;5;245m'); keyword="Haiku"
  fi
  if [ -n "$color" ]; then
    echo "$name" | sed "s/$keyword/${color}${keyword}${rst}/"
  else
    echo "$name"
  fi
}

# Format time remaining from epoch seconds
format_time_remaining() {
  local reset_epoch="$1"
  local threshold_hours="$2"
  if [ -z "$reset_epoch" ] || [ "$reset_epoch" = "null" ]; then
    echo ""
    return
  fi
  local now=$(date +%s)
  local diff=$(( reset_epoch - now ))
  if [ "$diff" -le 0 ]; then
    echo "now"
    return
  fi
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))

  local total_hours=$(( days * 24 + hours ))

  if [ "$total_hours" -ge "$threshold_hours" ]; then
    if [ "$days" -gt 0 ]; then
      if [ "$hours" -ge 12 ]; then
        days=$(( days + 1 ))
      fi
      echo "~${days}d"
    else
      if [ "$mins" -ge 30 ]; then
        hours=$(( hours + 1 ))
      fi
      echo "~${hours}h"
    fi
  else
    if [ "$days" -gt 0 ]; then
      echo "${days}d${hours}h"
    elif [ "$hours" -gt 0 ]; then
      echo "${hours}h${mins}m"
    else
      echo "${mins}m"
    fi
  fi
}

# Apply dim to time units (~, h, m, d)
dim_time_units() {
  local remaining="$1"
  local result=""
  for ((i=0; i<${#remaining}; i++)); do
    char="${remaining:$i:1}"
    case "$char" in
      '~'|h|m|d) result="${result}${dim}${char}${rst}" ;;
      *) result="${result}${char}" ;;
    esac
  done
  echo -n "$result"
}

# Extract basic fields from statusline JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Git branch + dirty indicator
branch=""
dirty=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    git_status_output=$(git -C "$cwd" status --porcelain=v1 --untracked-files=normal 2>/dev/null)
    if [ -n "$git_status_output" ]; then
      dirty="true"
    fi
  fi
fi

short_dir=$(basename "$cwd")

# Rate limits from Claude Code statusline input (available since v2.1.80)
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_hour_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_day_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# ===== BUILD COMPACT SEGMENTS =====

# 5h segment
compact_5h=""
if [ -n "$five_hour_pct" ]; then
    five_int=${five_hour_pct%.*}
    five_remaining=$(format_time_remaining "$five_hour_resets" 2)
    five_time_with_dim=$(dim_time_units "$five_remaining")

    c5_color=$(pct_color "$five_int")
    c5_pct="${c5_color}${five_int}%${rst}"
    c5_suffix=""
    [ "$five_int" -ge 100 ] 2>/dev/null && c5_suffix=" ${bright_red}XX${rst}"
    [ "$five_int" -gt 90 ] 2>/dev/null && [ "$five_int" -lt 100 ] 2>/dev/null && c5_suffix=" ${yellow}!!${rst}"
    c5_time=""
    if [ -n "$five_remaining" ] && [ "$five_int" -ge 60 ] 2>/dev/null; then
      c5_time=" ${five_time_with_dim}"
    fi
    compact_5h="${dim}5h${rst} ${c5_pct}${c5_time}${c5_suffix}"
fi

# 7d segment
compact_7d=""
if [ -n "$seven_day_pct" ]; then
    seven_int=${seven_day_pct%.*}
    seven_remaining=$(format_time_remaining "$seven_day_resets" 48)
    seven_time_with_dim=$(dim_time_units "$seven_remaining")

    c7_color=$(pct_color "$seven_int")
    c7_pct="${c7_color}${seven_int}%${rst}"
    c7_suffix=""
    [ "$seven_int" -ge 100 ] 2>/dev/null && c7_suffix=" ${bright_red}XX${rst}"
    [ "$seven_int" -gt 90 ] 2>/dev/null && [ "$seven_int" -lt 100 ] 2>/dev/null && c7_suffix=" ${yellow}!!${rst}"
    c7_time=""
    if [ -n "$seven_remaining" ] && [ "$seven_int" -ge 60 ] 2>/dev/null; then
      c7_time=" ${seven_time_with_dim}"
    fi
    compact_7d="${dim}7d${rst} ${c7_pct}${c7_time}${c7_suffix}"
fi

# Session cost segment: "$0.42"
compact_cost=""
session_cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$session_cost_usd" ] && [ "$session_cost_usd" != "null" ]; then
  dec_sep=$(printf "%.1f" 1 | tr -d '01')
  cost_locale=$(echo "$session_cost_usd" | sed "s/\./${dec_sep}/")
  cost_fmt=$(echo "$cost_locale" | awk '{printf "%.2f", $1}')
  cost_int=$(echo "$cost_fmt" | sed 's/[.,].*//')
  cost_frac=$(echo "$cost_fmt" | grep -o '[.,][0-9]*$')
  compact_cost="${dim}${DOLLAR}${rst}${cost_int}${dim}${cost_frac}${rst}"
fi

# Model segment: strip "Claude " prefix and parenthetical suffix (e.g. "(1M context)")
compact_model_name=$(echo "$model" | sed 's/^Claude //; s/ ([^)]*)$//g')
compact_model_colored=$(colorize_model "$compact_model_name")
compact_model=$(echo "$compact_model_colored" | sed -E "s/([0-9]+\.[0-9]+)/${dim}\1${rst}/g")

# Context segment: bare percentage (distinguishable from 5h/7d by lack of prefix)
compact_ctx=""
if [ -n "$used_pct" ]; then
  context_int=${used_pct%.*}
  ctx_c=$(pct_color "$context_int")
  compact_ctx="${ctx_c}${used_pct}%${rst}"
  [ "$context_int" -ge 80 ] 2>/dev/null && compact_ctx="${compact_ctx} ${bright_red}!!${rst}"
fi

# Dir segment: trailing / signals it's a directory
compact_dir="${short_dir}${dim}/${rst}"

# Branch segment: "main" or "main*" (yellow if dirty)
# Truncate long branches: "chore/statusline-compact-model-label" -> "chore/sta..label"
MAX_BRANCH=20
compact_branch=""
if [ -n "$branch" ]; then
  display_branch="$branch"
  if [ "${#branch}" -gt "$MAX_BRANCH" ]; then
    prefix="${branch%%/*}"
    suffix="${branch##*/}"
    if [ "$prefix" != "$branch" ]; then
      # Has a prefix/ - truncate the description part
      budget=$(( MAX_BRANCH - ${#prefix} - 1 - 2 ))  # -1 for /, -2 for ..
      if [ "$budget" -gt 4 ]; then
        keep_start=$(( budget / 2 ))
        keep_end=$(( budget - keep_start ))
        display_branch="${prefix}/${suffix:0:$keep_start}..${suffix: -$keep_end}"
      else
        display_branch="${branch:0:$(( MAX_BRANCH - 2 ))}.."
      fi
    else
      display_branch="${branch:0:$(( MAX_BRANCH - 2 ))}.."
    fi
  fi
  if [ -n "$dirty" ]; then
    compact_branch="${yellow}${display_branch}*${rst}"
  else
    compact_branch="${display_branch}"
  fi
fi

# ===== PROGRESSIVE HIDING =====
# Claude Code appends system notifications to the right of the last statusline line.
# Reserve: 0 because notifications are rare and the statusline is already tight.

NOTIFICATION_RESERVE=0

term_width=$(tput cols 2>/dev/null)
if ! [ "$term_width" -ge 40 ] 2>/dev/null; then
  term_width=""
fi

if [ -n "$term_width" ]; then
  available=$(( term_width - NOTIFICATION_RESERVE ))

  # Level 0: all segments
  compact_line=$(assemble_line "$compact_5h" "$compact_7d" "$compact_cost" "$compact_model" "$compact_ctx" "$compact_dir" "$compact_branch")

  if [ "$(visual_width "$compact_line")" -gt "$available" ]; then
    # Level 1: drop directory
    compact_line=$(assemble_line "$compact_5h" "$compact_7d" "$compact_cost" "$compact_model" "$compact_ctx" "$compact_branch")
  fi

  if [ "$(visual_width "$compact_line")" -gt "$available" ]; then
    # Level 2: drop session cost
    compact_line=$(assemble_line "$compact_5h" "$compact_7d" "$compact_model" "$compact_ctx" "$compact_branch")
  fi
else
  # Fallback: no terminal width detected, show everything
  compact_line=$(assemble_line "$compact_5h" "$compact_7d" "$compact_cost" "$compact_model" "$compact_ctx" "$compact_dir" "$compact_branch")
fi

echo "$compact_line"
