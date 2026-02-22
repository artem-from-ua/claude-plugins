# Implementation spec: Statusline customizable - Phase 1

**PRD**: ./prd-phase-1.md
**Estimated effort**: M

## Technical approach

Add a config loading section at the top of `statusline.sh` that reads `~/.claude/statusline.json` via `jq`. Config values are resolved with a precedence chain: explicit overrides > preset defaults > hardcoded defaults. The rendering sections are wrapped in conditionals based on `cfg_emojis` and `cfg_progress_bars`.

The text preset replaces emoji icons with short text labels and replaces progress bars with inline percentage + time-to-reset text. The classic preset gets percentage display added alongside existing progress bars.

No new files needed - this is entirely changes to `statusline.sh`.

## File changes

### Modified files

| File path | Changes |
|-----------|---------|
| `plugins/statusline/scripts/statusline.sh` | Add config loading, conditional rendering for emojis/bars, percentage display |

## Implementation details

### 1. Config loading (insert after line 16, before ANSI colors)

```bash
# Load config from ~/.claude/statusline.json
config_file="$HOME/.claude/statusline.json"
cfg_preset="classic"
cfg_emojis=""
cfg_progress_bars=""

if [ -f "$config_file" ]; then
  cfg_preset=$(jq -r '.preset // "classic"' "$config_file" 2>/dev/null)
  cfg_emojis=$(jq -r '.emojis // empty' "$config_file" 2>/dev/null)
  cfg_progress_bars=$(jq -r '.progress_bars // empty' "$config_file" 2>/dev/null)
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

# Explicit overrides take precedence
[ "$cfg_emojis" = "true" ] && use_emojis=true
[ "$cfg_emojis" = "false" ] && use_emojis=false
[ "$cfg_progress_bars" = "true" ] && use_progress_bars=true
[ "$cfg_progress_bars" = "false" ] && use_progress_bars=false
```

### 2. Emoji replacement

Define icon variables after config loading:

```bash
# Icons (emoji or text based on config)
if [ "$use_emojis" = "true" ]; then
  ICON_5H="⏳"; ICON_7D="📅"; ICON_1M="💸"
  ICON_DIR="📁"; ICON_BRANCH="🌿"; ICON_MODEL="🤖"; ICON_CTX="📚"
else
  ICON_5H="5h:"; ICON_7D="7d:"; ICON_1M="1M:"
  ICON_DIR="DIR:"; ICON_BRANCH="BR:"; ICON_MODEL="MDL:"; ICON_CTX="CTX:"
fi
```

Then replace all hardcoded emoji references with these variables. Note: the resolution labels like `format_resolution "5h" "10m"` are separate from the icons - those stay as-is in classic mode. In text mode, the resolution label IS the icon (e.g., "5h:" already conveys it), so the resolution formatting is skipped.

**Key decision**: In text preset, the resolution labels (e.g., "5h/10m") are redundant since the text icon "5h:" already identifies the section. Skip resolution display in text mode to save space.

### 3. Progress bar conditional

Wrap progress bar building in conditionals:

```bash
if [ "$use_progress_bars" = "true" ]; then
  five_bar=$(build_progress_bar "$five_int" "$five_time_pct" 30)
  five_indicator=$(get_limit_indicator "$five_int" "$five_time_pct")
  # ... existing bar + indicator + time layout
  five_block="${resolution_5h}${padding_5h}${five_bar}${SEP}${five_indicator}${SEP}${five_time_fmt}"
else
  # Text mode: percentage + time-to-reset
  five_pct_display="${five_int}${dim}%${rst}"
  five_block="${ICON_5H} ${five_pct_display} ${dim}resets${rst} ${five_time_with_dim}"
fi
```

Same pattern for 7d and extra usage blocks.

### 4. Percentage display in classic mode

In classic preset, insert percentage between the bar and time display:

```bash
# After building five_bar, before five_time_fmt
five_pct_display="${dim}${five_int}%${rst}"
five_block="${resolution_5h}${padding_5h}${five_bar}${SEP}${five_indicator}${SEP}${five_pct_display}${SEP}${five_time_fmt}"
```

This adds a compact "73%" between the indicator and time-to-reset. The percentage is dimmed since the bar already conveys it visually.

### 5. Line assembly

The line assembly at the bottom uses the same icon variables:

```bash
# Classic: 🤖 → $ICON_MODEL, 📁 → $ICON_DIR, etc.
line1="${five_block}   ${ICON_MODEL}${SEP}${model_display}${context_display}"
line2="${seven_block}   ${dir_with_warning}"
line3="${extra_block}   ${branch_with_warning}"
```

Where `dir_with_warning` and `branch_with_warning` use `$ICON_DIR` and `$ICON_BRANCH` respectively.

## Implementation steps

1. Add config loading section after `input=$(cat)` and before ANSI colors
2. Define icon variables based on `use_emojis`
3. Replace all hardcoded emoji with icon variables (7 replacements)
4. Add percentage display to classic preset (5h and 7d blocks)
5. Add conditional rendering: progress bar vs text-only for 5h, 7d, and extra blocks
6. In text mode, adjust line format to use text labels and skip resolution prefixes
7. Test: no config file produces identical output to current version
8. Test: `{"preset": "text"}` produces clean text output
9. Test: override combinations work correctly

## Error handling

| Error scenario | Handling strategy |
|----------------|-------------------|
| Config file missing | Silent fallback to defaults (classic preset) |
| Config file invalid JSON | `jq` returns empty, all config vars stay at defaults |
| Config has unknown fields | Ignored - only read known fields |
| Config has invalid preset name | Falls through to `*` case = classic |

## Validation commands

```bash
# Test with no config (should match current output)
echo '{"model":{"display_name":"Claude Sonnet 4.5"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}' | bash plugins/statusline/scripts/statusline.sh

# Test text preset
echo '{"preset":"text"}' > ~/.claude/statusline.json
echo '{"model":{"display_name":"Claude Sonnet 4.5"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}' | bash plugins/statusline/scripts/statusline.sh

# Test override
echo '{"emojis":false}' > ~/.claude/statusline.json
echo '{"model":{"display_name":"Claude Sonnet 4.5"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}' | bash plugins/statusline/scripts/statusline.sh

# Cleanup
rm ~/.claude/statusline.json
```

---

*This spec is ready for implementation. Follow the patterns and validate at each step.*
