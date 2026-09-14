#!/usr/bin/env bash
set -e

# ==============================================================================
# anydesk-macos-windows-remap Uninstaller
# Author: phucdnh
# ==============================================================================

echo "========================================================"
echo " Uninstalling anydesk-macos-windows-remap..."
echo "========================================================"

# 1. Unload LaunchAgents
for PLIST in "$HOME/Library/LaunchAgents/com.phucdnh.anydesk-remap.plist" "$HOME/Library/LaunchAgents/com.dangphuc2470.anydesk-remap.plist"; do
    if [ -f "$PLIST" ]; then
        echo "==> Unloading $PLIST..."
        launchctl unload "$PLIST" 2>/dev/null || true
        rm -f "$PLIST"
    fi
done

# 2. Kill running processes
killall anydesk_remap phucdnh_anydesk_remap 2>/dev/null || true

# 3. Remove installed files
for DIR in "$HOME/.config/phucdnh-anydesk-remap" "$HOME/.config/anydesk-remap"; do
    if [ -d "$DIR" ]; then
        echo "==> Removing $DIR..."
        rm -rf "$DIR"
    fi
done

echo "========================================================"
echo " Uninstallation Complete!"
echo "========================================================"
