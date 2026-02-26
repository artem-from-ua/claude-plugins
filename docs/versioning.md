# Version Bump Requirements

**CRITICAL:** Before merging any PR to `main`, you MUST bump the version of affected plugins. This is required for `claude-marketplace-sync` to pick up changes.

---

## When to Bump Version

Bump version in `plugins/<name>/.claude-plugin/plugin.json` for ANY change to that plugin:
- Code changes (scripts, hooks, templates)
- Documentation changes (SKILL.md, ACCEPTANCE_TESTS.md)
- Configuration changes (plugin.json, hooks.json)

**Exception:** Changes to root-level files (CLAUDE.md, README.md) or other plugins do NOT require version bump.

---

## Semantic Versioning Rules

Follow [Semantic Versioning 2.0.0](https://semver.org/):

**MAJOR version (X.0.0)** — Breaking changes:
- Removed features or commands
- Changed command/skill names or signatures
- Incompatible hook behavior changes
- Requires user action to migrate

Examples:
- Renamed skill from `plantuml-validate` to `validate-plantuml` → `1.5.3` to `2.0.0`
- Removed deprecated command → `1.8.2` to `2.0.0`
- Changed hook output format breaking downstream tools → `1.3.1` to `2.0.0`

**MINOR version (x.Y.0)** — New features, backwards-compatible:
- New commands or skills
- New hooks
- New configuration options (with defaults)
- Enhanced functionality that doesn't break existing usage
- Non-breaking behavior changes

Examples:
- Added new diagram type to plantuml-diagram-guide → `1.2.0` to `1.3.0`
- Added `--force` flag to existing command → `1.1.5` to `1.2.0`
- New PostToolUse hook for additional file types → `1.4.2` to `1.5.0`
- Made SessionStart rules more strict (PR #27) → `1.0.0` to `1.1.0`

**PATCH version (x.y.Z)** — Bug fixes, no new features:
- Fixed bugs in existing functionality
- Performance improvements
- Documentation fixes (typos, clarifications)
- Updated acceptance tests without behavior changes
- Refactoring without behavior changes

Examples:
- Fixed encoder crash on empty input → `1.2.3` to `1.2.4`
- Corrected typo in SKILL.md → `1.3.0` to `1.3.1`
- Performance optimization in sync script → `1.1.8` to `1.1.9`
- Updated ACCEPTANCE_TESTS.md to reflect current behavior → `1.2.5` to `1.2.6`

---

## Version Bump Workflow (Automated by Claude Code)

**Claude Code MUST follow this workflow automatically:**

1. **Detect plugin changes**: Check if any files under `plugins/<name>/` were modified
2. **Get current version from main**:
   ```bash
   git show main:plugins/<name>/.claude-plugin/plugin.json | jq -r '.version'
   ```
3. **Determine semantic increment**: Based on change type (MAJOR/MINOR/PATCH)
4. **Bump version** in `plugins/<name>/.claude-plugin/plugin.json`
5. **Create version bump commit**:
   ```bash
   git add plugins/<name>/.claude-plugin/plugin.json
   git commit -m "Bump <plugin-name> version to X.Y.Z

   Version bump for PR #XX: <description>

   Changes in X.Y.Z:
   - <list key changes>

   Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
   ```
6. **Then create PR** (NEVER before version bump)
7. **After merge**: User runs `claude-marketplace-sync --force` to update cache

---

## Handling Version Conflicts

If rebasing on main reveals version conflict:

1. **Check current main version**:
   ```bash
   git show main:plugins/<name>/.claude-plugin/plugin.json | jq -r '.version'
   ```
2. **Compare with your bumped version**:
   - If main has higher version → increment from main's version
   - If main has same version → increment again (likely concurrent PRs)
   - If main has lower version → keep your version (already correct)
3. **Update version in plugin.json** if needed
4. **Amend commit** with new version number:
   ```bash
   git add plugins/<name>/.claude-plugin/plugin.json
   git commit --amend
   ```
5. **Continue rebase/merge**

Example conflict scenario:
- You started from main@1.1.0, bumped to 1.1.1
- Meanwhile, someone merged PR bumping to 1.2.0
- On rebase: detect main is now 1.2.0
- Your PATCH change should become 1.2.1 (not 1.1.1)

---

## Multiple Plugins Changed

If your PR affects multiple plugins, bump ALL of them:

```bash
# PR changed both plantuml and statusline
# Bump both versions in separate commits or one commit

git add plugins/plantuml/.claude-plugin/plugin.json
git add plugins/statusline/.claude-plugin/plugin.json
git commit -m "Bump plugin versions: plantuml 1.2.0, statusline 1.1.0

Version bumps for PR #XX: <description>

plantuml 1.1.5 → 1.2.0:
- <changes>

statusline 1.0.3 → 1.1.0:
- <changes>"
```

---

## Verification

After version bump:
1. Check `plugin.json` contains new version
2. After merge, run `claude-marketplace-sync --force --verbose`
3. Verify new version appears in `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`
4. Test in fresh Claude Code session

---

## Why This Matters

Without version bumps, `claude-marketplace-sync` won't update plugin files in cache because it only syncs when version changes. This means:
- ❌ Users won't see your changes (old version still loaded)
- ❌ Manual testing becomes invalid (testing old code)
- ❌ Bug fixes won't reach users

**Always bump versions before merge!**
