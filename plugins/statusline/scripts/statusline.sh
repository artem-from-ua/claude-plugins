#!/bin/bash
# Claude Code statusline script
# Reads JSON from stdin (piped by Claude Code)
#
# Layout:
#   📁 <dir>   🌿 <branch>   🤖 <model>   📚 <ctx>%   ⏳ <5h>% <bar> <time>   📅 <7d>% <bar> <time>
#
# Fields:
#   📁  Current directory (basename)
#   🌿  Git branch (if in a repo); yellow + ⚠️  when dirty (uncommitted changes or
#         untracked files)
#   🤖  Model name, color-coded: Opus=red, Sonnet=green, Haiku=blue
#   📚  Context window usage %:
#         <60%  — default (no color)
#         ≥60%  — yellow + ⚠️  — first compression likely, wrap up current task
#         ≥80%  — red + 🛑 — context degraded, start a new session
#   ⏳  5-hour rate limit: usage%, progress bar, time remaining
#   📅  7-day rate limit: usage%, progress bar, time remaining
#         Time format: XhYm (5h) or XdYh rounded (7d when >24h left)
#         When API returns resets_at=null (window inactive, no usage yet),
#         shows yellow "idle" instead of bar+time (bar needs time_pct to colorize)
#
# Progress bar (20 blocks for 5h, 21 blocks for 7d):
#   When usage ≤ time elapsed (under/on pace):
#     dark gray  — consumed portion
#     green      — buffer (ahead of schedule)
#     dark blue  — remaining to 100%
#   When usage > time elapsed (over pace):
#     dark gray  — time elapsed portion
#     red        — over-consumption
#     dark blue  — remaining to 100%
#
# Dim units: %, d, h, m — slightly muted to reduce visual noise
#
# Data source: Anthropic OAuth usage API, cached for 60s

input=$(cat)

# Extract basic fields from statusline JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Git branch + dirty indicator
git_info=""
dirty_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    if ! git -C "$cwd" diff-index --quiet HEAD -- 2>/dev/null || [ -n "$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null)" ]; then
      git_info="   🌿 $(printf '\033[38;5;178m')${branch}$(printf '\033[0m')"
      dirty_info=" ⚠️"
    else
      git_info="   🌿 ${branch}"
    fi
  fi
fi

short_dir=$(basename "$cwd")

# Colorize model name (only the model name part, not "Claude" or version)
colorize_model() {
  local name="$1"
  local color=""
  local keyword=""
  if echo "$name" | grep -qi "opus"; then
    color=$(printf '\033[38;5;167m'); keyword="Opus"
  elif echo "$name" | grep -qi "sonnet"; then
    color=$(printf '\033[38;5;71m'); keyword="Sonnet"
  elif echo "$name" | grep -qi "haiku"; then
    color=$(printf '\033[38;5;33m'); keyword="Haiku"
  fi
  if [ -n "$color" ]; then
    echo "$name" | sed "s/$keyword/${color}${keyword}$(printf '\033[0m')/"
  else
    echo "$name"
  fi
}
model_colored=$(colorize_model "$model")

# Build base status
status="📁 ${short_dir}${git_info}${dirty_info}   🤖 ${model_colored}"

# Dim color for units (%, d, h, m)
dim=$(printf '\033[38;5;242m')
rst=$(printf '\033[0m')

# Context window (yellow ≥60%, red ≥80%)
if [ -n "$used_pct" ]; then
  ctx_int=${used_pct%.*}
  if [ "$ctx_int" -ge 80 ] 2>/dev/null; then
    ctx_color=$(printf '\033[38;5;167m')
  elif [ "$ctx_int" -ge 60 ] 2>/dev/null; then
    ctx_color=$(printf '\033[38;5;178m')
  else
    ctx_color=""
  fi
  if [ "$ctx_int" -ge 80 ] 2>/dev/null; then
    status="${status}   📚 ${ctx_color}${used_pct}${dim}%${rst} 🛑"
  elif [ "$ctx_int" -ge 60 ] 2>/dev/null; then
    status="${status}   📚 ${ctx_color}${used_pct}${dim}%${rst} ⚠️"
  else
    status="${status}   📚 ${used_pct}${dim}%${rst}"
  fi
fi

# Fetch usage data from Anthropic API (cached for 60 seconds)
cache_file="/tmp/claude-statusline-usage-cache-$UID"
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
  token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['claudeAiOauth']['accessToken'])" 2>/dev/null)
  if [ -n "$token" ]; then
    usage_json=$(curl -s --connect-timeout 2 --max-time 3 \
      -H "Authorization: Bearer $token" \
      -H "anthropic-beta: oauth-2025-04-20" \
      "https://api.anthropic.com/api/oauth/usage")
    if [ $? -ne 0 ]; then
      usage_json=""
    fi
    if echo "$usage_json" | jq -e '.five_hour' > /dev/null 2>&1; then
      echo "$usage_json" > "$cache_file"
    else
      usage_json=""
      # Use stale cache if API failed
      if [ -f "$cache_file" ]; then
        usage_json=$(cat "$cache_file" 2>/dev/null)
      fi
    fi
  fi
fi

# Parse reset timestamp to epoch seconds
parse_reset_epoch() {
  local resets_at="$1"
  if [ -z "$resets_at" ] || [ "$resets_at" = "null" ]; then
    echo ""
    return
  fi
  # Normalize timestamp: drop fractional seconds and explicit +00:00 offset
  local normalized
  normalized=$(echo "$resets_at" | sed 's/\.[0-9]*+00:00$//' | sed 's/+00:00$//')

  # Use BSD date flags on macOS, GNU date flags elsewhere
  if [ "$(uname)" = "Darwin" ]; then
    date -j -u -f "%Y-%m-%dT%H:%M:%S" "$normalized" +%s 2>/dev/null
  else
    date -u -d "$normalized" +%s 2>/dev/null
  fi
}

# Format time remaining as human-readable string
# Args: $1=resets_at, $2=compact (if "1", round to hours when >24h)
format_time_remaining() {
  local resets_at="$1"
  local compact="$2"
  local reset_epoch
  reset_epoch=$(parse_reset_epoch "$resets_at")
  if [ -z "$reset_epoch" ]; then
    echo ""
    return
  fi
  local diff=$(( reset_epoch - now ))
  if [ "$diff" -le 0 ]; then
    echo "⏰"
    return
  fi
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  local dim=$(printf '\033[38;5;242m')
  local rst=$(printf '\033[0m')
  if [ "$compact" = "1" ] && [ "$days" -gt 0 ]; then
    if [ "$mins" -ge 30 ]; then
      hours=$(( hours + 1 ))
    fi
    echo "${days}${dim}d${rst}${hours}${dim}h${rst}"
  elif [ "$days" -gt 0 ]; then
    echo "${days}${dim}d${rst}${hours}${dim}h${rst}${mins}${dim}m${rst}"
  elif [ "$hours" -gt 0 ]; then
    echo "${hours}${dim}h${rst}${mins}${dim}m${rst}"
  else
    echo "${mins}${dim}m${rst}"
  fi
}

# Calculate time elapsed percentage for a window
# Args: $1=resets_at, $2=window_seconds
calc_time_pct() {
  local resets_at="$1"
  local window_seconds="$2"
  local reset_epoch
  reset_epoch=$(parse_reset_epoch "$resets_at")
  if [ -z "$reset_epoch" ]; then
    echo "0"
    return
  fi
  local diff=$(( reset_epoch - now ))
  if [ "$diff" -le 0 ]; then
    echo "100"
    return
  fi
  local elapsed=$(( window_seconds - diff ))
  if [ "$elapsed" -le 0 ]; then
    echo "0"
    return
  fi
  echo $(( elapsed * 100 / window_seconds ))
}

# Build progress bar
# Args: $1=usage_pct (0-100), $2=time_pct (0-100), $3=bar_length (default 20)
# Colors: dark gray=used, green/red=gap, dark blue=remaining
build_progress_bar() {
  local u_pct="$1"
  local t_pct="$2"
  local total="${3:-20}"
  # Clamp percentages to 0-100
  [ "$u_pct" -lt 0 ] 2>/dev/null && u_pct=0; [ "$u_pct" -gt 100 ] 2>/dev/null && u_pct=100
  [ "$t_pct" -lt 0 ] 2>/dev/null && t_pct=0; [ "$t_pct" -gt 100 ] 2>/dev/null && t_pct=100
  # Convert pct to blocks with rounding: (pct * total + 50) / 100
  local u_blocks=$(( (u_pct * total + 50) / 100 ))
  local t_blocks=$(( (t_pct * total + 50) / 100 ))
  local bar=""
  local block="▉"
  # ANSI colors (use printf to produce real escape bytes)
  local dark_gray=$(printf '\033[38;5;236m')
  local bright_green=$(printf '\033[38;5;71m')
  local bright_red=$(printf '\033[38;5;167m')
  local dark_blue=$(printf '\033[38;5;23m')
  local reset=$(printf '\033[0m')

  if [ "$u_blocks" -le "$t_blocks" ]; then
    # Usage <= Time: gray[0..u] green[u..t] blue[t..100]
    local i=0
    while [ "$i" -lt "$total" ]; do
      if [ "$i" -lt "$u_blocks" ]; then
        bar="${bar}${dark_gray}${block}"
      elif [ "$i" -lt "$t_blocks" ]; then
        bar="${bar}${bright_green}${block}"
      else
        bar="${bar}${dark_blue}${block}"
      fi
      i=$(( i + 1 ))
    done
  else
    # Usage > Time: gray[0..t] red[t..u] blue[u..100]
    local i=0
    while [ "$i" -lt "$total" ]; do
      if [ "$i" -lt "$t_blocks" ]; then
        bar="${bar}${dark_gray}${block}"
      elif [ "$i" -lt "$u_blocks" ]; then
        bar="${bar}${bright_red}${block}"
      else
        bar="${bar}${dark_blue}${block}"
      fi
      i=$(( i + 1 ))
    done
  fi
  bar="${bar}${reset}"
  echo -n "$bar"
}

if [ -n "$usage_json" ]; then
  five_hour_pct=$(echo "$usage_json" | jq -r '.five_hour.utilization // empty')
  five_hour_resets=$(echo "$usage_json" | jq -r '.five_hour.resets_at // empty')
  seven_day_pct=$(echo "$usage_json" | jq -r '.seven_day.utilization // empty')
  seven_day_resets=$(echo "$usage_json" | jq -r '.seven_day.resets_at // empty')

  if [ -n "$five_hour_pct" ]; then
    five_int=${five_hour_pct%.*}
    five_remaining=$(format_time_remaining "$five_hour_resets" "0")
    five_time_pct=$(calc_time_pct "$five_hour_resets" 18000)
    five_bar=$(build_progress_bar "$five_int" "$five_time_pct")
    if [ -n "$five_remaining" ]; then
      status="${status}   ⏳ ${five_int}${dim}%${rst} ${five_bar} ${five_remaining}"
    else
      yellow=$(printf '\033[38;5;178m')
      status="${status}   ⏳ ${five_int}${dim}%${rst} ${yellow}idle${rst}"
    fi
  fi

  if [ -n "$seven_day_pct" ]; then
    seven_int=${seven_day_pct%.*}
    seven_remaining=$(format_time_remaining "$seven_day_resets" "1")
    seven_time_pct=$(calc_time_pct "$seven_day_resets" 604800)
    seven_bar=$(build_progress_bar "$seven_int" "$seven_time_pct" 21)
    if [ -n "$seven_remaining" ]; then
      status="${status}   📅 ${seven_int}${dim}%${rst} ${seven_bar} ${seven_remaining}"
    else
      yellow=$(printf '\033[38;5;178m')
      status="${status}   📅 ${seven_int}${dim}%${rst} ${yellow}idle${rst}"
    fi
  fi
fi

echo "$status"
