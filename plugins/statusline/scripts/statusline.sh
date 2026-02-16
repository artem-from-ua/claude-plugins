#!/bin/bash
# Claude Code statusline script (THREE-LINE LAYOUT)
# Reads JSON from stdin (piped by Claude Code)
#
# Layout (three lines) - classic preset:
#   Line 1: 5h/10m････[bar-30]･[ind]･[pct]･[time-11]   🤖･[model]   📚･[ctx]%
#   Line 2: 7d/6h･･･････[bar-28]･[ind]･[pct]･[time-11]   📁･[dir]
#   Line 3: 1M/1d･[icon]･[padding][bar-N]･[ind]･[money-11]   🌿･[branch]
#
# Layout (three lines) - text preset:
#   Line 1: 5h: 73% resets 2h14m   MDL:･Opus･4.6   CTX:･42%
#   Line 2: 7d: 45% resets 3d5h   DIR:･my-project
#   Line 3: 1M: ⏸️ ¤4.79   BR:･main
#
# Config: ~/.claude/statusline.json
#   {"preset": "classic"|"text", "emojis": bool, "progress_bars": bool}
#
# Progress bar resolution:
#   5h:    30 blocks → 10 minutes per block (5h / 30 = 600s)
#   7d:    28 blocks → 6 hours per block (7d / 28 = 21600s)
#   Extra: N blocks (days in month) → 1 day per block
#
# Data source: Anthropic OAuth usage API, cached for 60s

input=$(cat)

# Load config from ~/.claude/statusline.json
config_file="$HOME/.claude/statusline.json"
cfg_preset="classic"
cfg_emojis=""
cfg_progress_bars=""

if [ -f "$config_file" ]; then
  cfg_preset=$(jq -r '.preset // "classic"' "$config_file" 2>/dev/null)
  cfg_emojis=$(jq -r 'if has("emojis") then .emojis | tostring else "unset" end' "$config_file" 2>/dev/null)
  cfg_progress_bars=$(jq -r 'if has("progress_bars") then .progress_bars | tostring else "unset" end' "$config_file" 2>/dev/null)
  # Fallback if jq failed (invalid JSON)
  [ -z "$cfg_preset" ] && cfg_preset="classic"
fi

# Apply preset defaults, then overrides
case "$cfg_preset" in
  text)
    use_emojis=false
    use_progress_bars=false
    ;;
  *)
    use_emojis=true
    use_progress_bars=true
    ;;
esac

# Explicit overrides take precedence (skip if "unset" = not in config)
[ "$cfg_emojis" = "true" ] && use_emojis=true
[ "$cfg_emojis" = "false" ] && use_emojis=false
[ "$cfg_progress_bars" = "true" ] && use_progress_bars=true
[ "$cfg_progress_bars" = "false" ] && use_progress_bars=false

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

# Icons (emoji or text based on config)
if [ "$use_emojis" = "true" ]; then
  ICON_MODEL="🤖"; ICON_CTX="📚"
  ICON_DIR="📁"; ICON_BRANCH="🌿"
  ICON_DIRTY="⚠"; ICON_DIRTY_WARN="⚠️"
  ICON_CTX_WARN_HIGH="🛑"; ICON_CTX_WARN_MED="⚠️"
  ICON_PAUSE="⏸️"; ICON_PLAY="▶️"
  ICON_EXHAUSTED="❌"; ICON_WARN="⚠️"
else
  ICON_MODEL="MDL:"; ICON_CTX="CTX:"
  ICON_DIR="DIR:"; ICON_BRANCH="BR:"
  ICON_DIRTY="*"; ICON_DIRTY_WARN="*"
  ICON_CTX_WARN_HIGH="!!"; ICON_CTX_WARN_MED="!"
  ICON_PAUSE="||"; ICON_PLAY=">>"
  ICON_EXHAUSTED="XX"; ICON_WARN="!!"
fi

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
      dirty="$ICON_DIRTY"
    fi
  fi
fi

short_dir=$(basename "$cwd")

# Calculate display width (visual width in terminal, handles wide characters)
# ⏰ (alarm clock emoji) takes 2 columns, regular ASCII takes 1
calc_display_width() {
  local str="$1"
  local char_count=${#str}
  # Check if string contains ⏰ (wide emoji, takes 2 terminal columns)
  if echo "$str" | grep -q '⏰'; then
    echo $((char_count + 1))
  else
    echo "$char_count"
  fi
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
    echo "$ICON_EXHAUSTED"
  elif [ "$usage_int" -gt 90 ] 2>/dev/null && [ "$time_int" -le 90 ] 2>/dev/null; then
    echo "$ICON_WARN"
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

  if [ "$u_blocks" -le "$t_blocks" ]; then
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
  bar="${bar}${rst}"
  echo -n "$bar"
}

# Colorize model name
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
    if [ "$use_emojis" = "true" ]; then
      echo "⏰"
    else
      echo "now"
    fi
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

# ===== BUILD LINE 1: 5h limit + model + context =====

five_block=""
if [ -n "$usage_json" ]; then
  five_hour_pct=$(echo "$usage_json" | jq -r '.five_hour.utilization // empty')
  five_hour_resets=$(echo "$usage_json" | jq -r '.five_hour.resets_at // empty')

  if [ -n "$five_hour_pct" ]; then
    five_int=${five_hour_pct%.*}
    five_remaining=$(format_time_remaining "$five_hour_resets" 2)
    five_time_pct=$(calc_time_pct "$five_hour_resets" 18000)
    five_time_with_dim=$(dim_time_units "$five_remaining")

    if [ "$use_progress_bars" = "true" ]; then
      resolution_5h=$(format_resolution "5h" "10m")
      padding_5h="${very_dim}････${rst}"
      five_bar=$(build_progress_bar "$five_int" "$five_time_pct" 30)
      five_indicator=$(get_limit_indicator "$five_int" "$five_time_pct")
      five_pct_display="${dim}${five_int}%${rst}"

      # Pad time to 8 characters
      five_display_width=$(calc_display_width "$five_remaining")
      five_padding=$((8 - five_display_width))
      five_time_fmt="${five_time_with_dim}$(printf "%${five_padding}s" "")"

      five_block="${resolution_5h}${padding_5h}${five_bar}${SEP}${five_indicator}${SEP}${five_pct_display}${SEP}${five_time_fmt}"
    else
      # Text mode: percentage + time-to-reset
      five_pct_display="${five_int}${dim}%${rst}"
      five_block="5h${SEP}${five_pct_display} ${dim}resets${rst} ${five_time_with_dim}"
    fi
  fi
fi

# Model: colorize keyword, dim version number, replace spaces with SEP
model_colored=$(colorize_model "$model")
model_with_dim=$(echo "$model_colored" | sed -E "s/([0-9]+\.[0-9]+)/${dim}\1${rst}/g")
model_display=$(echo "$model_with_dim" | sed "s/ /${SEP}/g")

# Context: build warning indicator (only if context data available)
context_display=""
if [ -n "$used_pct" ]; then
  context_int=${used_pct%.*}
  context_warning=""
  if [ "$context_int" -ge 80 ] 2>/dev/null; then
    ctx_color=$(printf '\033[38;5;167m')
    context_warning="$ICON_CTX_WARN_HIGH"
  elif [ "$context_int" -ge 60 ] 2>/dev/null; then
    ctx_color=$(printf '\033[38;5;178m')
    context_warning="$ICON_CTX_WARN_MED"
  else
    ctx_color=""
  fi

  if [ -n "$context_warning" ]; then
    context_display="   ${ICON_CTX}${SEP}${ctx_color}${used_pct}${dim}%${rst}${SEP}${context_warning}"
  else
    context_display="   ${ICON_CTX}${SEP}${ctx_color}${used_pct}${dim}%${rst}"
  fi
fi

line1="${five_block}   ${ICON_MODEL}${SEP}${model_display}${context_display}"

# ===== BUILD LINE 2: 7d limit + directory =====

seven_block=""
if [ -n "$usage_json" ]; then
  seven_day_pct=$(echo "$usage_json" | jq -r '.seven_day.utilization // empty')
  seven_day_resets=$(echo "$usage_json" | jq -r '.seven_day.resets_at // empty')

  if [ -n "$seven_day_pct" ]; then
    seven_int=${seven_day_pct%.*}
    seven_remaining=$(format_time_remaining "$seven_day_resets" 48)
    seven_time_pct=$(calc_time_pct "$seven_day_resets" 604800)
    seven_time_with_dim=$(dim_time_units "$seven_remaining")

    if [ "$use_progress_bars" = "true" ]; then
      resolution_7d=$(format_resolution "7d" "6h")
      padding_7d=$(printf "${very_dim}%s${rst}" "･･･････")
      seven_bar=$(build_progress_bar "$seven_int" "$seven_time_pct" 28)
      seven_indicator=$(get_limit_indicator "$seven_int" "$seven_time_pct")
      seven_pct_display="${dim}${seven_int}%${rst}"

      # Pad time to 8 characters
      seven_display_width=$(calc_display_width "$seven_remaining")
      seven_padding=$((8 - seven_display_width))
      seven_time_fmt="${seven_time_with_dim}$(printf "%${seven_padding}s" "")"

      seven_block="${resolution_7d}${padding_7d}${seven_bar}${SEP}${seven_indicator}${SEP}${seven_pct_display}${SEP}${seven_time_fmt}"
    else
      # Text mode: percentage + time-to-reset
      seven_pct_display="${seven_int}${dim}%${rst}"
      seven_block="7d${SEP}${seven_pct_display} ${dim}resets${rst} ${seven_time_with_dim}"
    fi
  fi
fi

# Directory: replace spaces with SEP
dir_display=$(echo "$short_dir" | sed "s/ /${SEP}/g")
dir_with_warning="${ICON_DIR}${SEP}${dir_display}"

line2="${seven_block}   ${dir_with_warning}"

# ===== BUILD LINE 3: Extra usage + git branch =====

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

# Determine status icon (play/pause)
status_icon="$ICON_PAUSE"
if [ -n "$usage_json" ]; then
  extra_enabled=$(echo "$usage_json" | jq -r '.extra_usage.is_enabled // empty')
  if [ "$extra_enabled" = "true" ]; then
    extra_utilization=$(echo "$usage_json" | jq -r '.extra_usage.utilization // empty')
    if [ -n "$extra_utilization" ] && [ "$extra_utilization" != "null" ]; then
      extra_int=${extra_utilization%.*}
      if [ "$extra_int" -lt 100 ] 2>/dev/null; then
        if [ "$five_int" -eq 100 ] 2>/dev/null || [ "$seven_int" -eq 100 ] 2>/dev/null; then
          status_icon="$ICON_PLAY"
        fi
      fi
    fi
  fi
fi

# Build extra block
extra_block=""
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

      if [ "$use_progress_bars" = "true" ]; then
        resolution_1m=$(format_resolution "1M" "1d")
        # Padding based on days in month: 31→1, 30→2, 29→3, 28→4
        padding_extra_count=$((32 - days_in_month))
        padding_extra=$(printf "${very_dim}%s${rst}" "$(printf '･%.0s' $(seq 1 $padding_extra_count))")

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
        # Text mode: status icon + money
        extra_block="1M${SEP}${status_icon} ${money_fmt}"
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

# Git branch: replace spaces with SEP, colorize yellow if dirty
if [ -n "$branch" ]; then
  branch_display=$(echo "$branch" | sed "s/ /${SEP}/g")
  if [ -n "$dirty" ]; then
    branch_with_warning="${ICON_BRANCH}${SEP}${yellow}${branch_display}${SEP}${ICON_DIRTY_WARN}${rst}"
  else
    branch_with_warning="${ICON_BRANCH}${SEP}${branch_display}"
  fi
  line3="${extra_block}   ${branch_with_warning}"
else
  # Not in a git repository - no branch block
  line3="${extra_block}"
fi

# Output three lines
echo "$line1"
echo "$line2"
echo "$line3"
