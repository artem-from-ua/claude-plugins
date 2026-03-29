# Statusline-compact plugin acceptance tests

## Purpose

The statusline-compact plugin provides a single-line compact status display for Claude Code, showing:
- 5h/7d rate limits with brightness-coded percentages
- Extra usage (monthly billing) with dollar amount
- Model name, context window usage, directory, git branch

Features:
- Single-line output - most space-efficient option
- Progressive hiding: drops low-priority segments on narrow terminals to preserve space for system notifications
- Brightness-coded values: dim at low usage, brighter as they climb, yellow >90%, red 100%
- Text indicators: `!!` at >90%, `XX` at 100%
- Branch shown yellow with `*` when dirty
- `>>` suffix on extra label when extra usage actively consumed

## Test execution order

1. Static checks (automated)
2. Output format tests (automated)
3. Integration tests (automated)
4. Manual visual verification (manual)

## Automation status

- ✅ **Fully automated**: Tests 1-3
- ⚠️ **Manual only**: Test 4 (visual verification in Claude Code UI)

---

## Test categories

### 1. Static checks

#### 1.1 Plugin manifest validation

**Objective:** Verify plugin.json is valid and contains required fields

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline-compact
jq empty .claude-plugin/plugin.json && echo "✅ Valid JSON" || echo "❌ Invalid JSON"
jq -r '.name' .claude-plugin/plugin.json
jq -r '.version' .claude-plugin/plugin.json
jq -r '.description' .claude-plugin/plugin.json
```

**Acceptance criteria:**
- ✅ plugin.json is valid JSON
- ✅ name = "statusline-compact"
- ✅ version follows semver
- ✅ description is present

---

#### 1.2 Script permissions

**Objective:** Verify scripts are executable

**Automation:** ✅

**Steps:**
```bash
test -x plugins/statusline-compact/scripts/statusline.sh && echo "✅ statusline.sh is executable"
test -x plugins/statusline-compact/scripts/setup-statusline.sh && echo "✅ setup-statusline.sh is executable"
```

**Acceptance criteria:**
- ✅ All scripts have executable bit set

---

### 2. Output format tests

#### 2.1 Single line output

**Objective:** Verify output is exactly one line with expected segments

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline-compact
output=$(echo '{"model":{"display_name":"Claude Sonnet 4.5"},"workspace":{"current_dir":"/tmp/my-project"},"context_window":{"used_percentage":52}}' | bash scripts/statusline.sh)
clean=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')

# Single line
line_count=$(echo "$clean" | wc -l | tr -d ' ')
[ "$line_count" -eq 1 ] && echo "✅ Single line output" || echo "❌ Expected 1 line, got $line_count"

# No emoji
if echo "$clean" | grep -qP '[\x{1F000}-\x{1FFFF}]'; then
  echo "❌ Emoji found"
else
  echo "✅ No emoji"
fi

# No progress bars
if echo "$clean" | grep -q '■'; then
  echo "❌ Progress bars found"
else
  echo "✅ No progress bars"
fi

# Has expected segments
echo "$clean" | grep -q 'Sonnet' && echo "✅ Model present" || echo "❌ Missing model"
echo "$clean" | grep -q 'context' && echo "✅ context label present" || echo "❌ Missing context label"
echo "$clean" | grep -q 'my-project' && echo "✅ Directory present" || echo "❌ Missing directory"
```

**Acceptance criteria:**
- ✅ Exactly one line of output
- ✅ No emoji characters
- ✅ No progress bar characters
- ✅ Model name, context label, and directory present

---

#### 2.2 Warning indicators

**Objective:** Verify !! and XX indicators appear at correct thresholds

**Automation:** 🟡 (requires mock API data)

**Steps:**
```bash
cd plugins/statusline-compact

create_mock_cache() {
  local five_h=$1
  cat > /tmp/claude-statusline-usage-cache-${UID} <<EOF
{"five_hour":{"utilization":$five_h,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":50.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":false}}
EOF
}

# Test: 50% (no indicators)
create_mock_cache 50.0
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g')
echo "$output" | grep -q '!!\|XX' && echo "❌ FAIL: Should not have warning" || echo "✅ No warning at 50%"

# Test: 95% (!!)
create_mock_cache 95.0
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g')
echo "$output" | grep -q '!!' && echo "✅ !! at 95%" || echo "❌ FAIL: Missing !!"

# Test: 100% (XX)
create_mock_cache 100.0
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g')
echo "$output" | grep -q 'XX' && echo "✅ XX at 100%" || echo "❌ FAIL: Missing XX"
```

**Acceptance criteria:**
- ✅ No indicators when usage <= 90%
- ✅ `!!` when 90% < usage < 100%
- ✅ `XX` when usage = 100%
- ✅ `!!` when context >= 80%

---

### 3. Integration tests

#### 3.1 API cache integration

**Objective:** Verify API caching works (60s cache)

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline-compact

# Clear cache
rm -f /tmp/claude-statusline-usage-cache-${UID}

# First call
echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh > /dev/null

# Check cache exists
test -f /tmp/claude-statusline-usage-cache-${UID} && echo "✅ Cache file created" || echo "❌ No cache"
```

---

#### 3.2 Extra usage money display

**Objective:** Verify API credits convert correctly to money amount

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline-compact

test_credits() {
  local credits=$1
  local expected=$2
  cat > /tmp/claude-statusline-usage-cache-${UID} <<EOF
{"five_hour":{"utilization":50.0,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":50.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":true,"used_credits":$credits,"utilization":null}}
EOF
  output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g')
  echo "$output" | grep -q "$expected" && echo "✅ $credits -> $expected" || echo "❌ FAIL: $credits -> expected $expected"
}

test_credits 1251.0 "12.51"
test_credits 100.0 "1.00"
test_credits 0.0 "0.00"
```

---

#### 3.3 Git branch detection

**Objective:** Verify git branch shows in statusline

**Automation:** 🟡

**Steps:**
```bash
test_dir=$(mktemp -d)
cd "$test_dir" && git init -q && git checkout -b test-branch 2>/dev/null
output=$(echo "{\"workspace\":{\"current_dir\":\"$test_dir\"},\"model\":{\"display_name\":\"Test\"},\"context_window\":{\"used_percentage\":50}}" | \
  bash plugins/statusline-compact/scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g')
echo "$output" | grep -q "test-branch" && echo "✅ Branch detected" || echo "❌ FAIL"
rm -rf "$test_dir"
```

---

#### 3.4 Progressive hiding

**Objective:** Verify segments are progressively hidden on narrow terminals to preserve notification space

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline-compact

# Mock cache with all segments populated
cat > /tmp/claude-statusline-usage-cache-${UID} <<EOF
{"five_hour":{"utilization":50.0,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":20.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":true,"used_credits":479.0,"utilization":null}}
EOF
INPUT='{"workspace":{"current_dir":"/test/my-project"},"model":{"display_name":"Claude Sonnet 4.5"},"context_window":{"used_percentage":50},"cost":{"total_cost_usd":0.42}}'

# Helper: run with simulated terminal width
run_at_width() {
  local width=$1
  bash -c "
    tput() { if [ \"\$1\" = \"cols\" ]; then echo $width; else command tput \"\$@\"; fi; }
    export -f tput
    echo '$INPUT' | bash scripts/statusline.sh 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
  "
}

# Wide terminal: all segments present
output=$(run_at_width 200)
echo "$output" | grep -q 'my-project' && echo "✅ Wide: directory present" || echo "❌ FAIL: Missing directory at 200 cols"
echo "$output" | grep -q '0.42' && echo "✅ Wide: session cost present" || echo "❌ FAIL: Missing cost at 200 cols"
echo "$output" | grep -q 'extra' && echo "✅ Wide: extra usage present" || echo "❌ FAIL: Missing extra at 200 cols"

# Narrow terminal: directory dropped first
output=$(run_at_width 100)
echo "$output" | grep -q 'Sonnet' && echo "✅ Narrow: model present" || echo "❌ FAIL: Model missing at 100 cols"
echo "$output" | grep -q 'context' && echo "✅ Narrow: context present" || echo "❌ FAIL: Context missing at 100 cols"

# Very narrow: only required segments remain (5h, 7d, model, context, branch)
output=$(run_at_width 70)
echo "$output" | grep -q '5h' && echo "✅ Minimal: 5h present" || echo "❌ FAIL: 5h missing at 70 cols"
echo "$output" | grep -q '7d' && echo "✅ Minimal: 7d present" || echo "❌ FAIL: 7d missing at 70 cols"
echo "$output" | grep -q 'my-project' && echo "❌ FAIL: Directory should be hidden at 70 cols" || echo "✅ Minimal: directory hidden"
echo "$output" | grep -q 'extra' && echo "❌ FAIL: Extra should be hidden at 70 cols" || echo "✅ Minimal: extra hidden"
```

**Acceptance criteria:**
- ✅ Wide terminal (200+ cols): all segments present
- ✅ Narrow terminal: directory dropped first, then session cost, then extra usage
- ✅ Required segments (5h, 7d, model, context, branch) never hidden
- ✅ Fallback: when `tput cols` unavailable, all segments shown

---

#### 3.5 API timeout/failure

**Objective:** Verify graceful degradation when API fails

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline-compact
rm -f /tmp/claude-statusline-usage-cache-${UID}
unset CLAUDE_CODE_OAUTH_TOKEN
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
# Should still show model, context, dir
echo "$output" | grep -q "Test" && echo "✅ Shows basic info despite API failure" || echo "❌ FAIL"
```

---

### 4. Visual verification (manual)

#### 4.1 Live Claude Code integration

**Objective:** Verify compact statusline displays correctly in actual Claude Code UI

**Automation:** ⚠️ Manual only

**Manual test procedure:**

**Step 1:** Install and sync plugin
```bash
Restart Claude Code
```

**Step 2:** Configure statusline
```bash
claude
/statusline-setup
```

**Step 3:** Verify compact layout

Expected appearance:
```
5h 12% ~2h14m   7d 45% ~3d5h   extra $4.79   $0.42   Sonnet 4.5   context 52%   claude-plugins/   main
```

Visual checklist:
- ✅ Single line visible
- ✅ Dim labels (5h, 7d, extra, context)
- ✅ Brightness-coded percentages
- ✅ Model name with brightness = capability tier
- ✅ Directory with trailing /
- ✅ Branch (yellow with * when dirty)

---

## Known limitations

### API data availability

- **Extra usage data**: Only available when feature is enabled in user account
- **Null values**: `utilization: null` when `monthly_limit: null` (unlimited)

### Platform differences

- **Date commands**: macOS uses `-v` flags, Linux uses `-d` flag
- **Keychain access**: OAuth token from Keychain only on macOS (Linux uses `~/.claude/.credentials.json`)

---

## Regression testing guide

### Quick smoke test

```bash
cd plugins/statusline-compact

echo '{"model":{"display_name":"Claude Sonnet 4.5"},"workspace":{"current_dir":"/tmp/my-project"},"context_window":{"used_percentage":52}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g'
# Expected: single line with all segments
```

---

## Version history

### 0.6.0

- Progressive hiding: drops low-priority segments (dir, cost, extra) on narrow terminals to preserve notification space
- Removed per-model 7d limits segment

### 0.5.0

- Per-model 7d limits: shows highest-utilization per-model weekly limit (e.g., `7d:sonnet 1% ~5d`)

### 0.4.0

- Removed session name display (now built into Claude Code natively)

### 0.3.0

- Session name display: custom name (via `/rename`) shown as normal text; slug/ID fallback shown dimmed with `!!`
- Cached at `/tmp/claude-statusline-session-${UID}-<session_id>` with 300s TTL

### 0.1.0

Initial release - extracted from statusline plugin compact preset:
- Single-line layout with brightness-coded values
- 5h/7d rate limits with time-to-reset
- Extra usage with dollar amount
- Model name with capability-tier brightness
- Context window with warning at >=80%
- Git branch with dirty indicator
- Text-only warning indicators: `!!` at >90%, `XX` at 100%
