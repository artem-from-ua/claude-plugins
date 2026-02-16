# PRD: Statusline customizable - Phase 1

**Contract**: ./contract.md
**Phase**: 1 of 2
**Focus**: Config loading, text preset, percentage and time-to-reset display

## Phase overview

This phase builds the config infrastructure and the text preset. After this phase, users can create `~/.claude/statusline.json` to switch presets and override individual settings. Both presets will show percentage used and time-to-reset for 5h and 7d limits.

This is Phase 1 because the rendering logic must exist before the `/statusline-setup` command can configure it. The config file format drives everything downstream.

## User stories

1. As a statusline user, I want to see what percentage of my 5h and 7d limits I've used so I can gauge at a glance how much capacity remains.
2. As a statusline user, I want to see when my limits reset so I can decide whether to wait or keep working.
3. As a statusline user, I want a text-only mode with no emojis or progress bars so the display works consistently across all terminals and fonts.
4. As a statusline user, I want to override individual settings (e.g., disable emojis but keep progress bars) so I can customize to my preference.

## Functional requirements

### Config loading

- **FR-1.1**: On startup, read `~/.claude/statusline.json` if it exists. If missing or invalid JSON, use defaults silently.
- **FR-1.2**: Config schema: `{"preset": "classic"|"text", "emojis": bool, "progress_bars": bool}`. All fields optional.
- **FR-1.3**: Preset sets defaults for `emojis` and `progress_bars`. Explicit overrides take precedence over preset defaults.
- **FR-1.4**: Preset "classic": `emojis=true, progress_bars=true` (current behavior). Preset "text": `emojis=false, progress_bars=false`.
- **FR-1.5**: Default preset is "classic" (no config = current behavior).

### Text preset rendering

- **FR-1.6**: When `emojis=false`, replace all emoji icons with text labels: `5h:`, `7d:`, `1M:`, `DIR:`, `BR:`, `MDL:`, `CTX:`.
- **FR-1.7**: When `progress_bars=false`, omit the progress bar entirely. Display percentage and time-to-reset in its place.
- **FR-1.8**: Text preset line format example: `5h: 73% resets 2h14m | MDL: Opus 4.6 | CTX: 42%`

### Percentage display

- **FR-1.9**: Show usage percentage (integer, e.g., "73%") for 5h and 7d limits in both presets.
- **FR-1.10**: In classic preset, percentage appears after the progress bar (before time-to-reset). In text preset, percentage replaces the progress bar.

### Time-to-reset display

- **FR-1.11**: Show time-to-reset for both 5h and 7d limits (already partially implemented as `format_time_remaining`).
- **FR-1.12**: Format: "2h14m" for 5h limit, "3d5h" for 7d limit. Use existing `format_time_remaining` function.

## Non-functional requirements

- **NFR-1.1**: Config file read adds no more than 10ms to startup time.
- **NFR-1.2**: Text preset output must contain only ASCII printable characters (no Unicode above U+007F) except ANSI escape codes.
- **NFR-1.3**: Backward compatible - no config file produces identical output to current version.

## Dependencies

### Prerequisites

- None (Phase 1 is the first phase)

### Outputs for next phase

- Config loading mechanism (`load_config` function in statusline.sh)
- Config variables available: `cfg_preset`, `cfg_emojis`, `cfg_progress_bars`
- Text preset rendering logic

## Acceptance criteria

- [ ] No `~/.claude/statusline.json` - output identical to current statusline
- [ ] `{"preset": "text"}` - no emoji, no progress bars, percentages and times shown
- [ ] `{"preset": "classic"}` - identical to current but with percentage added
- [ ] `{"emojis": false}` - text labels instead of emoji, progress bars still shown
- [ ] `{"progress_bars": false}` - no bars, percentage in place, emojis still shown
- [ ] `{"preset": "text", "emojis": true}` - override: emojis ON but no progress bars
- [ ] Invalid JSON in config - silently falls back to defaults
- [ ] Missing config file - silently uses defaults

---

*Review this PRD and provide feedback before spec generation.*
