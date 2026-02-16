# Statusline customizable Contract

**Created**: 2026-02-16
**Confidence Score**: 96/100
**Status**: Draft

## Problem statement

The statusline plugin renders progress bars using Unicode block characters and emoji icons that are font-dependent - they look different across terminals and font configurations (e.g., Ghostty with CaskaydiaCoveNerdFontMono vs default macOS Terminal). Users can't easily understand what progress bars represent at a glance. Two critical pieces of information are missing: percentage of limit used and time until reset - which are exactly what makes the Claude Mac app usage view useful.

There's no way to customize the statusline output. Users who want a text-only experience (no emoji, no progress bars) are stuck with the current rendering.

## Goals

1. Support two presets - "classic" (current behavior) and "text" (percentage-based, no emoji, no progress bars) - selectable via `/statusline-setup`
2. Add percentage of limit used and time-to-reset for both 5h and 7d limits across both presets
3. Allow per-field overrides via `~/.claude/statusline.json` config file (e.g., disable emojis but keep progress bars)
4. Maintain current behavior as default - existing users are not surprised

## Success criteria

- [ ] Running with no config file produces identical output to current statusline (backward compatible)
- [ ] `~/.claude/statusline.json` with `{"preset": "text"}` produces a text-only statusline with no emoji and no Unicode block characters
- [ ] Text preset shows percentage used (e.g., "73%") for 5h and 7d limits
- [ ] Both presets show time-to-reset (e.g., "resets 2h14m") for 5h and 7d limits
- [ ] Individual overrides (e.g., `{"emojis": false}`) work on top of any preset
- [ ] `/statusline-setup` command offers preset selection
- [ ] statusline renders correctly in Ghostty, iTerm2, macOS Terminal, and common Linux terminals
- [ ] No performance regression - statusline still renders in under 500ms

## Scope boundaries

### In scope

- Config file format and loading (`~/.claude/statusline.json`)
- Two presets: "classic" and "text"
- Per-field overrides: emojis on/off, progress bars on/off
- Percentage display for 5h and 7d limits
- Time-to-reset display for 5h and 7d limits
- Updated `/statusline-setup` command with preset selection
- Updated acceptance tests

### Out of scope

- Third "compact" single-line preset - deferred, not needed for MVP
- Color theme customization - separate concern
- Custom progress bar characters - too niche
- Configuring which info fields appear (all fields always shown in both presets)

### Future considerations

- Compact/single-line preset for small terminals
- User-defined color schemes
- Per-field visibility toggles (show/hide individual sections)

---

*This contract was generated from brain dump input. Review and approve before proceeding to PRD generation.*
