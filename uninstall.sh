#!/usr/bin/env bash
set -e

# ==============================================================================
# anydesk-macos-windows-remap Uninstaller
# Author: dangphuc2470
# ==============================================================================

INSTALL_DIR="$HOME/.config/anydesk-remap"
PLIST_DEST="$HOME/Library/LaunchAgents/com.dangphuc2470.anydesk-remap.plist"

echo "========================================================"
echo " Uninstalling anydesk-macos-windows-remap..."
echo "========================================================"

# 1. Unload LaunchAgent
if [ -f "$PLIST_DEST" ]; then
    echo "==> Unloading LaunchAgent..."
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    rm -f "$PLIST_DEST"
fi

# 2. Kill running processes
killall anydesk_remap phucdnh_anydesk_remap 2>/dev/null || true

# 3. Remove installed files
if [ -d "$INSTALL_DIR" ]; then
    echo "==> Removing installed directory $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
fi

echo "========================================================"
echo " Uninstallation Complete!"
echo "========================================================"
