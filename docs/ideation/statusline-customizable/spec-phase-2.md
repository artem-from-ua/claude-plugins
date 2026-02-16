# Implementation spec: Statusline customizable - Phase 2

**PRD**: ./prd-phase-2.md
**Estimated effort**: S

## Technical approach

Update the `/statusline-setup` SKILL.md to include a preset selection step. The skill instructs Claude to use `AskUserQuestion` (via the statusline-setup agent) to let the user pick a preset, then writes `~/.claude/statusline.json`. Also update acceptance tests.

## File changes

### Modified files

| File path | Changes |
|-----------|---------|
| `plugins/statusline/commands/statusline-setup/SKILL.md` | Add preset selection step, config file writing |
| `plugins/statusline/docs/ACCEPTANCE_TESTS.md` | Add test cases for presets, config, overrides |
| `plugins/statusline/.claude-plugin/plugin.json` | Version bump |

## Implementation details

### 1. Update SKILL.md

Add a new step between current steps 3 and 4:

```markdown
4. Ask the user which preset they'd like:
   - **Classic** (default): Emoji icons + progress bars + percentage + time-to-reset
   - **Text**: Text labels + percentage + time-to-reset only (no emoji, no progress bars)

5. Write the selected preset to `~/.claude/statusline.json`:
   ```bash
   echo '{"preset": "classic"}' | jq . > ~/.claude/statusline.json
   # or
   echo '{"preset": "text"}' | jq . > ~/.claude/statusline.json
   ```
   If the file already exists, merge the preset into it:
   ```bash
   jq '.preset = "text"' ~/.claude/statusline.json > /tmp/sl-cfg-$UID.json && mv /tmp/sl-cfg-$UID.json ~/.claude/statusline.json
   ```

6. Mention that users can further customize by editing `~/.claude/statusline.json`:
   - `"emojis": true/false` - override emoji display
   - `"progress_bars": true/false` - override progress bar display
```

### 2. Update acceptance tests

Add new test categories:

- **Config loading**: Test that config file is read, defaults applied, invalid JSON handled
- **Preset switching**: Test classic vs text output
- **Override behavior**: Test individual field overrides on top of presets
- **Text rendering**: Verify no Unicode above U+007F in text preset output

### 3. Version bump

Bump to 1.3.0 (MINOR - new feature: customizable presets).

## Implementation steps

1. Update SKILL.md with preset selection and config writing steps
2. Update ACCEPTANCE_TESTS.md with new test categories
3. Bump version in plugin.json
4. Commit with changelog

## Validation commands

```bash
# Verify SKILL.md is valid YAML frontmatter
head -5 plugins/statusline/commands/statusline-setup/SKILL.md

# Verify plugin.json version
jq '.version' plugins/statusline/.claude-plugin/plugin.json
```

---

*This spec is ready for implementation.*
