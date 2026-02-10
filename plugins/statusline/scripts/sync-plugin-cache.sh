#!/usr/bin/env bash
# Workaround for Claude Code plugin cache bug.
# Copies plugin content from marketplace source into the stale cache directory.
#
# Upstream issues:
#   https://github.com/anthropics/claude-code/issues/14061
#   https://github.com/anthropics/claude-code/issues/15621
#   https://github.com/anthropics/claude-code/issues/15642
#
# This script must remain simple and stable — it bootstraps itself
# (the cached copy runs first, then overwrites itself with the new version).

set -euo pipefail

CACHE_DIR="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$CACHE_DIR" ] && exit 0

# Extract marketplace and plugin names from cache path:
#   ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/
PLUGINS_BASE="${HOME}/.claude/plugins"
# Strip the common prefix to get: <marketplace>/<plugin>/<version>
relative="${CACHE_DIR#"${PLUGINS_BASE}/cache/"}"
# If stripping failed (path doesn't match), bail out silently
[ "$relative" = "$CACHE_DIR" ] && exit 0

marketplace="${relative%%/*}"
rest="${relative#*/}"
plugin="${rest%%/*}"

MARKETPLACE_DIR="${PLUGINS_BASE}/marketplaces/${marketplace}/plugins/${plugin}"

# If marketplace source doesn't exist, nothing to sync
[ -d "$MARKETPLACE_DIR" ] || exit 0

# Sync marketplace content into cache, removing deleted files
rsync -a --delete "$MARKETPLACE_DIR"/ "$CACHE_DIR"/ 2>/dev/null || {
    echo "warning: sync-plugin-cache: failed to sync ${plugin} from marketplace to cache" >&2
}
