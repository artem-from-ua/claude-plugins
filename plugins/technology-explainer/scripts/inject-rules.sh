#!/bin/bash
# inject-rules.sh — SessionStart hook for technology-explainer plugin
# Reads ~/.claude/technology-explainer.json and outputs compact proficiency lists
# with pointers to level-specific skills.
# Silent exit (zero output) when no config or all tech lists empty.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
VERSION=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "?")

CONFIG="$HOME/.claude/technology-explainer.json"

# Silent exit if no config
if [[ ! -f "$CONFIG" ]]; then
  exit 0
fi

# Read technology arrays
expert=$(jq -r '.technologies.expert // [] | join(", ")' "$CONFIG" 2>/dev/null || true)
intermediate=$(jq -r '.technologies.intermediate // [] | join(", ")' "$CONFIG" 2>/dev/null || true)
learning=$(jq -r '.technologies.learning // [] | join(", ")' "$CONFIG" 2>/dev/null || true)

# Silent exit if all tech lists empty
if [[ -z "$expert" && -z "$intermediate" && -z "$learning" ]]; then
  exit 0
fi

default_level=$(jq -r '.defaultLevel // "learning"' "$CONFIG" 2>/dev/null || echo "learning")

# Build sources line
sources=$(jq -r '
  .sources // {} | to_entries
  | if length == 0 then empty
    else map("\(.key) → \(.value | join(", "))") | join("; ")
    end
' "$CONFIG" 2>/dev/null || true)

# Emit compact output
printf '<!-- Source: Plugin technology-explainer@tribe-coding (v%s) -->\n' "$VERSION"
printf '## Technology Explainer\n\n'
printf 'Adapt explanation depth to user proficiency. Applies ONLY to terminal dialogue — NOT to code comments, docstrings, or project documentation.\n\n'

if [[ -n "$expert" ]]; then
  printf '**Expert** (brief): %s\n' "$expert"
fi
if [[ -n "$intermediate" ]]; then
  printf '**Intermediate** (nuances): %s\n' "$intermediate"
fi
if [[ -n "$learning" ]]; then
  printf '**Learning** (detailed): %s\n' "$learning"
fi

cat <<'RULE'

**Unlisted technology rule:** When the user asks about a technology NOT listed in any level above:
1. NEVER silently fall back to any default level
2. Use `AskUserQuestion` to ask: "Which proficiency level should I use for **<technology>**?" with options: Expert, Intermediate, Learning
3. Read `~/.claude/technology-explainer.json` (create from template if missing), remove the technology from all level arrays, add it to the chosen level array, and write the file back
4. Invoke the appropriate `proficiency-guide-<level>` skill and answer at that depth
RULE

if [[ -n "$sources" ]]; then
  printf '\n**Sources:** %s\n' "$sources"
fi

printf '\nWhen explaining an **expert**-level technology → invoke `proficiency-guide-expert` skill.\n'
printf 'When explaining an **intermediate**-level technology → invoke `proficiency-guide-intermediate` skill.\n'
printf 'When explaining a **learning**-level technology → invoke `proficiency-guide-learning` skill.\n'
