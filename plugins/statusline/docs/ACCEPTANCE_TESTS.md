# Statusline plugin acceptance tests

## Purpose

The statusline plugin provides a custom three-line status display for Claude Code, showing:
- **Line 1:** 5h rate limit (progress bar or percentage) + model + context%
- **Line 2:** 7d rate limit (progress bar or percentage) + directory
- **Line 3:** Monthly extra usage + git branch

Features:
- Two presets: "classic" (emoji + progress bars) and "text" (percentages only, no emoji)
- Per-field overrides via `~/.claude/statusline.json`
- Percentage display and time-to-reset for 5h and 7d limits
- Simplified time display: approximate (~Xh/~Xd) when far from reset, exact (XhYm) when close
- Warning icons: ❌ at 100%, ⚠️ at >90%
- Money tracking: ¤X.YZ format with dimmed currency symbol and fractional part
- Progress bar pacing visualization

Acceptance tests are critical to ensure:
- Correct layout rendering (three lines)
- Accurate API data parsing and display
- Cross-platform compatibility (macOS, Linux)
- Config loading and preset switching
- Progress bar pacing calculations
- Warning icon logic
- Time format simplification logic

## Test execution order

1. Static checks (automated)
2. Config tests (automated)
3. Unit tests (automated)
4. Integration tests (automated)
5. Manual visual verification tests (manual)

## Automation status

- ✅ **Fully automated**: Tests 1-7
- 🟡 **Partially automated**: Tests 8-9 (require fresh session for full verification)
- ⚠️ **Manual only**: Test 10 (visual verification in Claude Code UI)

---

## Test categories

### 1. Static checks

#### 1.1 Plugin manifest validation

**Objective:** Verify plugin.json is valid and contains required fields

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline
jq empty .claude-plugin/plugin.json && echo "✅ Valid JSON" || echo "❌ Invalid JSON"
jq -r '.name' .claude-plugin/plugin.json
jq -r '.version' .claude-plugin/plugin.json
jq -r '.description' .claude-plugin/plugin.json
```

**Acceptance criteria:**
- ✅ plugin.json is valid JSON
- ✅ name = "statusline"
- ✅ version follows semver
- ✅ description is present

---

#### 1.2 Script permissions

**Objective:** Verify scripts are executable

**Automation:** ✅

**Steps:**
```bash
test -x plugins/statusline/scripts/statusline.sh && echo "✅ statusline.sh is executable"
test -x plugins/statusline/scripts/setup-statusline.sh && echo "✅ setup-statusline.sh is executable"
```

**Acceptance criteria:**
- ✅ All scripts have executable bit set

---

### 2. Config loading tests

#### 2.1 Default config (no file)

**Objective:** Verify classic preset is used when no config file exists

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline
rm -f ~/.claude/statusline.json
output=$(echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g')

# Should have emoji icons and progress bars
echo "$output" | grep -q '🤖' && echo "✅ Emoji icons present" || echo "❌ Missing emoji"
echo "$output" | grep -q '■' && echo "✅ Progress bars present" || echo "❌ Missing bars"
```

**Acceptance criteria:**
- ✅ Emoji icons shown (🤖, 📁, 🌿, 📚)
- ✅ Progress bars shown (■ characters)
- ✅ No errors on stderr

---

#### 2.2 Text preset

**Objective:** Verify text preset disables emoji and progress bars

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline
echo '{"preset":"text"}' > ~/.claude/statusline.json
output=$(echo '{"model":{"display_name":"Claude Opus 4.6"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g')

echo "$output"

# Should have text labels, no emoji
echo "$output" | grep -q 'MDL:' && echo "✅ Text label MDL:" || echo "❌ Missing MDL:"
echo "$output" | grep -q 'DIR:' && echo "✅ Text label DIR:" || echo "❌ Missing DIR:"
echo "$output" | grep -q 'BR:' && echo "✅ Text label BR:" || echo "❌ Missing BR:"
echo "$output" | grep -q 'CTX:' && echo "✅ Text label CTX:" || echo "❌ Missing CTX:"

# Should NOT have progress bars
if echo "$output" | grep -q '■'; then
  echo "❌ Progress bars should not appear in text mode"
else
  echo "✅ No progress bars"
fi

# Should show percentage and resets
echo "$output" | grep -q '%.*resets' && echo "✅ Percentage + resets shown" || echo "❌ Missing percentage/resets"

rm ~/.claude/statusline.json
```

**Acceptance criteria:**
- ✅ Text labels used instead of emoji (MDL:, DIR:, BR:, CTX:)
- ✅ No progress bar characters (■)
- ✅ Percentage and "resets" text shown for 5h and 7d limits
- ✅ Three lines of output

---

#### 2.3 Override: emojis=false

**Objective:** Verify emoji override works independently of preset

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline
echo '{"emojis":false}' > ~/.claude/statusline.json
output=$(echo '{"model":{"display_name":"Claude Opus 4.6"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g')

# Text labels but with progress bars
echo "$output" | grep -q 'MDL:' && echo "✅ Text labels" || echo "❌ Missing text labels"
echo "$output" | grep -q '■' && echo "✅ Progress bars still present" || echo "❌ Missing progress bars"

rm ~/.claude/statusline.json
```

**Acceptance criteria:**
- ✅ Text labels (MDL:, DIR:, BR:, CTX:) instead of emoji
- ✅ Progress bars still displayed
- ✅ Dirty indicator uses `*` instead of ⚠️

---

#### 2.4 Override: text preset with emojis=true

**Objective:** Verify overrides take precedence over preset defaults

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline
echo '{"preset":"text","emojis":true}' > ~/.claude/statusline.json
output=$(echo '{"model":{"display_name":"Claude Opus 4.6"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g')

# Emoji icons but no progress bars
echo "$output" | grep -q '🤖' && echo "✅ Emoji icons" || echo "❌ Missing emoji"
if echo "$output" | grep -q '■'; then
  echo "❌ Progress bars should not appear"
else
  echo "✅ No progress bars"
fi

rm ~/.claude/statusline.json
```

**Acceptance criteria:**
- ✅ Emoji icons present (override wins over preset)
- ✅ No progress bars (from text preset)

---

#### 2.5 Invalid JSON config

**Objective:** Verify graceful fallback on invalid config

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline
echo 'not valid json' > ~/.claude/statusline.json
output=$(echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}' | bash scripts/statusline.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g')

echo "$output" | grep -q '🤖' && echo "✅ Falls back to classic" || echo "❌ Did not fall back"

rm ~/.claude/statusline.json
```

**Acceptance criteria:**
- ✅ No crash
- ✅ Falls back to classic preset (emoji + progress bars)

---

### 3. Unit tests

#### 3.1 Progress bar block count

**Objective:** Verify progress bar generates correct number of blocks

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# Test 5h bar (30 blocks)
block_count=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh | head -1 | grep -o '■' | wc -l | tr -d ' ')
echo "5h bar blocks: $block_count (expected: 30)"
test "$block_count" -eq 30 && echo "✅ PASS" || echo "❌ FAIL"
```

**Acceptance criteria:**
- ✅ 5-hour rate limit bar has exactly 30 blocks
- ✅ 7-day rate limit bar has exactly 28 blocks

---

#### 3.2 Three-line output format

**Objective:** Verify output has exactly three lines

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

line_count=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh | wc -l | tr -d ' ')
echo "Line count: $line_count (expected: 3)"

test "$line_count" -eq 3 && echo "✅ Correct" || echo "❌ Incorrect"
```

**Acceptance criteria:**
- ✅ Output contains exactly 3 lines
- ✅ Line 1 contains 5h limit + model + context
- ✅ Line 2 contains 7d limit + directory
- ✅ Line 3 contains extra usage + branch

---

#### 3.3 Percentage display in classic mode

**Objective:** Verify percentage is shown alongside progress bars in classic preset

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline
rm -f ~/.claude/statusline.json

output=$(echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g')

# Check line 1 has percentage for 5h
echo "$output" | head -1 | grep -qE '[0-9]+%' && echo "✅ 5h percentage shown" || echo "❌ Missing 5h percentage"

# Check line 2 has percentage for 7d
echo "$output" | head -2 | tail -1 | grep -qE '[0-9]+%' && echo "✅ 7d percentage shown" || echo "❌ Missing 7d percentage"
```

**Acceptance criteria:**
- ✅ Percentage (e.g., "22%") appears on 5h line
- ✅ Percentage (e.g., "14%") appears on 7d line

---

### 4. Integration tests

#### 4.1 API cache integration

**Objective:** Verify API caching works (60s cache)

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# Clear cache
rm -f /tmp/claude-statusline-usage-cache-${UID}

# First call (should fetch from API)
echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh > /dev/null

# Check cache exists
test -f /tmp/claude-statusline-usage-cache-${UID} && echo "✅ Cache file created" || echo "❌ No cache"
```

**Acceptance criteria:**
- ✅ Cache file created after first call
- ✅ Second call is significantly faster
- ✅ Cache expires after 60 seconds

---

#### 4.2 Warning icons logic

**Objective:** Verify warning icons appear at correct thresholds

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

create_mock_cache() {
  local five_h=$1
  cat > /tmp/claude-statusline-usage-cache-${UID} <<EOF
{"five_hour":{"utilization":$five_h,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":50.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":false}}
EOF
}

# Test: 50% (no icons)
create_mock_cache 50.0
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)
echo "$output" | grep -q "⚠️\|❌" && echo "❌ FAIL: Should not have warning" || echo "✅ No warning at 50%"

# Test: 100% (❌)
create_mock_cache 100.0
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)
echo "$output" | grep -q "❌" && echo "✅ ❌ at 100%" || echo "❌ FAIL: Missing ❌"
```

**Acceptance criteria:**
- ✅ No icons when utilization <= 90%
- ✅ ⚠️ icon when 90% < utilization < 100%
- ✅ ❌ icon when utilization = 100%

---

#### 4.3 Extra usage money display

**Objective:** Verify API credits convert correctly to money amount (credits / 100)

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

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
test_credits 47900.0 "479.00"
```

**Acceptance criteria:**
- ✅ Conversion formula: `credits / 100`
- ✅ Always 2 decimal places
- ✅ No duplicated decimals (e.g., "4.79" not "4.79.79")

---

#### 4.4 Simplified time display format

**Objective:** Verify time remaining uses simplified format

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

create_time_test() {
  local hours_left=$1
  local now=$(date -u +%s)
  local reset_time=$((now + hours_left * 3600))
  if [ "$(uname)" = "Darwin" ]; then
    local reset_iso=$(date -ju -f %s $reset_time +%Y-%m-%dT%H:%M:%S+00:00)
  else
    local reset_iso=$(date -u -d "@$reset_time" +%Y-%m-%dT%H:%M:%S+00:00)
  fi
  cat > /tmp/claude-statusline-usage-cache-${UID} <<EOF
{"five_hour":{"utilization":50.0,"resets_at":"$reset_iso"},"seven_day":{"utilization":50.0,"resets_at":"$reset_iso"},"extra_usage":{"is_enabled":false}}
EOF
  echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1 | sed 's/\x1b\[[0-9;]*m//g'
}

# Far from reset: approximate
output=$(create_time_test 4.5)
echo "$output" | grep -q '~' && echo "✅ Approximate format (~) at 4.5h" || echo "❌ FAIL"

# Close to reset: exact
output=$(create_time_test 1.5)
echo "$output" | grep -qE '[0-9]+h[0-9]+m' && echo "✅ Exact format (XhYm) at 1.5h" || echo "❌ FAIL"
```

**Acceptance criteria:**
- ✅ 5h limit: >=2h shows ~Xh (approximate), <2h shows exact XhYm
- ✅ 7d limit: >=2d shows ~Xd (approximate), <2d shows exact XdYh or XhYm
- ✅ Tilde (~) character is dimmed

---

### 5. Cross-platform tests

#### 5.1 macOS compatibility

**Objective:** Verify script works on macOS

**Automation:** ✅ (on macOS only)

**Steps:**
```bash
if [ "$(uname)" != "Darwin" ]; then echo "⏭️ SKIP: Not macOS"; exit 0; fi
cd plugins/statusline
echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh > /dev/null && echo "✅ Statusline executes without errors"
```

---

#### 5.2 Linux compatibility

**Objective:** Verify script works on Linux

**Automation:** ✅ (on Linux only)

**Steps:**
```bash
if [ "$(uname)" = "Darwin" ]; then echo "⏭️ SKIP: Not Linux"; exit 0; fi
cd plugins/statusline
echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh > /dev/null && echo "✅ Statusline executes without errors"
```

---

### 6. Edge cases

#### 6.1 Extra usage disabled

**Objective:** Verify no extra usage data when `is_enabled: false`

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline
cat > /tmp/claude-statusline-usage-cache-${UID} <<'EOF'
{"five_hour":{"utilization":50.0,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":50.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":false}}
EOF
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g' | tail -1)
if echo "$output" | grep -q "¤"; then
  echo "❌ FAIL: Money should not appear when extra disabled"
else
  echo "✅ PASS: No extra usage data shown"
fi
```

---

#### 6.2 API timeout/failure

**Objective:** Verify graceful degradation when API fails

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline
rm -f /tmp/claude-statusline-usage-cache-${UID}
unset CLAUDE_CODE_OAUTH_TOKEN
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
echo "$output" | grep -q "🤖\|MDL:" && echo "✅ Shows basic info despite API failure" || echo "❌ FAIL"
```

---

### 7. Git integration

#### 7.1 Git branch detection

**Objective:** Verify git branch shows in statusline

**Automation:** 🟡

**Steps:**
```bash
test_dir=$(mktemp -d)
cd "$test_dir" && git init -q && git checkout -b test-branch 2>/dev/null
output=$(echo "{\"workspace\":{\"current_dir\":\"$test_dir\"},\"model\":{\"display_name\":\"Test\"},\"context_window\":{\"used_percentage\":50}}" | \
  bash plugins/statusline/scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g' | tail -1)
echo "$output" | grep -q "test-branch" && echo "✅ Branch detected" || echo "❌ FAIL"
rm -rf "$test_dir"
```

---

### 8. Context window warnings

#### 8.1 Context window color coding

**Objective:** Verify context window colors and warnings

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# <60% (no warning)
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50.0}}' | bash scripts/statusline.sh | head -1)
echo "$output" | grep -q "🛑\|!!" && echo "❌ FAIL" || echo "✅ No warning at 50%"

# >=80% (red)
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":85.0}}' | bash scripts/statusline.sh | head -1)
echo "$output" | grep -q "🛑\|!!" && echo "✅ Warning at 85%" || echo "❌ FAIL"
```

**Acceptance criteria:**
- ✅ <60%: no color, no icon
- ✅ >=60%: yellow + warning
- ✅ >=80%: red + stop icon

---

### 9. Config via /statusline-setup

#### 9.1 Preset selection

**Objective:** Verify /statusline-setup offers preset selection and writes config

**Automation:** ⚠️ Manual only

**Manual test procedure:**

**Step 1:** Start fresh session
```bash
claude
```

**Step 2:** Run setup command
```
/statusline-setup
```

**Step 3:** Verify preset selection is offered (Classic vs Text)

**Step 4:** Select "Text" preset

**Step 5:** Verify config file was created
```bash
cat ~/.claude/statusline.json
# Expected: {"preset": "text"}
```

**Step 6:** Verify statusline switched to text mode (no emoji, no bars, percentages shown)

**Acceptance criteria:**
- ✅ /statusline-setup offers preset selection
- ✅ Selected preset written to ~/.claude/statusline.json
- ✅ Statusline updates immediately after setup

---

### 10. Visual verification (manual)

#### 10.1 Live Claude Code integration

**Objective:** Verify statusline displays correctly in actual Claude Code UI

**Automation:** ⚠️ Manual only

**Manual test procedure (5 steps):**

**Step 1:** Install and sync plugin
```bash
claude-marketplace-sync --force
```

**Step 2:** Configure statusline
```bash
claude
/statusline-setup
```

**Step 3:** Verify classic preset visual layout

Expected appearance:
```
5h/10m････■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■････22%･~5h        🤖･Claude･Opus･4.6   📚･42%
7d/6h･･･････■■■■■■■■■■■■■■■■■■■■■■■■■■■■････14%･~5d        📁･claude-plugins
1M/1d･⏸️････■■■■■■■■■■■■■■■■■■■■■■■■■■■■････¤4.79      🌿･main
```

**Step 4:** Switch to text preset
```bash
echo '{"preset":"text"}' > ~/.claude/statusline.json
```

Expected appearance:
```
5h･22% resets ~5h   MDL:･Claude･Opus･4.6   CTX:･42%
7d･14% resets ~5d   DIR:･claude-plugins
1M･⏸️ ¤4.79      BR:･main
```

**Step 5:** Verify both presets render correctly across different terminal fonts

Visual checklist:
- ✅ Three lines visible
- ✅ Classic: progress bars with colored blocks
- ✅ Classic: percentage shown next to bars
- ✅ Text: no emoji, no progress bars, percentages and "resets" text
- ✅ Colors are visible (gray, green/red, blue)
- ✅ Both presets show time-to-reset

---

## Known limitations

### API data availability

- **Extra usage data**: Only available when feature is enabled in user account
- **Null values**: `utilization: null` when `monthly_limit: null` (unlimited)
- **Reset timestamps**: Extra usage doesn't provide `resets_at` field (inferred as 1st of next month UTC)

### Platform differences

- **Date commands**: macOS uses `-v` flags, Linux uses `-d` flag
- **Keychain access**: OAuth token from Keychain only on macOS (Linux uses `~/.claude/.credentials.json`)
- **Locale**: Decimal separator may be comma or dot depending on system locale

### Config

- Config file must be valid JSON. Invalid JSON silently falls back to classic preset.
- Config is read on every statusline render (no in-process caching of config).

---

## Regression testing guide

### When to run

Run full test suite:
- Before releasing new version
- After modifying progress bar logic
- After changing API parsing code
- After changing config loading or preset logic
- When updating cross-platform code

### Quick smoke test

```bash
cd plugins/statusline

# No config - classic with percentage
rm -f ~/.claude/statusline.json
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g'

# Text preset
echo '{"preset":"text"}' > ~/.claude/statusline.json
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}' | bash scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g'

rm -f ~/.claude/statusline.json
```

---

## Version history

### 1.3.0 (Current)

New features:
- Customizable presets: "classic" (default) and "text" (no emoji, no progress bars)
- Config file `~/.claude/statusline.json` with preset selection and per-field overrides
- Percentage display (e.g., "22%") in classic preset alongside progress bars
- Time-to-reset shown in both presets
- Text preset: pure ASCII labels (MDL:, DIR:, BR:, CTX:) instead of emoji
- `/statusline-setup` updated with preset selection step

Tests added:
- Config loading tests (2.1-2.5): default, text preset, overrides, invalid JSON
- Percentage display test (3.3)
- /statusline-setup preset selection test (9.1)
- Updated visual verification for both presets (10.1)

### 1.2.3

Bug fix:
- Fixed extra usage money display showing duplicated decimals (e.g., 4.79.79)

### 1.2.0

New features:
- Three-line layout (5h limit | 7d limit | extra usage)
- Enhanced resolution: 5h (30 blocks/10m), 7d (28 blocks/6h)

### 1.1.0

New features:
- Two-line layout (progress bars | info)
- Extra usage (monthly billing) tracking
- Warning icons (❌ at 100%, ⚠️ at >90%)

### 1.0.0

Initial release:
- Single-line layout
- 5h/7d rate limits with percentage display
- Context window usage
- Git branch and model info
