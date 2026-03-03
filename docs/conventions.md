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

**Setup wizards** (e.g., `/playbook-setup`, `/semver-setup`, `/git-branch-naming-setup`, `/kb-grooming-setup`, `/retroscope-setup`, `/technology-explainer-setup`) write to `.claude-plugin/<name>.json` by default. The statusline plugins (`/statusline-setup`, `/statusline-compact:statusline-setup`) configure `~/.claude/settings.json` instead.

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

### SKILL.md files

SKILL.md files also reference plugin files (scripts, templates, presets). Use `${CLAUDE_PLUGIN_ROOT}` for anything outside the skill directory:

```bash
# CORRECT — runtime variable, resolves to plugin root
bash "${CLAUDE_PLUGIN_ROOT}/scripts/ctx-show.sh"
cat "${CLAUDE_PLUGIN_ROOT}/templates/default.json"

# WRONG — SKILL_DIR parent-traversal is fragile (LLM may mis-infer the directory)
bash "${SKILL_DIR}/../../scripts/ctx-show.sh"
```

`${SKILL_DIR}` is safe only for co-located references (e.g., `${SKILL_DIR}/references/catalog.md`). See [`docs/AUTHORING.md`](AUTHORING.md) — §5 "Path references in SKILL.md" for the full convention.

---

## Cache Determinism

SessionStart hooks inject text into Claude's system prompt. The Anthropic API caches prompt prefixes — if the prefix is identical across sessions, it hits the cache (lower latency, lower cost). Non-deterministic hook output invalidates the cache on every session start.

**Plugin classification by determinism:**

| Category | Plugins | Why |
|----------|---------|-----|
| **Deterministic** | `plantuml`, `git-branch-naming`, `retroscope`, `statusline`, `statusline-compact` | Static output — same input always produces identical text. Safe for prefix caching. |
| **Config-dependent** | `playbook`, `semver`, `technology-explainer` | Output depends on user config files (`.claude-plugin/*.json`). Config rarely changes between sessions, so practically stable. |
| **No SessionStart hooks** | `context`, `kb-grooming`, `ai-fortune` | These plugins use only commands/skills, no hook output injected at session start. |

**Rule for new plugins:** SessionStart hooks MUST NOT use `date`, `git log`, `$RANDOM`, network calls, or any other non-deterministic data source in their output. Config-dependent output is acceptable — it changes rarely and the caching benefit is preserved across the majority of sessions.

---

## Token Budget

Every source injected at session start costs context tokens. The `context` plugin (`/ctx-show`) warns when total context load exceeds a configurable threshold.

**Per-component budgets:**

| Component | Budget | Notes |
|-----------|--------|-------|
| SessionStart hook output | ≤300 tokens | Per plugin. Rules only — no catalogs. |
| Playbook preset RULES zone | ≤150 tokens | Per preset. Standard ~100-120, critical up to ~200. |
| Skill description (plugin.json) | ≤50 tokens | Per skill. Lead with trigger signal. |

**Aggregate cap:** ~10,000 tokens (5% of 200K context window).

**Environment variables** (override defaults in `ctx-show.sh`):

| Variable | Default | Description |
|----------|---------|-------------|
| `CTX_CONTEXT_WINDOW` | `200000` | Total context window size in tokens |
| `CTX_WARN_THRESHOLD` | `CTX_CONTEXT_WINDOW * 5 / 100` | Warning fires when total tokens exceed this |

## Token Estimation

Two approaches for estimating tokens in plugin scripts:

| Method | Formula / Endpoint | Accuracy | When to use |
|--------|-------------------|----------|-------------|
| **Heuristic** | `chars * 10 / 36` (bash integer math) | ±5% | Default — no deps, instant |
| **Exact API** | `POST /v1/messages/count_tokens` | Exact | When `ANTHROPIC_API_KEY` is set |

**Heuristic ratio by content type** (Claude BPE tokenizer):

| Content | chars/token |
|---------|-------------|
| English markdown | 3.7–3.9 |
| Code (mixed) | 3.5–4.0 |
| Cyrillic/English mix | 3.3–3.4 |
| **Weighted average** | **3.6** |

**Usage pattern** (see `ctx-show.sh` for reference):
1. Check `ANTHROPIC_API_KEY` + `curl` + `jq` availability
2. Try exact API (free, `--max-time 5`)
3. Fall back to heuristic on failure

---

## Subagent Model Configuration

Plugins that delegate work to subagents must make the model configurable in their config file.

**Config field convention:**

| Plugin type | Config field | Example |
|-------------|-------------|---------|
| Single subagent | `"model": "<value>"` | `{ "model": "sonnet" }` |
| Multi-subagent (phases) | `"models": { "<phase>": "<value>" }` | `{ "models": { "dataCollection": "haiku", "analysis": "sonnet" } }` |

**Valid values:** `"haiku"`, `"sonnet"`, `"opus"`, `"inherit"` (use parent session model).

**Setup wizard requirement:** The model selection question must include a plugin-specific recommendation explaining WHY that model fits the task (e.g., "Haiku (Recommended) — Mechanical task, no reasoning needed").

See [`docs/plugin-behavior.md`](plugin-behavior.md) — §5 Subagent Design Guidelines for the full default selection table and opus usage criteria.

---

## Git Hook Installation

Plugins that install git hooks (pre-commit, pre-push, etc.) **must not overwrite** existing hooks. Plugins are additive guests in the user's repository.

**Marker-based injection:** Wrap the plugin's section in marker comments:
```bash
# >>> tribe-coding/<plugin-name> >>>
# ... plugin hook logic ...
# <<< tribe-coding/<plugin-name> <<<
```

**Rules:**

- **Respect `core.hooksPath`** — read the existing value with `git config --local core.hooksPath`. Only set it when no value is configured.
- **Variable namespacing** — prefix all variables with uppercase plugin name (e.g., `PLANTUML_STAGED_MD`, `PLANTUML_ENCODER`) to avoid clashes when multiple plugins share a hook file.
- **Idempotency** — if markers are already present, replace the section between them. If absent, append the section. Never duplicate.
- **Template format** — templates contain only the marker-delimited fragment (no `#!/bin/bash` shebang). The setup script adds a shebang when creating a new hook file.
- **No `exit 0`** — shared hook files run sequentially. An `exit 0` inside a section would skip other plugins' sections. Only `exit 1` (to block the git operation) is allowed.
- **`chmod +x`** — always set the executable bit after writing the hook file.
- **Provide an uninstall command** — every plugin that installs git hooks must also provide an uninstall script and a slash command (e.g., `/plantuml-uninstall`) that removes its marker-delimited section. If the section is the only content, delete the hook file. If other sections remain, preserve them.

**Reference implementation:** `plugins/plantuml/scripts/setup-project.sh` + `plugins/plantuml/scripts/uninstall-hook.sh` + `plugins/plantuml/templates/pre-commit`

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

## Local Plugin Testing (before push)

To test a plugin locally before pushing to remote and installing via marketplace:

**1. Copy plugin into the marketplace clone:**
```bash
cp -r plugins/<name> ~/.claude/plugins/marketplaces/tribe-coding/plugins/<name>
```

**2. Register in the marketplace manifest (if not already):**
```bash
# Edit ~/.claude/plugins/marketplaces/tribe-coding/.claude-plugin/marketplace.json
# Add the plugin entry to the "plugins" array
```

**3. Enable in settings:**
```bash
# Edit ~/.claude/settings.json — add to "enabledPlugins":
"<name>@tribe-coding": true
```

**4. Restart Claude Code** — the plugin should appear in `/plugin` and its commands in the skill list.

**After testing — clean up:**
- Remove `~/.claude/plugins/marketplaces/tribe-coding/plugins/<name>` (will be re-created on next marketplace sync)
- Remove `"<name>@tribe-coding": true` from `~/.claude/settings.json` (will be re-added on proper install)
- The marketplace manifest cache will be overwritten on next sync, so no manual revert needed

**Why this works:** Claude Code resolves plugin `"source"` paths relative to `~/.claude/plugins/marketplaces/<marketplace>/`. So `"source": "./plugins/ai-fortune"` resolves to `~/.claude/plugins/marketplaces/tribe-coding/plugins/ai-fortune`. Placing files there makes the plugin discoverable without pushing to remote.

