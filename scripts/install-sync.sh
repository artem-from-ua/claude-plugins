#!/usr/bin/env bash
# Install claude-sync to ~/.local/bin and configure shell profile.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="${SCRIPT_DIR}/claude-sync"
DEST_DIR="${HOME}/.local/bin"
DEST="${DEST_DIR}/claude-sync"

# Cross-platform file modification time helper.
# Uses BSD stat on macOS (*-f %m*) and GNU stat on Linux (*-c %Y*).
get_mtime() {
    local path="$1"
    if stat -f %m "$path" >/dev/null 2>&1; then
        stat -f %m "$path"
    else
        stat -c %Y "$path"
    fi
}

if [ ! -f "$SOURCE" ]; then
    echo "Error: claude-sync not found at ${SOURCE}" >&2
    exit 1
fi

mkdir -p "$DEST_DIR"
cp "$SOURCE" "$DEST"
chmod +x "$DEST"
echo "Installed claude-sync → ${DEST}"

# --- Detect shell profile ---
SHELL_NAME="$(basename "${SHELL:-/bin/bash}")"
case "$SHELL_NAME" in
    zsh)  PROFILE="${HOME}/.zshrc" ;;
    bash) PROFILE="${HOME}/.bashrc" ;;
    *)    PROFILE="${HOME}/.profile" ;;
esac

changed=false

# --- Ensure ~/.local/bin is in PATH ---
if ! grep -q '/.local/bin' "$PROFILE" 2>/dev/null; then
    echo '' >> "$PROFILE"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE"
    echo "Added ~/.local/bin to PATH in ${PROFILE}"
    changed=true
fi

# --- Add claude alias ---
if ! grep -q "alias claude=" "$PROFILE" 2>/dev/null; then
    echo "alias claude='claude-sync && command claude'" >> "$PROFILE"
    echo "Added claude alias to ${PROFILE}"
    changed=true
fi

if [ "$changed" = true ]; then
    echo ""
    echo "Run this to apply now:"
    echo "  source ${PROFILE}"
else
    echo "PATH and alias already configured in ${PROFILE}"
fi
