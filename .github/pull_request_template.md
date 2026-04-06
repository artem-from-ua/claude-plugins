## Description

<!-- Describe what this PR does and why -->

## Changes

<!-- List key changes -->
-
-

## Plugin(s) Affected

<!-- List affected plugins, or "None" if only root-level files changed -->
<!-- Example: plantuml, semver -->


## Version Bump Required

<!-- CRITICAL: Version bump is REQUIRED before merge for any plugin changes -->
<!-- See CLAUDE.md "Version Bump Requirements" section -->

- [ ] ✅ Version bumped in `plugins/<name>/.claude-plugin/plugin.json`
- [ ] N/A (no plugin changes, only root-level files)

**Version change:**
- `<plugin-name>`: `<old-version>` → `<new-version>`

**Type of version bump:**
- [ ] MAJOR (breaking changes)
- [ ] MINOR (new features, backwards-compatible)
- [ ] PATCH (bug fixes, documentation)

**Reasoning:** <!-- Why this version bump type? -->

## Testing

<!-- Describe how you tested these changes -->
- [ ] Ran acceptance tests (if applicable)
- [ ] Tested in fresh Claude Code session

## Checklist

- [ ] All SKILL.md files have valid YAML frontmatter
- [ ] Hooks use `${CLAUDE_PLUGIN_ROOT}` (not `$(dirname "$0")`)
- [ ] Cross-platform compatibility (macOS + Linux)
- [ ] Updated ACCEPTANCE_TESTS.md (if behavior changed)
- [ ] **Version bumped before merge** (REQUIRED)
- [ ] Ready to merge

## Related Issues

<!-- Link related issues -->
Closes #
Related to #
