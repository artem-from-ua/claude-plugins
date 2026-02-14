#!/bin/bash
# Claude Code statusline script
# Reads JSON from stdin (piped by Claude Code)
#
# Layout (two lines):
#   Line 1: ⏳ <bar> [icon] <time>   📅 <bar> [icon] <time>   💸 <status> <bar> [warning] <amount>
#   Line 2: 📁 <dir>   🌿 <branch>   🤖 <model>   📚 <ctx>%
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
#   ⏳  5-hour rate limit: progress bar, optional icon, time remaining
#   📅  7-day rate limit: progress bar, optional icon, time remaining
#         Icons: ❌ when usage =100% (limit exhausted), ⚠️ when usage >90%
#         Time format: XhYm (5h) or XdYh rounded (7d when >24h left)
#         When API returns resets_at=null (window inactive, no usage yet),
#         shows yellow "idle" instead of icon+time (bar needs time_pct to colorize)
#   💸  Extra usage (monthly billing): status icon (▶️/⏸️), progress bar, warning icon, dollar amount
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
    git_status_output=$(git -C "$cwd" status --porcelain=v1 --untracked-files=normal 2>/dev/null)
    if [ -n "$git_status_output" ]; then
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

# Build line 2 (info line)
line2="📁 ${short_dir}${git_info}${dirty_info}   🤖 ${model_colored}"

# Build line 1 (progress bars line) - will be populated later
line1=""

# Dim color for units (%, d, h, m)
dim=$(printf '\033[38;5;242m')
rst=$(printf '\033[0m')

# Context window (yellow ≥60%, red ≥80%) - goes to line 2
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
    line2="${line2}   📚 ${ctx_color}${used_pct}${dim}%${rst} 🛑"
  elif [ "$ctx_int" -ge 60 ] 2>/dev/null; then
    line2="${line2}   📚 ${ctx_color}${used_pct}${dim}%${rst} ⚠️"
  else
    line2="${line2}   📚 ${used_pct}${dim}%${rst}"
  fi
fi

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
  # Cross-platform OAuth token retrieval
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
  local normalized
  normalized=$(echo "$resets_at" | sed 's/\.[0-9]*+00:00$//' | sed 's/+00:00$//')
  if [ "$(uname)" = "Darwin" ]; then
    date -juf "%Y-%m-%dT%H:%M:%S" "$normalized" +%s 2>/dev/null
  else
    date -ud "$normalized" +%s 2>/dev/null
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
  local block="■"
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

    # Determine icon: ❌ if limit exhausted (exactly 100%), ⚠️ if >90%, none otherwise
    five_icon=""
    if [ "$five_int" -eq 100 ] 2>/dev/null; then
      five_icon="❌ "
    elif [ "$five_int" -gt 90 ] 2>/dev/null; then
      five_icon="⚠️ "
    fi

    if [ -n "$five_remaining" ]; then
      line1="${line1}⏳ ${five_bar} ${five_icon}${five_remaining}"
    else
      yellow=$(printf '\033[38;5;178m')
      line1="${line1}⏳ ${five_bar} ${yellow}idle${rst}"
    fi
  fi

  if [ -n "$seven_day_pct" ]; then
    seven_int=${seven_day_pct%.*}
    seven_remaining=$(format_time_remaining "$seven_day_resets" "1")
    seven_time_pct=$(calc_time_pct "$seven_day_resets" 604800)
    seven_bar=$(build_progress_bar "$seven_int" "$seven_time_pct" 21)

    # Determine icon: ❌ if limit exhausted (exactly 100%), ⚠️ if >90%, none otherwise
    seven_icon=""
    if [ "$seven_int" -eq 100 ] 2>/dev/null; then
      seven_icon="❌ "
    elif [ "$seven_int" -gt 90 ] 2>/dev/null; then
      seven_icon="⚠️ "
    fi

    if [ -n "$seven_remaining" ]; then
      line1="${line1}   📅 ${seven_bar} ${seven_icon}${seven_remaining}"
    else
      yellow=$(printf '\033[38;5;178m')
      line1="${line1}   📅 ${seven_bar} ${yellow}idle${rst}"
    fi
  fi

  # Extra usage block (only if enabled)
  extra_enabled=$(echo "$usage_json" | jq -r '.extra_usage.is_enabled // empty')
  if [ "$extra_enabled" = "true" ]; then
    used_credits=$(echo "$usage_json" | jq -r '.extra_usage.used_credits // empty')
    extra_utilization=$(echo "$usage_json" | jq -r '.extra_usage.utilization // empty')

    if [ -n "$used_credits" ]; then
      # Convert credits to dollars (credits / 100)
      dollars=$(echo "$used_credits" | awk '{printf "%.2f", $1/100}')

      # Determine status icon: ▶️ if 5h or 7d limit exhausted (100%), otherwise ⏸️
      status_icon="⏸️"
      if [ "$five_int" -eq 100 ] 2>/dev/null || [ "$seven_int" -eq 100 ] 2>/dev/null; then
        status_icon="▶️"
      fi

      # Start building extra usage block
      extra_block="💸 ${status_icon}"

      # Add progress bar if utilization is available (not null)
      if [ -n "$extra_utilization" ] && [ "$extra_utilization" != "null" ]; then
        extra_int=${extra_utilization%.*}

        # Calculate days in current month (UTC)
        if [ "$(uname)" = "Darwin" ]; then
          current_year=$(date -u +%Y)
          current_month=$(date -u +%m)
          days_in_month=$(date -u -v1d -v+1m -v-1d +%d 2>/dev/null)
        else
          current_year=$(date -u +%Y)
          current_month=$(date -u +%m)
          days_in_month=$(date -u -d "$(date -u +%Y-%m-01) +1 month -1 day" +%d 2>/dev/null)
        fi
        days_in_month=${days_in_month:-30}

        # Calculate month time percentage by seconds
        # Start of current month (UTC midnight)
        if [ "$(uname)" = "Darwin" ]; then
          month_start=$(date -ju -f "%Y-%m-%d %H:%M:%S" "${current_year}-${current_month}-01 00:00:00" +%s 2>/dev/null)
          # Start of next month
          next_month_start=$(date -ju -v1d -v+1m -f "%Y-%m-%d %H:%M:%S" "${current_year}-${current_month}-01 00:00:00" +%s 2>/dev/null)
        else
          month_start=$(date -u -d "${current_year}-${current_month}-01 00:00:00" +%s 2>/dev/null)
          next_month_start=$(date -u -d "$(date -u +%Y-%m-01) +1 month" +%s 2>/dev/null)
        fi

        # Current time (UTC)
        now_utc=$(date -u +%s)

        # Calculate elapsed and total seconds in month
        month_elapsed=$((now_utc - month_start))
        month_total=$((next_month_start - month_start))

        # Time percentage
        if [ "$month_total" -gt 0 ]; then
          month_time_pct=$((month_elapsed * 100 / month_total))
        else
          month_time_pct=0
        fi

        # Build progress bar with month-specific length
        extra_bar=$(build_progress_bar "$extra_int" "$month_time_pct" "$days_in_month")

        # Determine warning icon
        extra_warning=""
        if [ "$extra_int" -eq 100 ] 2>/dev/null; then
          extra_warning=" ❌"
        elif [ "$extra_int" -gt 90 ] 2>/dev/null; then
          extra_warning=" ⚠️"
        fi

        extra_block="${extra_block} ${extra_bar}${extra_warning}"
      fi

      # Add dollar amount
      extra_block="${extra_block} ${dollars}"

      line1="${line1}   ${extra_block}"
    fi
  fi
fi

# Output two lines
echo "$line1"
echo "$line2"
