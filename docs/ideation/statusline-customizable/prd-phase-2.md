# PRD: Statusline customizable - Phase 2

**Contract**: ./contract.md
**Phase**: 2 of 2
**Focus**: `/statusline-setup` integration and acceptance tests

## Phase overview

This phase updates the `/statusline-setup` command to offer preset selection and writes the config file. It also updates acceptance test documentation to cover all new functionality.

This is Phase 2 because it depends on the config format and rendering logic from Phase 1. The setup command is the user-facing entry point for configuration.

## User stories

1. As a statusline user, I want `/statusline-setup` to let me choose a preset so I don't have to manually edit JSON.
2. As a statusline user, I want acceptance tests that cover the new presets so I can verify everything works after updates.

## Functional requirements

### `/statusline-setup` command update

- **FR-2.1**: Add a preset selection step to the setup flow. Options: "Classic (emoji + progress bars)" and "Text (percentages only, no emoji)".
- **FR-2.2**: Write selected preset to `~/.claude/statusline.json`. Create the file if it doesn't exist. Merge with existing config if it does.
- **FR-2.3**: After writing config, copy the updated `statusline.sh` to `~/.claude/statusline.sh` (trigger the setup hook).
- **FR-2.4**: Show a preview of what the statusline will look like with the selected preset.

### Acceptance tests

- **FR-2.5**: Update `plugins/statusline/docs/ACCEPTANCE_TESTS.md` with test cases for config loading, preset switching, override behavior, and text preset rendering.
- **FR-2.6**: Include manual test procedures for verifying rendering in different terminals.

## Non-functional requirements

- **NFR-2.1**: Setup command completes in under 5 seconds.
- **NFR-2.2**: Config file is human-readable JSON with comments explaining each field.

## Dependencies

### Prerequisites

- Phase 1 complete (config loading, presets, rendering)

### Outputs for next phase

- N/A (final phase)

## Acceptance criteria

- [ ] `/statusline-setup` offers preset selection
- [ ] Selected preset written to `~/.claude/statusline.json`
- [ ] Existing config preserved when adding preset
- [ ] Acceptance tests document all new functionality
- [ ] Version bumped per CLAUDE.md requirements

---

*Review this PRD and provide feedback before spec generation.*
