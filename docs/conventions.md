# Plugin Conventions

Reference for plugin authors covering configuration, hook scripts, and cross-platform compatibility.

---

## Plugin Config Convention

Plugins that need project-level configuration store config files in `.claude-plugin/`:

| Scope | Path | Committed? | Example |
|-------|------|-----------|---------|
| **Project** (shared with team) | `{project}/.claude-plugin/<name>.json` | ✅ Yes | `.claude-plugin/playbook.json` |
| **Global** (personal) | `~/.claude/<name>.json` | ❌ No | `~/.claude/playbook.json` |

**Resolution order:** Project config takes priority over global. If both exist, project wins.

**Backwards compatibility:** Scripts also check `{project}/.claude/<name>.json` as fallback for configs created before this convention.

**Setup wizards** (`/playbook-setup`, `/semver-setup`, `/git-branch-naming-setup`, `/retroscope-setup`) write to `.claude-plugin/<name>.json` by default.

---

## Skills & plugin.json

**IMPORTANT: `plugin.json` MUST include both `"commands"` and `"skills"` fields** for Claude Code to expose SKILL.md files to the skill system. Without the `"skills"` field, commands are not discoverable via `/skill-name` even if their SKILL.md files exist.

If your plugin only has `commands/` (no separate `skills/` directory), point both fields at the same path:

```json
{
  "commands": ["./commands/"],
  "skills": ["./commands/"]
}
```

If your plugin has both directories:

```json
{
  "commands": ["./commands/"],
  "skills": ["./skills/"]
}
```

**WARNING: Duplicate skills in `/context`** — Claude Code does NOT deduplicate SKILL.md files between `commands/` and `skills/` directories. If the same `name:` frontmatter appears in both, it will show twice in `/context`. Rules:

- **Auto-invocable skills** (e.g., `plantuml-diagram-guide`): place SKILL.md in `skills/` only. The `commands/` directory should have a **different** skill (e.g., `plantuml-validate`), or no SKILL.md at all.
- **Command-only plugins** (no auto-invocable skills, only user-invoked commands like `/retro`): use `"skills": []` in plugin.json. Commands work fine without the skills field — they are loaded from `commands/` when invoked.
- **Never** have the same `name:` in both `commands/foo/SKILL.md` and `skills/foo/SKILL.md`.

---

## Hook Scripts Convention

In `hooks.json`, always use `${CLAUDE_PLUGIN_ROOT}` to reference plugin files — never `$(dirname "$0")` (it resolves to the shell binary path, not the plugin directory):

```json
{
  "type": "command",
  "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/my-hook.sh\""
}
```

Inside scripts, use a fallback so they work both as hooks and when run directly:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
```

---

## Cross-Platform Compatibility

All scripts must work on both macOS and Linux. Use these patterns:

**Platform detection:**
```bash
if [ "$(uname)" = "Darwin" ]; then
  # macOS
else
  # Linux
fi
```

**`stat` — file modification time:**
- macOS: `stat -f %m "$file"`
- Linux: `stat -c %Y "$file"`

**`date` — parsing ISO timestamps:**
- macOS: `date -juf "%Y-%m-%dT%H:%M:%S" "$str" +%s`
- Linux: `date -ud "$str" +%s`

**OAuth credentials** (priority order):
1. `$CLAUDE_CODE_OAUTH_TOKEN` env var (any platform)
2. macOS Keychain: `security find-generic-password -s "Claude Code-credentials" -w`
3. Linux credentials file: `~/.claude/.credentials.json`

**Shared `/tmp` files:** Always append `-${UID}` to avoid collisions in multi-user environments.

---

## Plugin Cache Sync

Claude Code has a bug where the plugin cache is not invalidated on auto-update ([#14061](https://github.com/anthropics/claude-code/issues/14061), [#15621](https://github.com/anthropics/claude-code/issues/15621), [#15642](https://github.com/anthropics/claude-code/issues/15642)).

**Solution:** The standalone `scripts/claude-marketplace-sync` script runs _before_ Claude Code starts, pulling marketplace repos and rsyncing into cache. Run `scripts/install-sync.sh` to install — it configures PATH and shell alias automatically. See README for details.

**Debug logging:** Both `claude-marketplace-sync` and plugin SessionStart hooks log detailed operations to `/tmp/claude-plugin-sync.log`. Use this file to diagnose sync issues (stale `CLAUDE_PLUGIN_ROOT`, failed hook execution, rsync problems).
