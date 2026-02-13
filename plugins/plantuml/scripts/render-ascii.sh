#!/bin/bash
# Wrapper script for PlantUML ASCII rendering
# Reduces command length to minimize permission prompts
#
# Usage:
#   echo "@startuml\nAlice -> Bob: Hello\n@enduml" | bash render-ascii.sh

set -euo pipefail

# Resolve plugin root (works both as hook and when run directly)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Pipe stdin to plantuml-encode.py --render-ascii
python3 "$PLUGIN_ROOT/scripts/plantuml-encode.py" --render-ascii
