#!/usr/bin/env bash
# Workaround for Claude Code plugin cache bug.
# Pulls latest marketplace content via git, then copies into stale cache directory.
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
REPO_DIR="${PLUGINS_BASE}/marketplaces/${marketplace}"

# If marketplace source doesn't exist, nothing to sync
[ -d "$MARKETPLACE_DIR" ] || exit 0

# --- Pull latest from remote (once per session) ---
# Flag file prevents duplicate pulls when multiple plugins from the same marketplace
# each run their own copy of this script within the same session start.
PULL_FLAG="/tmp/claude-marketplace-pull-${marketplace}"
pull_needed=true

if [ -f "$PULL_FLAG" ]; then
    flag_age=$(( $(date +%s) - $(stat -f %m "$PULL_FLAG" 2>/dev/null || echo 0) ))
    [ "$flag_age" -lt 60 ] && pull_needed=false
fi

if [ "$pull_needed" = true ] && [ -d "$REPO_DIR/.git" ]; then
    TIMEOUT_CMD=""
    if command -v timeout &>/dev/null; then
        TIMEOUT_CMD="timeout 3"
    elif command -v gtimeout &>/dev/null; then
        TIMEOUT_CMD="gtimeout 3"
    fi

    $TIMEOUT_CMD git -C "$REPO_DIR" pull --depth=1 origin main &>/dev/null || true
    touch "$PULL_FLAG" 2>/dev/null || true
fi

# --- Sync marketplace content into cache ---
rsync -a --delete "$MARKETPLACE_DIR"/ "$CACHE_DIR"/ 2>/dev/null || {
    echo "warning: sync-plugin-cache: failed to sync ${plugin} from marketplace to cache" >&2
}
