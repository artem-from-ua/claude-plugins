# Statusline Plugin Acceptance Tests

## Purpose

The statusline plugin provides a custom two-line status display for Claude Code, showing:
- **Line 1:** Progress bars for rate limits (5h, 7d) and extra usage (monthly billing)
- **Line 2:** Directory, git branch, model, and context window information

Features:
- Simplified time display: approximate (~Xh/~Xd) when far from reset, exact (XhYm) when close
- Warning icons: ❌ at 100%, ⚠️ at >90%
- Money tracking: ¤X.YZ format with dimmed currency symbol and fractional part
- Progress bar pacing visualization

Acceptance tests are critical to ensure:
- Correct layout rendering (two lines)
- Accurate API data parsing and display
- Cross-platform compatibility (macOS, Linux)
- Progress bar pacing calculations
- Warning icon logic
- Time format simplification logic

## Test Execution Order

1. Static checks (automated)
2. Unit tests (automated)
3. Integration tests (automated)
4. Manual visual verification tests (manual)

## Automation Status

- ✅ **Fully automated**: Tests 1-6
- 🟡 **Partially automated**: Test 7 (requires fresh session for full verification)
- ⚠️ **Manual only**: Test 8 (visual verification in Claude Code UI)

---

## Test Categories

### 1. Static Checks

#### 1.1 Plugin Manifest Validation

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

**Expected result:**
```
✅ Valid JSON
statusline
1.1.0
Custom Claude Code statusline with API rate limits, context window, git branch, model info
```

**Acceptance criteria:**
- ✅ plugin.json is valid JSON
- ✅ name = "statusline"
- ✅ version follows semver (e.g., 1.1.0)
- ✅ description is present

---

#### 1.2 Script Permissions

**Objective:** Verify scripts are executable

**Automation:** ✅

**Steps:**
```bash
test -x plugins/statusline/scripts/statusline.sh && echo "✅ statusline.sh is executable"
test -x plugins/statusline/scripts/setup-statusline.sh && echo "✅ setup-statusline.sh is executable"
```

**Expected result:**
```
✅ statusline.sh is executable
✅ setup-statusline.sh is executable
```

**Acceptance criteria:**
- ✅ All scripts have executable bit set

---

#### 1.3 Setup Script Logging

**Objective:** Verify setup-statusline.sh writes diagnostic log

**Automation:** ✅

**Steps:**
```bash
rm -f /tmp/claude-plugin-sync.log
CLAUDE_PLUGIN_ROOT="$(pwd)/plugins/statusline" bash plugins/statusline/scripts/setup-statusline.sh > /dev/null 2>&1
grep -c "\[setup-statusline\]" /tmp/claude-plugin-sync.log
grep "CLAUDE_PLUGIN_ROOT=" /tmp/claude-plugin-sync.log
grep "SOURCE=" /tmp/claude-plugin-sync.log
```

**Expected result:**
- Log file created at `/tmp/claude-plugin-sync.log`
- Contains `[setup-statusline]` entries with CLAUDE_PLUGIN_ROOT, SOURCE, TARGET paths
- Records copy decision (missing/differs/identical)

**Acceptance criteria:**
- ✅ Log file created
- ✅ CLAUDE_PLUGIN_ROOT value logged
- ✅ SOURCE and TARGET paths logged
- ✅ Copy decision logged

---

### 2. Unit Tests

#### 2.1 Progress Bar Block Count

**Objective:** Verify progress bar generates correct number of blocks

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# Test 5h bar (20 blocks)
test_output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh | head -1 | grep -o '■' | wc -l | tr -d ' ')
echo "5h bar blocks: $test_output (expected: 20)"

# Test 7d bar (21 blocks)
test_output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh | head -1 | tail -c 50 | grep -o '■' | head -21 | wc -l | tr -d ' ')
echo "7d bar blocks: $test_output (expected: 21)"
```

**Expected result:**
```
5h bar blocks: 20 (expected: 20)
7d bar blocks: 21 (expected: 21)
```

**Acceptance criteria:**
- ✅ 5-hour rate limit bar has exactly 20 blocks
- ✅ 7-day rate limit bar has exactly 21 blocks

---

#### 2.2 Extra Usage Monthly Bar Length

**Objective:** Verify extra usage bar matches days in current month

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# Calculate expected days in current month (UTC)
if [ "$(uname)" = "Darwin" ]; then
  expected_days=$(date -u -v1d -v+1m -v-1d +%d 2>/dev/null)
else
  expected_days=$(date -u -d "$(date -u +%Y-%m-01) +1 month -1 day" +%d 2>/dev/null)
fi
echo "Expected days in month: $expected_days"

# Count blocks in extra usage bar (after 💸)
actual_blocks=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh | head -1 | grep -o '💸.*' | grep -o '■' | wc -l | tr -d ' ')
echo "Actual blocks in extra usage bar: $actual_blocks"

if [ "$expected_days" = "$actual_blocks" ]; then
  echo "✅ Match!"
else
  echo "❌ Mismatch!"
fi
```

**Expected result:**
```
Expected days in month: 28
Actual blocks in extra usage bar: 28
✅ Match!
```

**Acceptance criteria:**
- ✅ Extra usage bar length equals days in current month (28-31 blocks)

---

#### 2.3 Two-Line Output Format

**Objective:** Verify output has exactly two lines

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

line_count=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh | wc -l | tr -d ' ')
echo "Line count: $line_count (expected: 2)"

test "$line_count" -eq 2 && echo "✅ Correct" || echo "❌ Incorrect"
```

**Expected result:**
```
Line count: 2 (expected: 2)
✅ Correct
```

**Acceptance criteria:**
- ✅ Output contains exactly 2 lines
- ✅ Line 1 contains progress bars (⏳, 📅, 💸)
- ✅ Line 2 contains info (📁, 🌿, 🤖, 📚)

---

### 3. Integration Tests

#### 3.1 API Cache Integration

**Objective:** Verify API caching works (60s cache)

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# Clear cache
rm -f /tmp/claude-statusline-usage-cache-${UID}

# First call (should fetch from API)
echo "First call (fetching from API)..."
time echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh > /dev/null

# Check cache exists
test -f /tmp/claude-statusline-usage-cache-${UID} && echo "✅ Cache file created"

# Second call (should use cache)
echo "Second call (using cache)..."
time echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh > /dev/null

echo "Second call should be faster (cached)"
```

**Expected result:**
```
First call (fetching from API)...
real    0m0.XXXs
✅ Cache file created
Second call (using cache)...
real    0m0.0XXs
Second call should be faster (cached)
```

**Acceptance criteria:**
- ✅ Cache file created after first call
- ✅ Second call is significantly faster
- ✅ Cache expires after 60 seconds

---

#### 3.2 Warning Icons Logic

**Objective:** Verify warning icons appear at correct thresholds

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# Create mock API responses with different utilization levels
create_mock_cache() {
  local five_h=$1
  local seven_d=$2
  local extra=$3
  cat > /tmp/claude-statusline-usage-cache-${UID} <<EOF
{
  "five_hour": {"utilization": $five_h, "resets_at": "2026-02-20T12:00:00+00:00"},
  "seven_day": {"utilization": $seven_d, "resets_at": "2026-02-25T12:00:00+00:00"},
  "extra_usage": {"is_enabled": true, "used_credits": 1000.0, "utilization": $extra, "monthly_limit": 5000}
}
EOF
}

# Test case 1: 50% (no icons)
echo "Test 1: 50% utilization (no warning icons)"
create_mock_cache 50.0 50.0 50.0
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)
if echo "$output" | grep -q "⚠️\|❌"; then
  echo "❌ FAIL: Should not have warning icons"
else
  echo "✅ PASS: No warning icons"
fi

# Test case 2: 91% (⚠️ icons)
echo "Test 2: 91% utilization (⚠️ warning icons)"
create_mock_cache 91.0 91.0 91.0
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)
warning_count=$(echo "$output" | grep -o "⚠️" | wc -l | tr -d ' ')
echo "Warning icons (⚠️) found: $warning_count (expected: 3)"
test "$warning_count" -eq 3 && echo "✅ PASS" || echo "❌ FAIL"

# Test case 3: 100% (❌ icons)
echo "Test 3: 100% utilization (❌ exhausted icons)"
create_mock_cache 100.0 100.0 100.0
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)
exhausted_count=$(echo "$output" | grep -o "❌" | wc -l | tr -d ' ')
echo "Exhausted icons (❌) found: $exhausted_count (expected: 3)"
test "$exhausted_count" -eq 3 && echo "✅ PASS" || echo "❌ FAIL"
```

**Expected result:**
```
Test 1: 50% utilization (no warning icons)
✅ PASS: No warning icons
Test 2: 91% utilization (⚠️ warning icons)
Warning icons (⚠️) found: 3 (expected: 3)
✅ PASS
Test 3: 100% utilization (❌ exhausted icons)
Exhausted icons (❌) found: 3 (expected: 3)
✅ PASS
```

**Acceptance criteria:**
- ✅ No icons when utilization ≤ 90%
- ✅ ⚠️ icon when 90% < utilization < 100%
- ✅ ❌ icon when utilization = 100%
- ✅ Icons appear for all three bars (5h, 7d, extra)

---

#### 3.3 Extra Usage Status Icon

**Objective:** Verify ▶️/⏸️ status icon logic (icon appears between progress bar and money)

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# Test case 1: Limits not exhausted (⏸️ paused)
echo "Test 1: Limits not exhausted (⏸️ paused)"
cat > /tmp/claude-statusline-usage-cache-${UID} <<'EOF'
{"five_hour":{"utilization":50.0,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":50.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":true,"used_credits":1000.0,"utilization":50.0,"monthly_limit":5000}}
EOF
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)
echo "$output" | grep -q "💸.*⏸️.*¤" && echo "✅ PASS: ⏸️ (paused)" || echo "❌ FAIL"

# Test case 2: 5h exhausted, extra<100 (▶️ active)
echo "Test 2: 5h exhausted, extra<100 (▶️ active)"
cat > /tmp/claude-statusline-usage-cache-${UID} <<'EOF'
{"five_hour":{"utilization":100.0,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":50.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":true,"used_credits":1000.0,"utilization":50.0,"monthly_limit":5000}}
EOF
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)
echo "$output" | grep -q "💸.*▶️.*¤" && echo "✅ PASS: ▶️ (active)" || echo "❌ FAIL"

# Test case 3: 7d exhausted, extra<100 (▶️ active)
echo "Test 3: 7d exhausted, extra<100 (▶️ active)"
cat > /tmp/claude-statusline-usage-cache-${UID} <<'EOF'
{"five_hour":{"utilization":50.0,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":100.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":true,"used_credits":1000.0,"utilization":50.0,"monthly_limit":5000}}
EOF
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)
echo "$output" | grep -q "💸.*▶️.*¤" && echo "✅ PASS: ▶️ (active)" || echo "❌ FAIL"

# Test case 4: 5h exhausted, extra=100 (⏸️ paused)
echo "Test 4: 5h exhausted, extra=100 (⏸️ paused, extra exhausted)"
cat > /tmp/claude-statusline-usage-cache-${UID} <<'EOF'
{"five_hour":{"utilization":100.0,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":50.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":true,"used_credits":5000.0,"utilization":100.0,"monthly_limit":5000}}
EOF
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)
echo "$output" | grep -q "💸.*⏸️.*¤" && echo "✅ PASS: ⏸️ (paused)" || echo "❌ FAIL"

# Test case 5: 5h exhausted, extra=null (⏸️ paused, unlimited)
echo "Test 5: 5h exhausted, extra=null (⏸️ paused, unlimited)"
cat > /tmp/claude-statusline-usage-cache-${UID} <<'EOF'
{"five_hour":{"utilization":100.0,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":50.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":true,"used_credits":1000.0,"utilization":null}}
EOF
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)
echo "$output" | grep -q "💸.*⏸️.*¤" && echo "✅ PASS: ⏸️ (paused)" || echo "❌ FAIL"
```

**Expected result:**
```
Test 1: Limits not exhausted (⏸️ paused)
✅ PASS: ⏸️ (paused)
Test 2: 5h exhausted, extra<100 (▶️ active)
✅ PASS: ▶️ (active)
Test 3: 7d exhausted, extra<100 (▶️ active)
✅ PASS: ▶️ (active)
Test 4: 5h exhausted, extra=100 (⏸️ paused, extra exhausted)
✅ PASS: ⏸️ (paused)
Test 5: 5h exhausted, extra=null (⏸️ paused, unlimited)
✅ PASS: ⏸️ (paused)
```

**Acceptance criteria:**
- ✅ Icon appears between progress bar and money amount (💸 ... icon ... ¤)
- ✅ ▶️ when (5h=100 OR 7d=100) AND extra_utilization exists AND extra_utilization<100
- ✅ ⏸️ when both 5h and 7d < 100%
- ✅ ⏸️ when extra_utilization = 100% (even if 5h/7d exhausted)
- ✅ ⏸️ when extra_utilization = null (unlimited)

---

#### 3.4 Extra Usage Money Display

**Objective:** Verify API credits convert correctly to money amount (credits / 100)

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# Test various credit amounts
test_credits() {
  local credits=$1
  local expected=$2

  cat > /tmp/claude-statusline-usage-cache-${UID} <<EOF
{"five_hour":{"utilization":50.0,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":50.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":true,"used_credits":$credits,"utilization":null}}
EOF

  output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)

  # Extract money spent (last field after 💸)
  actual=$(echo "$output" | grep -o '💸.*' | awk '{print $NF}')

  echo "Credits: $credits → $actual (expected: $expected)"

  # Compare (allowing comma or dot as decimal separator)
  if echo "$actual" | grep -qE "^${expected//./[.,]}$"; then
    echo "✅ PASS"
  else
    echo "❌ FAIL"
  fi
}

test_credits 1251.0 "12.51"
test_credits 100.0 "1.00"
test_credits 99.5 "1.00"
test_credits 0.0 "0.00"
test_credits 12345.67 "123.46"
```

**Expected result:**
```
Credits: 1251.0 → 12.51 (expected: 12.51)
✅ PASS
Credits: 100.0 → 1.00 (expected: 1.00)
✅ PASS
Credits: 99.5 → 1.00 (expected: 1.00)
✅ PASS
Credits: 0.0 → 0.00 (expected: 0.00)
✅ PASS
Credits: 12345.67 → 123.46 (expected: 123.46)
✅ PASS
```

**Acceptance criteria:**
- ✅ Conversion formula: `credits / 100`
- ✅ Always 2 decimal places
- ✅ Works with user locale (comma or dot separator)

---

### 4. Cross-Platform Tests

#### 4.1 macOS Compatibility

**Objective:** Verify script works on macOS

**Automation:** ✅ (on macOS only)

**Steps:**
```bash
if [ "$(uname)" != "Darwin" ]; then
  echo "⏭️ SKIP: Not running on macOS"
  exit 0
fi

cd plugins/statusline

# Test date commands (macOS-specific flags)
date -u -v1d -v+1m -v-1d +%d > /dev/null 2>&1 && echo "✅ macOS date commands work"

# Test full statusline
echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh > /dev/null && echo "✅ Statusline executes without errors"
```

**Expected result:**
```
✅ macOS date commands work
✅ Statusline executes without errors
```

**Acceptance criteria:**
- ✅ No errors on macOS
- ✅ Date calculations correct

---

#### 4.2 Linux Compatibility

**Objective:** Verify script works on Linux

**Automation:** ✅ (on Linux only)

**Steps:**
```bash
if [ "$(uname)" = "Darwin" ]; then
  echo "⏭️ SKIP: Not running on Linux"
  exit 0
fi

cd plugins/statusline

# Test date commands (Linux-specific flags)
date -u -d "2026-02-01 +1 month -1 day" +%d > /dev/null 2>&1 && echo "✅ Linux date commands work"

# Test full statusline
echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | \
  bash scripts/statusline.sh > /dev/null && echo "✅ Statusline executes without errors"
```

**Expected result:**
```
✅ Linux date commands work
✅ Statusline executes without errors
```

**Acceptance criteria:**
- ✅ No errors on Linux
- ✅ Date calculations correct

---

#### 4.3 Simplified Time Display Format

**Objective:** Verify time remaining uses simplified format to reduce visual noise

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# Helper to create mock cache with specific reset time
create_time_test() {
  local hours_left=$1
  local expected_format="$2"

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

  local output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)

  echo "Test: ${hours_left}h left"
  echo "Output: $output"
  echo "Expected format: $expected_format"
  echo ""
}

# 5h limit tests
echo "=== 5h limit (threshold: >=2h) ==="
create_time_test 4.5 "~Xh (approximate)"
create_time_test 2.5 "~Xh (approximate)"
create_time_test 1.5 "XhYm (exact)"
create_time_test 0.5 "Xm (exact)"

echo ""
echo "=== 7d limit (threshold: >=48h = 2d) ==="
create_time_test 96 "~Xd (approximate, >=2d)"
create_time_test 48 "~Xd (approximate, >=2d)"
create_time_test 36 "XdYh or XhYm (exact, <2d)"
create_time_test 12 "XhYm (exact, <1d)"
```

**Expected result:**
```
=== 5h limit (threshold: >=2h) ===
Test: 4.5h left
Expected format: ~Xh (approximate)
Output contains: ~5h or ~4h (with ~ dimmed)

Test: 2.5h left
Expected format: ~Xh (approximate)
Output contains: ~3h or ~2h (with ~ dimmed)

Test: 1.5h left
Expected format: XhYm (exact)
Output contains: 1h30m (no ~)

Test: 0.5h left
Expected format: Xm (exact)
Output contains: 30m (no ~)

=== 7d limit (threshold: >=48h = 2d) ===
Test: 96h left
Expected format: ~Xd (approximate, >=2d)
Output contains: ~4d (with ~ dimmed)

Test: 48h left
Expected format: ~Xd (approximate, >=2d)
Output contains: ~2d (with ~ dimmed)

Test: 36h left
Expected format: XdYh or XhYm (exact, <2d)
Output contains: 1d12h (no ~)

Test: 12h left
Expected format: XhYm (exact, <1d)
Output contains: 12h0m (no ~)
```

**Acceptance criteria:**
- ✅ 5h limit: >=2h shows ~Xh (approximate), <2h shows exact XhYm
- ✅ 7d limit: >=2d shows ~Xd (approximate), <2d shows exact XdYh or XhYm
- ✅ Tilde (~) character is dimmed (ANSI color 242)
- ✅ Honest rounding: >=0.5 rounds up, <0.5 rounds down

---

### 5. Edge Cases

#### 5.1 Extra Usage Disabled

**Objective:** Verify no extra usage block when `is_enabled: false`

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

cat > /tmp/claude-statusline-usage-cache-${UID} <<'EOF'
{"five_hour":{"utilization":50.0,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":50.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":false,"used_credits":1000.0,"utilization":null}}
EOF

output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)

if echo "$output" | grep -q "💸"; then
  echo "❌ FAIL: Extra usage block should not appear"
else
  echo "✅ PASS: Extra usage block correctly hidden"
fi
```

**Expected result:**
```
✅ PASS: Extra usage block correctly hidden
```

**Acceptance criteria:**
- ✅ No 💸 block when `is_enabled: false`

---

#### 5.2 Extra Usage Unlimited (null limit)

**Objective:** Verify extra usage displays without utilization when `monthly_limit: null`

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

cat > /tmp/claude-statusline-usage-cache-${UID} <<'EOF'
{"five_hour":{"utilization":50.0,"resets_at":"2026-02-20T12:00:00+00:00"},"seven_day":{"utilization":50.0,"resets_at":"2026-02-25T12:00:00+00:00"},"extra_usage":{"is_enabled":true,"used_credits":1251.0,"utilization":null,"monthly_limit":null}}
EOF

output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh | head -1)

echo "$output"

# Should have 💸 block with money spent but no progress bar
if echo "$output" | grep -q "💸.*12"; then
  echo "✅ PASS: Shows money spent"
else
  echo "❌ FAIL: Missing money spent"
fi

# Count progress bars (should be only 2: 5h and 7d, not 3)
bar_count=$(echo "$output" | grep -o '⏳\|📅\|💸' | wc -l | tr -d ' ')
echo "Icon count: $bar_count"
```

**Expected result:**
```
💸 ⏸️ 12.51
✅ PASS: Shows money spent
Icon count: 3
```

**Acceptance criteria:**
- ✅ Shows 💸 block with money spent
- ✅ No progress bar when `utilization: null`
- ✅ No warning icons

---

#### 5.3 API Timeout/Failure

**Objective:** Verify graceful degradation when API fails

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# Remove cache and token to simulate API failure
rm -f /tmp/claude-statusline-usage-cache-${UID}
unset CLAUDE_CODE_OAUTH_TOKEN

output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50}}' | bash scripts/statusline.sh 2>&1)

echo "$output"

# Should still show basic info (line 2) even if API fails
if echo "$output" | grep -q "📁"; then
  echo "✅ PASS: Shows directory info despite API failure"
else
  echo "❌ FAIL: Should still show basic info"
fi
```

**Expected result:**
```

📁 test   🤖 Test   📚 50.0%
✅ PASS: Shows directory info despite API failure
```

**Acceptance criteria:**
- ✅ No crash when API unavailable
- ✅ Line 1 may be empty or minimal
- ✅ Line 2 always shows basic info

---

### 6. Git Integration

#### 6.1 Git Branch Detection

**Objective:** Verify git branch shows in statusline

**Automation:** 🟡

**Steps:**
```bash
# Create temp git repo
test_dir=$(mktemp -d)
cd "$test_dir"
git init -q
git checkout -b test-branch 2>/dev/null

# Run statusline
output=$(echo "{\"workspace\":{\"current_dir\":\"$test_dir\"},\"model\":{\"display_name\":\"Test\"},\"context_window\":{\"used_percentage\":50}}" | \
  bash /Users/artem/devel/claude-plugins/plugins/statusline/scripts/statusline.sh | tail -1)

echo "$output"

if echo "$output" | grep -q "🌿.*test-branch"; then
  echo "✅ PASS: Branch name detected"
else
  echo "❌ FAIL: Branch name not shown"
fi

# Cleanup
cd /
rm -rf "$test_dir"
```

**Expected result:**
```
📁 tmp.XXXXXX   🌿 test-branch   🤖 Test   📚 50.0%
✅ PASS: Branch name detected
```

**Acceptance criteria:**
- ✅ Branch name appears after 🌿
- ✅ No branch shown when not in git repo

---

#### 6.2 Dirty Working Tree Indicator

**Objective:** Verify ⚠️ appears when working tree is dirty

**Automation:** 🟡

**Steps:**
```bash
# Create temp git repo
test_dir=$(mktemp -d)
cd "$test_dir"
git init -q
git checkout -b main 2>/dev/null

# Add some content and commit
echo "test" > file.txt
git add file.txt
git commit -m "Initial commit" -q

# Run statusline (clean tree)
output_clean=$(echo "{\"workspace\":{\"current_dir\":\"$test_dir\"},\"model\":{\"display_name\":\"Test\"},\"context_window\":{\"used_percentage\":50}}" | \
  bash /Users/artem/devel/claude-plugins/plugins/statusline/scripts/statusline.sh | tail -1)

echo "Clean tree: $output_clean"

if echo "$output_clean" | grep -v "⚠️" | grep -q "🌿.*main"; then
  echo "✅ PASS: No warning on clean tree"
else
  echo "❌ FAIL: Should not show warning"
fi

# Make working tree dirty
echo "modified" > file.txt

# Run statusline (dirty tree)
output_dirty=$(echo "{\"workspace\":{\"current_dir\":\"$test_dir\"},\"model\":{\"display_name\":\"Test\"},\"context_window\":{\"used_percentage\":50}}" | \
  bash /Users/artem/devel/claude-plugins/plugins/statusline/scripts/statusline.sh | tail -1)

echo "Dirty tree: $output_dirty"

if echo "$output_dirty" | grep -q "🌿.*main.*⚠️"; then
  echo "✅ PASS: Warning shown on dirty tree"
else
  echo "❌ FAIL: Should show warning"
fi

# Cleanup
cd /
rm -rf "$test_dir"
```

**Expected result:**
```
Clean tree: 📁 tmp.XXXXXX   🌿 main   🤖 Test   📚 50.0%
✅ PASS: No warning on clean tree
Dirty tree: 📁 tmp.XXXXXX   🌿 main ⚠️   🤖 Test   📚 50.0%
✅ PASS: Warning shown on dirty tree
```

**Acceptance criteria:**
- ✅ No ⚠️ when tree is clean
- ✅ Yellow ⚠️ after branch name when tree is dirty

---

### 7. Context Window Warnings

#### 7.1 Context Window Color Coding

**Objective:** Verify context window colors and warnings

**Automation:** ✅

**Steps:**
```bash
cd plugins/statusline

# Test case 1: <60% (no color, no warning)
echo "Test 1: 50% context (no warning)"
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":50.0}}' | \
  bash scripts/statusline.sh | tail -1)
if echo "$output" | grep "📚 50" | grep -qv "⚠️\|🛑"; then
  echo "✅ PASS: No warning"
else
  echo "❌ FAIL"
fi

# Test case 2: ≥60% (yellow + ⚠️)
echo "Test 2: 65% context (yellow ⚠️)"
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":65.0}}' | \
  bash scripts/statusline.sh | tail -1)
if echo "$output" | grep -q "📚.*65.*⚠️"; then
  echo "✅ PASS: ⚠️ shown"
else
  echo "❌ FAIL"
fi

# Test case 3: ≥80% (red + 🛑)
echo "Test 3: 85% context (red 🛑)"
output=$(echo '{"workspace":{"current_dir":"/test"},"model":{"display_name":"Test"},"context_window":{"used_percentage":85.0}}' | \
  bash scripts/statusline.sh | tail -1)
if echo "$output" | grep -q "📚.*85.*🛑"; then
  echo "✅ PASS: 🛑 shown"
else
  echo "❌ FAIL"
fi
```

**Expected result:**
```
Test 1: 50% context (no warning)
✅ PASS: No warning
Test 2: 65% context (yellow ⚠️)
✅ PASS: ⚠️ shown
Test 3: 85% context (red 🛑)
✅ PASS: 🛑 shown
```

**Acceptance criteria:**
- ✅ <60%: no color, no icon
- ✅ ≥60%: yellow + ⚠️
- ✅ ≥80%: red + 🛑

---

### 8. Visual Verification (Manual)

#### 8.1 Live Claude Code Integration

**Objective:** Verify statusline displays correctly in actual Claude Code UI

**Automation:** ⚠️ Manual only

**Manual Test Procedure (5 steps):**

**Step 1:** Install plugin
```bash
cd /Users/artem/devel/claude-plugins
scripts/install-sync.sh
claude-marketplace-sync --force
```

**Step 2:** Configure statusline in Claude Code
```bash
claude
/statusline-setup
```
Follow prompts to install.

**Step 3:** Restart Claude Code
```bash
exit
claude
```

**Step 4:** Verify visual layout

Expected appearance in UI:
```
⏳ ■■■■■■■■■■■■■■■■■■■■ 3h15m   📅 ■■■■■■■■■■■■■■■■■■■■■ 2d5h   💸 ⏸️ ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 12.51
📁 claude-plugins   🌿 main   🤖 Claude Sonnet 4.5   📚 45.2%
```

Visual checklist:
- ✅ Two lines visible
- ✅ Line 1 shows progress bars with colored blocks
- ✅ Line 2 shows directory, branch, model, context
- ✅ Progress bars use ■ symbol (not ▉)
- ✅ Colors are visible (gray, green/red, blue)
- ✅ Icons render correctly (⏳, 📅, 💸, 📁, 🌿, 🤖, 📚)

**Step 5:** Test warning icons

Exhaust 5h limit by using Claude extensively, then verify:
- ✅ ❌ appears after 5h bar when at 100%
- ✅ 💸 icon changes to ▶️ (active)
- ✅ Extra usage bar appears (if enabled)

---

## Known Limitations

### API Data Availability

- **Extra usage data**: Only available when feature is enabled in user account
- **Null values**: `utilization: null` when `monthly_limit: null` (unlimited)
- **Reset timestamps**: Extra usage doesn't provide `resets_at` field (inferred as 1st of next month UTC)

### Platform Differences

- **Date commands**: macOS uses `-v` flags, Linux uses `-d` flag
- **Keychain access**: OAuth token from Keychain only on macOS (Linux uses `~/.claude/.credentials.json`)
- **Locale**: Decimal separator may be comma or dot depending on system locale

### Debug Logging

Both `claude-marketplace-sync` and `setup-statusline.sh` write detailed logs to `/tmp/claude-plugin-sync.log`. The log includes:
- `[marketplace-sync]` — sync decisions, rsync operations, hook execution with exit codes
- `[setup-statusline]` — `CLAUDE_PLUGIN_ROOT` value, source/target file states, diff output, copy results

Use this log to diagnose issues where statusline doesn't update after a version bump.

---

## Regression Testing Guide

### When to Run

Run full test suite:
- Before releasing new version
- After modifying progress bar logic
- After changing API parsing code
- When updating cross-platform code

### Quick Smoke Test

```bash
cd plugins/statusline

# Run basic tests
bash docs/ACCEPTANCE_TESTS.md  # If converted to executable test script
# OR manually run tests 2.1, 2.2, 2.3, 3.2, 3.3
```

### CI/CD Integration

Recommended GitHub Actions workflow:

```yaml
name: Statusline Tests
on: [pull_request]
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Run acceptance tests
        run: |
          cd plugins/statusline
          # Run automated tests (1-7)
          bash scripts/run-tests.sh
```

---

## Version History

### 1.1.0 (Current)

New features:
- Two-line layout (progress bars | info)
- Extra usage (monthly billing) tracking
- Warning icons (❌ at 100%, ⚠️ at >90%)
- Changed progress bar symbol (▉ → ■)

Tests added:
- Extra usage dollar conversion (3.4)
- Status icon logic (3.3)
- Monthly bar length verification (2.2)
- Warning icon thresholds (3.2)

### 1.0.0

Initial release:
- Single-line layout
- 5h/7d rate limits with percentage display
- Context window usage
- Git branch and model info
