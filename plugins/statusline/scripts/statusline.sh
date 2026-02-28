#!/bin/bash
# Claude Code statusline script (THREE-LINE LAYOUT)
# Reads JSON from stdin (piped by Claude Code)
#
# Layout (three lines):
#   Line 1: 5h/10m････[bar-30]･[ind]･[time-8]   🤖･[model<padded>]   ✏️･[session]
#   Line 2: 7d/6h･･････[bar-28]･[ind]･[time-8]   📚･[ctx%<padded>]    📁･[dir]
#   Line 3: 1M/1d･[icon]･[pad][bar-N]･[ind]･[money-8]   💵･$X.XX        🌿･[branch]
#
# Col 2 is padded to model display width so col 3 aligns vertically.
#
# Progress bar resolution:
#   5h:    30 blocks → 10 minutes per block (5h / 30 = 600s)
#   7d:    28 blocks → 6 hours per block (7d / 28 = 21600s)
#   Extra: N blocks (days in month) → 1 day per block
#
# Data source: Anthropic OAuth usage API, cached for 60s

input=$(cat)

# ANSI colors
rst=$(printf '\033[0m')
dim=$(printf '\033[38;5;242m')
very_dim=$(printf '\033[38;5;237m')
dark_gray=$(printf '\033[38;5;236m')
bright_green=$(printf '\033[38;5;71m')
bright_red=$(printf '\033[38;5;167m')
dark_blue=$(printf '\033[38;5;23m')
yellow=$(printf '\033[38;5;178m')

# Separator
SEP="${very_dim}･${rst}"

# Extract basic fields from statusline JSON
cwd=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Git branch + dirty indicator
branch=""
dirty=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    git_status_output=$(git -C "$cwd" status --porcelain=v1 --untracked-files=normal 2>/dev/null)
    if [ -n "$git_status_output" ]; then
      dirty="⚠"
    fi
  fi
fi

short_dir=$(basename "$cwd")

# Calculate terminal display width (handles wide chars/emoji via python3 unicodedata)
calc_display_width() {
  python3 -c "
import unicodedata, sys
s = sys.argv[1]
w = sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s)
print(w)
" "$1" 2>/dev/null || echo "${#1}"
}

# Format resolution display (e.g., "5h/10m" with /10m dimmed)
format_resolution() {
  local interval=$1
  local resolution=$2
  echo "${interval}${dim}/${resolution}${rst}"
}

# Get limit indicator based on usage vs time pacing
get_limit_indicator() {
  local usage_pct=$1
  local time_pct=$2
  local usage_int=${usage_pct%.*}
  local time_int=${time_pct%.*}

  if [ "$usage_int" -eq 100 ] 2>/dev/null; then
    echo "❌"
  elif [ "$usage_int" -gt 90 ] 2>/dev/null && [ "$time_int" -le 90 ] 2>/dev/null; then
    echo "⚠️"
  else
    echo "${very_dim}･･${rst}"
  fi
}

# Build progress bar
build_progress_bar() {
  local u_pct="$1"
  local t_pct="$2"
  local total="${3:-20}"

  u_pct=${u_pct%.*}
  t_pct=${t_pct%.*}

  [ "$u_pct" -lt 0 ] 2>/dev/null && u_pct=0; [ "$u_pct" -gt 100 ] 2>/dev/null && u_pct=100
  [ "$t_pct" -lt 0 ] 2>/dev/null && t_pct=0; [ "$t_pct" -gt 100 ] 2>/dev/null && t_pct=100

  local u_blocks=$(( (u_pct * total + 50) / 100 ))
  local t_blocks=$(( (t_pct * total + 50) / 100 ))
  local bar=""
  local block="■"
  local block_ind="■̿"  # ■ + U+033F combining double overline = current-time indicator

  # Determine position of current-time indicator:
  # 1. green zone exists (t > u): last green = t_blocks-1
  # 2. red zone exists (u > t):   first red  = t_blocks
  # 3. only blue (u == t < total): first blue = u_blocks
  # 4. only gray (u == t == total): last gray = total-1
  local ind_pos
  if [ "$t_blocks" -gt "$u_blocks" ]; then
    ind_pos=$(( t_blocks - 1 ))
  elif [ "$u_blocks" -gt "$t_blocks" ]; then
    ind_pos=$t_blocks
  elif [ "$u_blocks" -lt "$total" ]; then
    ind_pos=$u_blocks
  else
    ind_pos=$(( total - 1 ))
  fi

  if [ "$u_blocks" -le "$t_blocks" ]; then
    local i=0
    while [ "$i" -lt "$total" ]; do
      local b="$block"
      [ "$i" -eq "$ind_pos" ] && b="$block_ind"
      if [ "$i" -lt "$u_blocks" ]; then
        bar="${bar}${dark_gray}${b}"
      elif [ "$i" -lt "$t_blocks" ]; then
        bar="${bar}${bright_green}${b}"
      else
        bar="${bar}${dark_blue}${b}"
      fi
      i=$(( i + 1 ))
    done
  else
    local i=0
    while [ "$i" -lt "$total" ]; do
      local b="$block"
      [ "$i" -eq "$ind_pos" ] && b="$block_ind"
      if [ "$i" -lt "$t_blocks" ]; then
        bar="${bar}${dark_gray}${b}"
      elif [ "$i" -lt "$u_blocks" ]; then
        bar="${bar}${bright_red}${b}"
      else
        bar="${bar}${dark_blue}${b}"
      fi
      i=$(( i + 1 ))
    done
  fi
  bar="${bar}${rst}"
  echo -n "$bar"
}

# Colorize model name (strips leading "Claude " prefix)
colorize_model() {
  local name="$1"
  # Strip "Claude " prefix
  name=$(echo "$name" | sed 's/^Claude //')
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
    echo "$name" | sed "s/$keyword/${color}${keyword}${rst}/"
  else
    echo "$name"
  fi
}

# Colorize git branch: dim slash, color prefix by type
colorize_branch() {
  local branch="$1"
  # Colors for branch prefixes
  local c_feature=$(printf '\033[38;5;114m')   # green
  local c_fix=$(printf '\033[38;5;203m')        # red
  local c_release=$(printf '\033[38;5;221m')    # yellow
  local c_refactor=$(printf '\033[38;5;110m')   # blue
  local c_default=$(printf '\033[38;5;245m')    # gray

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
    echo "⏰"
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

# Calculate time elapsed percentage
calc_time_pct() {
  local resets_at="$1"
  local window_seconds="$2"
  local reset_epoch
  reset_epoch=$(parse_reset_epoch "$resets_at")
  if [ -z "$reset_epoch" ]; then
    echo "0"
    return
  fi
  local now=$(date +%s)
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

# ===== BUILD LINE 1: 5h limit + model + directory =====

resolution_5h=$(format_resolution "5h" "10m")
padding_5h="${very_dim}････${rst}"

if [ -n "$usage_json" ]; then
  five_hour_pct=$(echo "$usage_json" | jq -r '.five_hour.utilization // empty')
  five_hour_resets=$(echo "$usage_json" | jq -r '.five_hour.resets_at // empty')

  if [ -n "$five_hour_pct" ]; then
    five_int=${five_hour_pct%.*}
    five_remaining=$(format_time_remaining "$five_hour_resets" 2)
    five_time_pct=$(calc_time_pct "$five_hour_resets" 18000)
    five_bar=$(build_progress_bar "$five_int" "$five_time_pct" 30)
    five_indicator=$(get_limit_indicator "$five_int" "$five_time_pct")

    # Apply dim to units: ~, h, m, d
    five_time_with_dim=""
    for ((i=0; i<${#five_remaining}; i++)); do
      char="${five_remaining:$i:1}"
      case "$char" in
        '~'|h|m|d) five_time_with_dim="${five_time_with_dim}${dim}${char}${rst}" ;;
        *) five_time_with_dim="${five_time_with_dim}${char}" ;;
      esac
    done

    five_display_width=$(calc_display_width "$five_remaining")
    five_padding=$((8 - five_display_width))
    five_time_fmt="${five_time_with_dim}$(printf "%${five_padding}s" "")"

    five_block="${resolution_5h}${padding_5h}${five_bar}${SEP}${five_indicator}${SEP}${five_time_fmt}"
  else
    five_block=""
  fi
else
  five_block=""
fi

# Model: colorize keyword, dim version number, replace spaces with SEP
model_colored=$(colorize_model "$model")
model_with_dim=$(echo "$model_colored" | sed -E "s/([0-9]+\.[0-9]+)/${dim}\1${rst}/g")
model_display=$(echo "$model_with_dim" | sed "s/ /${SEP}/g")
# Visible terminal width of "🤖･model" (strip ANSI then measure)
model_visible=$(echo "🤖･${model_display}" | sed $'s/\x1b\\[[0-9;]*m//g')
model_visible_width=$(calc_display_width "$model_visible")

# Directory: replace spaces with SEP
dir_display=$(echo "$short_dir" | sed "s/ /${SEP}/g")

# ===== BUILD LINE 2: 7d limit + context + branch =====

resolution_7d=$(format_resolution "7d" "6h")
padding_7d=$(printf "${very_dim}%s${rst}" "･······")

if [ -n "$usage_json" ]; then
  seven_day_pct=$(echo "$usage_json" | jq -r '.seven_day.utilization // empty')
  seven_day_resets=$(echo "$usage_json" | jq -r '.seven_day.resets_at // empty')

  if [ -n "$seven_day_pct" ]; then
    seven_int=${seven_day_pct%.*}
    seven_remaining=$(format_time_remaining "$seven_day_resets" 48)
    seven_time_pct=$(calc_time_pct "$seven_day_resets" 604800)
    seven_bar=$(build_progress_bar "$seven_int" "$seven_time_pct" 28)
    seven_indicator=$(get_limit_indicator "$seven_int" "$seven_time_pct")

    # Apply dim to units
    seven_time_with_dim=""
    for ((i=0; i<${#seven_remaining}; i++)); do
      char="${seven_remaining:$i:1}"
      case "$char" in
        '~'|h|m|d) seven_time_with_dim="${seven_time_with_dim}${dim}${char}${rst}" ;;
        *) seven_time_with_dim="${seven_time_with_dim}${char}" ;;
      esac
    done

    seven_display_width=$(calc_display_width "$seven_remaining")
    seven_padding=$((8 - seven_display_width))
    seven_time_fmt="${seven_time_with_dim}$(printf "%${seven_padding}s" "")"

    seven_block="${resolution_7d}${padding_7d}${seven_bar}${SEP}${seven_indicator}${SEP}${seven_time_fmt}"
  else
    seven_block=""
  fi
else
  seven_block=""
fi

# Context widget
context_widget=""
if [ -n "$used_pct" ]; then
  context_int=${used_pct%.*}
  if [ "$context_int" -ge 80 ] 2>/dev/null; then
    ctx_color=$(printf '\033[38;5;167m')
    ctx_suffix="${SEP}🛑"
  elif [ "$context_int" -ge 60 ] 2>/dev/null; then
    ctx_color=$(printf '\033[38;5;178m')
    ctx_suffix="${SEP}⚠️"
  else
    ctx_color=""
    ctx_suffix=""
  fi
  context_widget="📚${SEP}${ctx_color}${used_pct}${dim}%${rst}${ctx_suffix}"
fi
# Visible terminal width of "📚･ctx%" — build plain string for measurement
if [ -n "$used_pct" ]; then
  ctx_plain="📚･${used_pct}%"
  if [ "$context_int" -ge 80 ] 2>/dev/null; then
    ctx_plain="${ctx_plain}･🛑"
  elif [ "$context_int" -ge 60 ] 2>/dev/null; then
    ctx_plain="${ctx_plain}･⚠️"
  fi
  ctx_visible_width=$(calc_display_width "$ctx_plain")
else
  ctx_visible_width=0
fi

# ===== COLUMN ALIGNMENT =====
# Col 2 width = max(model_visible_width, ctx_visible_width, session_cost_visible_width)
# We pad col 2 with spaces so col 3 starts at the same column in all lines.
# session cost widget: "💵･$X.XX" → emoji(2)+sep(1)+dollar(1)+digits — computed below after extra block
# For now use a minimum of model width; we'll finalize after building session cost.

# Col 2 separator between col1 and col2 is "   " (3 spaces)
COL2_SEP="   "

# ===== BUILD LINE 3: Extra usage + session cost =====

resolution_1m=$(format_resolution "1M" "1d")

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

# Padding based on days in month: 31→1, 30→2, 29→3, 28→4
padding_extra_count=$((32 - days_in_month))
padding_extra=$(printf "${very_dim}%s${rst}" "$(printf '･%.0s' $(seq 1 $padding_extra_count))")

# Determine status icon (play/pause)
status_icon="⏸️"
if [ -n "$usage_json" ]; then
  extra_enabled=$(echo "$usage_json" | jq -r '.extra_usage.is_enabled // empty')
  if [ "$extra_enabled" = "true" ]; then
    extra_utilization=$(echo "$usage_json" | jq -r '.extra_usage.utilization // empty')
    if [ -n "$extra_utilization" ] && [ "$extra_utilization" != "null" ]; then
      extra_int=${extra_utilization%.*}
      if [ "$extra_int" -lt 100 ] 2>/dev/null; then
        if [ "$five_int" -eq 100 ] 2>/dev/null || [ "$seven_int" -eq 100 ] 2>/dev/null; then
          status_icon="▶️"
        fi
      fi
    fi
  fi
fi

# Build extra block
if [ -n "$usage_json" ]; then
  extra_enabled=$(echo "$usage_json" | jq -r '.extra_usage.is_enabled // empty')
  if [ "$extra_enabled" = "true" ]; then
    used_credits=$(echo "$usage_json" | jq -r '.extra_usage.used_credits // empty')
    extra_utilization=$(echo "$usage_json" | jq -r '.extra_usage.utilization // empty')

    if [ -n "$used_credits" ]; then
      # Money formatting
      money_raw=$(echo "$used_credits" | awk '{printf "%.2f", $1/100}')
      money_int=$(echo "$money_raw" | sed 's/[.,].*//')
      money_frac=$(echo "$money_raw" | grep -o '[.,][0-9]*$')

      # Calculate visible length (without ANSI codes)
      money_visible="¤${money_int}${money_frac}"
      money_visible_len=$(printf "%s" "$money_visible" | wc -m | tr -d ' ')
      # Pad to 8 chars (11 total - 3 spaces added in line3 before branch emoji)
      money_padding=$((8 - money_visible_len))
      money_spaces=""
      for ((i=0; i<money_padding; i++)); do money_spaces="${money_spaces} "; done
      money_fmt="${dim}¤${rst}${money_int}${dim}${money_frac}${rst}${money_spaces}"

      # Progress bar
      if [ -n "$extra_utilization" ] && [ "$extra_utilization" != "null" ]; then
        extra_int=${extra_utilization%.*}

        # Calculate month time percentage
        if [ "$(uname)" = "Darwin" ]; then
          month_start=$(date -ju -f "%Y-%m-%d %H:%M:%S" "${current_year}-${current_month}-01 00:00:00" +%s 2>/dev/null)
          next_month_start=$(date -ju -v1d -v+1m -f "%Y-%m-%d %H:%M:%S" "${current_year}-${current_month}-01 00:00:00" +%s 2>/dev/null)
        else
          month_start=$(date -u -d "${current_year}-${current_month}-01 00:00:00" +%s 2>/dev/null)
          next_month_start=$(date -u -d "$(date -u +%Y-%m-01) +1 month" +%s 2>/dev/null)
        fi

        now_utc=$(date -u +%s)
        month_elapsed=$((now_utc - month_start))
        month_total=$((next_month_start - month_start))

        if [ "$month_total" -gt 0 ]; then
          month_time_pct=$((month_elapsed * 100 / month_total))
        else
          month_time_pct=0
        fi

        extra_bar=$(build_progress_bar "$extra_int" "$month_time_pct" "$days_in_month")
        extra_indicator=$(get_limit_indicator "$extra_int" "$month_time_pct")

        extra_block="${resolution_1m}${SEP}${status_icon}${padding_extra}${extra_bar}${SEP}${extra_indicator}${SEP}${money_fmt}"
      else
        extra_block="${resolution_1m}${SEP}${status_icon}${padding_extra}                              ${SEP}${money_fmt}"
      fi
    else
      extra_block="                                                    "
    fi
  else
    extra_block="                                                    "
  fi
else
  extra_block="                                                    "
fi

# Session cost widget: 💵･$X.XX  (from total_cost_usd in stdin JSON)
session_cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
session_cost_widget=""
session_cost_visible_width=0
if [ -n "$session_cost_usd" ] && [ "$session_cost_usd" != "null" ]; then
  # Convert JSON dot-decimal to locale decimal separator, then format with awk
  dec_sep=$(printf "%.1f" 1 | tr -d '01')
  cost_locale=$(echo "$session_cost_usd" | sed "s/\./${dec_sep}/")
  cost_fmt=$(echo "$cost_locale" | awk '{printf "%.2f", $1}')
  cost_int=$(echo "$cost_fmt" | sed 's/[.,].*//')
  cost_frac=$(echo "$cost_fmt" | grep -o '[.,][0-9]*$')
  session_cost_widget="💵${SEP}${dim}\$${rst}${cost_int}${dim}${cost_frac}${rst}"
  session_cost_visible_width=$(calc_display_width "💵･\$${cost_int}${cost_frac}" 2>/dev/null || echo $(( 3 + 1 + ${#cost_int} + ${#cost_frac} )))
fi

# Git branch widget
branch_widget=""
if [ -n "$branch" ]; then
  branch_colored=$(colorize_branch "$branch")
  branch_display=$(echo "$branch_colored" | sed "s/ /${SEP}/g")
  if [ -n "$dirty" ]; then
    branch_widget="🌿${SEP}${branch_display}${SEP}⚠️"
  else
    branch_widget="🌿${SEP}${branch_display}"
  fi
fi

# ===== SESSION NAME WIDGET =====
# Reverse file reader: tac (Linux) / tail -r (macOS)
reverse_file() {
  if command -v tac > /dev/null 2>&1; then
    tac "$1"
  else
    tail -r "$1"
  fi
}

# Extract session name with cache (TTL 300s)
session_widget=""
session_name=""
session_style=""  # "custom" or "dimmed"
if [ -n "$session_id" ]; then
  session_cache="/tmp/claude-statusline-session-${UID}-${session_id}"
  session_cache_valid=false

  if [ -f "$session_cache" ]; then
    if [ "$(uname)" = "Darwin" ]; then
      scache_mtime=$(stat -f %m "$session_cache" 2>/dev/null || echo 0)
    else
      scache_mtime=$(stat -c %Y "$session_cache" 2>/dev/null || echo 0)
    fi
    scache_age=$(( $(date +%s) - scache_mtime ))
    if [ "$scache_age" -lt 300 ]; then
      session_cache_valid=true
    fi
  fi

  if [ "$session_cache_valid" = true ]; then
    cached_value=$(cat "$session_cache" 2>/dev/null)
    session_style="${cached_value%%:*}"
    session_name="${cached_value#*:}"
  else
    # Try extracting from transcript JSONL
    if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
      # Look for custom name (from /rename): last summary entry
      summary_line=$(reverse_file "$transcript_path" 2>/dev/null | grep -m1 '"type":"summary"')
      if [ -n "$summary_line" ]; then
        session_name=$(echo "$summary_line" | jq -r '.summary // empty' 2>/dev/null)
        if [ -n "$session_name" ]; then
          session_style="custom"
          echo "custom:${session_name}" > "$session_cache"
        fi
      fi

      # Fallback: slug from JSONL
      if [ -z "$session_name" ]; then
        slug_line=$(reverse_file "$transcript_path" 2>/dev/null | grep -m1 '"slug"')
        if [ -n "$slug_line" ]; then
          session_name=$(echo "$slug_line" | jq -r '.slug // empty' 2>/dev/null)
          if [ -n "$session_name" ]; then
            session_style="dimmed"
            echo "dimmed:${session_name}" > "$session_cache"
          fi
        fi
      fi
    fi

    # Final fallback: first part of session_id
    if [ -z "$session_name" ]; then
      session_name="${session_id%%-*}"
      session_style="dimmed"
      echo "dimmed:${session_name}" > "$session_cache"
    fi
  fi

  # Build widget
  if [ "$session_style" = "custom" ]; then
    session_display=$(echo "$session_name" | sed "s/ /${SEP}/g")
    session_widget="✏️${SEP}${session_display}"
  else
    session_display=$(echo "$session_name" | sed "s/ /${SEP}/g")
    session_widget="✏️${SEP}${dim}${session_display}${rst}"
  fi
fi

# ===== COLUMN 2 ALIGNMENT =====
# All widths are full terminal column widths of the col2 widget string
col2_model_w=$model_visible_width
col2_ctx_w=$ctx_visible_width
col2_cost_w=$session_cost_visible_width

# Find max width
col2_max=$col2_model_w
[ "$col2_ctx_w" -gt "$col2_max" ] && col2_max=$col2_ctx_w
[ "$col2_cost_w" -gt "$col2_max" ] && col2_max=$col2_cost_w

# Padding for each
pad_to() {
  local diff=$(( $2 - $1 ))
  [ "$diff" -gt 0 ] && printf "%${diff}s" "" || true
}

model_pad=$(pad_to "$col2_model_w" "$col2_max")
ctx_pad=$(pad_to "$col2_ctx_w" "$col2_max")
cost_pad=$(pad_to "$col2_cost_w" "$col2_max")

# ===== ASSEMBLE LINES =====

# Line 1: bar + "   🤖･model<pad>   ✏️･session"
if [ -n "$session_widget" ]; then
  line1="${five_block}${COL2_SEP}🤖${SEP}${model_display}${model_pad}${COL2_SEP}${session_widget}"
else
  line1="${five_block}${COL2_SEP}🤖${SEP}${model_display}"
fi

# Line 2: bar + "   📚･ctx%<pad>   📁･dir"
if [ -z "$context_widget" ]; then
  ctx_placeholder=$(printf "%${col2_max}s" "")
else
  ctx_placeholder="${context_widget}${ctx_pad}"
fi
line2="${seven_block}${COL2_SEP}${ctx_placeholder}${COL2_SEP}📁${SEP}${dir_display}"

# Line 3: extra bar + "   💵･$X.XX<pad>   🌿･branch"
if [ -n "$session_cost_widget" ] && [ -n "$branch_widget" ]; then
  line3="${extra_block}${COL2_SEP}${session_cost_widget}${cost_pad}${COL2_SEP}${branch_widget}"
elif [ -n "$session_cost_widget" ]; then
  line3="${extra_block}${COL2_SEP}${session_cost_widget}"
elif [ -n "$branch_widget" ]; then
  cost_placeholder=$(printf "%${col2_max}s" "")
  line3="${extra_block}${COL2_SEP}${cost_placeholder}${COL2_SEP}${branch_widget}"
else
  line3="${extra_block}"
fi

# Output three lines
echo "$line1"
echo "$line2"
echo "$line3"
