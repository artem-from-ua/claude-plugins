#!/bin/bash
# Claude Code compact statusline (SINGLE-LINE LAYOUT)
# Reads JSON from stdin (piped by Claude Code)
#
# Layout:
#   5h 12% ~2h14m   7d 45% ~3d5h   extra $4.79   $0.42   Sonnet 4.5   context 52%   my-project/   main
#
# Progressive hiding: when terminal is narrow, drops segments to leave room
# for Claude Code system notifications. Drop order: dir, cost, extra usage.
#
# Brightness-coded values: dim at low usage, brighter as they climb,
# yellow >90%, red at 100%. Text indicators: !! warning, XX exhausted.
#
# Data source: Anthropic OAuth usage API, cached for 60s

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

# Join non-empty segments with 3-space gaps
assemble_line() {
  local line=""
  for seg in "$@"; do
    if [ -n "$seg" ]; then
      if [ -n "$line" ]; then
        line="${line}   ${seg}"
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

# Parse reset timestamp to epoch seconds
parse_reset_epoch() {
  local resets_at="$1"
  if [ -z "$resets_at" ] || [ "$resets_at" = "null" ]; then
    echo ""
    return
  fi
  local normalized
  normalized=$(echo "$resets_at" | sed 's/\.[0-9]*+00:00$//' | sed 's/+00:00$//')
  if [ "$(uname)" = "Darwin" ]; then
    date -juf "%Y-%m-%dT%H:%M:%S" "$normalized" +%s 2>/dev/null
  else
    date -ud "$normalized" +%s 2>/dev/null
  fi
}

# Format time remaining
format_time_remaining() {
  local resets_at="$1"
  local threshold_hours="$2"
  local reset_epoch
  reset_epoch=$(parse_reset_epoch "$resets_at")
  if [ -z "$reset_epoch" ]; then
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

# Fetch usage data from Anthropic API (cached for 60 seconds)
cache_file="/tmp/claude-statusline-usage-cache-${UID}"
cache_max_age=60
now=$(date +%s)
use_cache=false

if [ -f "$cache_file" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null || echo 0)
  else
    cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
  fi
  cache_age=$(( now - cache_mtime ))
  if [ "$cache_age" -lt "$cache_max_age" ]; then
    use_cache=true
  fi
fi

usage_json=""
if [ "$use_cache" = true ]; then
  usage_json=$(cat "$cache_file" 2>/dev/null)
else
  token=""
  if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    token="$CLAUDE_CODE_OAUTH_TOKEN"
  elif [ "$(uname)" = "Darwin" ]; then
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['claudeAiOauth']['accessToken'])" 2>/dev/null)
  elif [ -f "${HOME}/.claude/.credentials.json" ]; then
    token=$(jq -r '.claudeAiOauth.accessToken' "${HOME}/.claude/.credentials.json" 2>/dev/null)
  fi
  if [ -n "$token" ]; then
    usage_json=$(curl -s --connect-timeout 2 --max-time 3 \
      -H "Authorization: Bearer $token" \
      -H "anthropic-beta: oauth-2025-04-20" \
      "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
    if echo "$usage_json" | jq -e '.five_hour' > /dev/null 2>&1; then
      echo "$usage_json" > "$cache_file"
    else
      usage_json=""
      if [ -f "$cache_file" ]; then
        usage_json=$(cat "$cache_file" 2>/dev/null)
      fi
    fi
  fi
fi

# ===== BUILD COMPACT SEGMENTS =====

# 5h segment
compact_5h=""
if [ -n "$usage_json" ]; then
  five_hour_pct=$(echo "$usage_json" | jq -r '.five_hour.utilization // empty')
  five_hour_resets=$(echo "$usage_json" | jq -r '.five_hour.resets_at // empty')

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
    if [ -n "$five_remaining" ]; then
      c5_time=" ${five_time_with_dim}"
    fi
    compact_5h="${dim}5h${rst} ${c5_pct}${c5_time}${c5_suffix}"
  fi
fi

# 7d segment
compact_7d=""
if [ -n "$usage_json" ]; then
  seven_day_pct=$(echo "$usage_json" | jq -r '.seven_day.utilization // empty')
  seven_day_resets=$(echo "$usage_json" | jq -r '.seven_day.resets_at // empty')

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
    if [ -n "$seven_remaining" ]; then
      c7_time=" ${seven_time_with_dim}"
    fi
    compact_7d="${dim}7d${rst} ${c7_pct}${c7_time}${c7_suffix}"
  fi
fi

# Extra usage segment: "extra $4.79" or "extra>> $13.87"
compact_mo=""
if [ -n "$usage_json" ]; then
  extra_enabled=$(echo "$usage_json" | jq -r '.extra_usage.is_enabled // empty')
  if [ "$extra_enabled" = "true" ]; then
    used_credits=$(echo "$usage_json" | jq -r '.extra_usage.used_credits // empty')
    if [ -n "$used_credits" ]; then
      money_raw=$(echo "$used_credits" | awk '{printf "%.2f", $1/100}')
      money_int=$(echo "$money_raw" | sed 's/[.,].*//')
      money_frac=$(echo "$money_raw" | grep -o '[.,][0-9]*$')

      # Determine play/pause status
      mo_suffix=""
      extra_utilization=$(echo "$usage_json" | jq -r '.extra_usage.utilization // empty')
      if [ -n "$extra_utilization" ] && [ "$extra_utilization" != "null" ]; then
        extra_int=${extra_utilization%.*}
        if [ "$extra_int" -lt 100 ] 2>/dev/null; then
          if [ -n "$five_int" ] && [ "$five_int" -eq 100 ] 2>/dev/null; then
            mo_suffix="${bright_red}>>${rst}"
          elif [ -n "$seven_int" ] && [ "$seven_int" -eq 100 ] 2>/dev/null; then
            mo_suffix="${bright_red}>>${rst}"
          fi
        fi
      fi
      compact_mo="${dim}extra${rst}${mo_suffix} ${dim}${DOLLAR}${rst}${money_int}${dim}${money_frac}${rst}"
    fi
  fi
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

# Model segment: strip "Claude " prefix and " context" suffix for compactness
compact_model_name=$(echo "$model" | sed 's/^Claude //; s/ context)/)/g')
compact_model_colored=$(colorize_model "$compact_model_name")
compact_model=$(echo "$compact_model_colored" | sed -E "s/([0-9]+\.[0-9]+)/${dim}\1${rst}/g")

# Context segment
compact_ctx=""
if [ -n "$used_pct" ]; then
  context_int=${used_pct%.*}
  ctx_c=$(pct_color "$context_int")
  compact_ctx="${dim}context${rst} ${ctx_c}${used_pct}%${rst}"
  [ "$context_int" -ge 80 ] 2>/dev/null && compact_ctx="${compact_ctx} ${bright_red}!!${rst}"
fi

# Dir segment: trailing / signals it's a directory
compact_dir="${short_dir}${dim}/${rst}"

# Branch segment: "main" or "main*" (yellow if dirty)
compact_branch=""
if [ -n "$branch" ]; then
  if [ -n "$dirty" ]; then
    compact_branch="${yellow}${branch}*${rst}"
  else
    compact_branch="${branch}"
  fi
fi

# ===== PROGRESSIVE HIDING =====
# Claude Code appends system notifications to the right of the last statusline line.
# Reserve space so notifications (e.g. "auto mode is unavailable for your plan") aren't truncated.

NOTIFICATION_RESERVE=45

term_width=$(tput cols 2>/dev/null)
if ! [ "$term_width" -ge 40 ] 2>/dev/null; then
  term_width=""
fi

if [ -n "$term_width" ]; then
  available=$(( term_width - NOTIFICATION_RESERVE ))

  # Level 0: all segments
  compact_line=$(assemble_line "$compact_5h" "$compact_7d" "$compact_mo" "$compact_cost" "$compact_model" "$compact_ctx" "$compact_dir" "$compact_branch")

  if [ "$(visual_width "$compact_line")" -gt "$available" ]; then
    # Level 1: drop directory
    compact_line=$(assemble_line "$compact_5h" "$compact_7d" "$compact_mo" "$compact_cost" "$compact_model" "$compact_ctx" "$compact_branch")
  fi

  if [ "$(visual_width "$compact_line")" -gt "$available" ]; then
    # Level 2: drop session cost
    compact_line=$(assemble_line "$compact_5h" "$compact_7d" "$compact_mo" "$compact_model" "$compact_ctx" "$compact_branch")
  fi

  if [ "$(visual_width "$compact_line")" -gt "$available" ]; then
    # Level 3: drop extra usage (only required segments remain)
    compact_line=$(assemble_line "$compact_5h" "$compact_7d" "$compact_model" "$compact_ctx" "$compact_branch")
  fi
else
  # Fallback: no terminal width detected, show everything
  compact_line=$(assemble_line "$compact_5h" "$compact_7d" "$compact_mo" "$compact_cost" "$compact_model" "$compact_ctx" "$compact_dir" "$compact_branch")
fi

echo "$compact_line"
