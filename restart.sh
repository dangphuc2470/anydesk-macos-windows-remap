#!/usr/bin/env bash
set -e

# ==============================================================================
# anydesk-macos-windows-remap Restart Script
# Author: dangphuc2470
# ==============================================================================

PLIST_DEST="$HOME/Library/LaunchAgents/com.dangphuc2470.anydesk-remap.plist"

echo "==> Restarting anydesk-macos-windows-remap..."

if [ -f "$PLIST_DEST" ]; then
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    launchctl load "$PLIST_DEST"
    echo "==> Service reloaded successfully."
else
    killall anydesk_remap 2>/dev/null || true
    echo "==> Process restarted."
fi

echo "==> Status check:"
sleep 0.5
ps aux | grep anydesk_remap | grep -v grep || echo "Warning: Process not detected. Please verify Accessibility permissions."
