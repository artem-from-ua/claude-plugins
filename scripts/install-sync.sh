#!/usr/bin/env bash
# Install claude-sync to ~/.local/bin and print alias instructions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="${SCRIPT_DIR}/claude-sync"
DEST_DIR="${HOME}/.local/bin"
DEST="${DEST_DIR}/claude-sync"

if [ ! -f "$SOURCE" ]; then
    echo "Error: claude-sync not found at ${SOURCE}" >&2
    exit 1
fi

mkdir -p "$DEST_DIR"
cp "$SOURCE" "$DEST"
chmod +x "$DEST"

echo "Installed claude-sync → ${DEST}"
echo ""
echo "Add this alias to your shell profile (~/.zshrc or ~/.bashrc):"
echo ""
echo "  alias claude='claude-sync && command claude'"
echo ""
echo "This runs claude-sync before every Claude Code session, keeping"
echo "the plugin cache in sync with marketplace sources."
