#!/usr/bin/env bash
set -e

# ==============================================================================
# anydesk-macos-windows-remap Restart Script
# Author: phucdnh
# ==============================================================================

echo "==> Restarting anydesk-macos-windows-remap daemon..."

# Clean up legacy LaunchAgent
LEGACY_PLIST="$HOME/Library/LaunchAgents/com.dangphuc2470.anydesk-remap.plist"
if [ -f "$LEGACY_PLIST" ]; then
    launchctl unload "$LEGACY_PLIST" 2>/dev/null || true
    rm -f "$LEGACY_PLIST"
fi

# Kill any existing processes before reloading
killall anydesk_remap phucdnh_anydesk_remap 2>/dev/null || true

# Reload phucdnh LaunchAgent
PLIST="$HOME/Library/LaunchAgents/com.phucdnh.anydesk-remap.plist"
if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    sleep 0.5
    launchctl load "$PLIST" 2>/dev/null || true
    echo "==> Reloaded $PLIST"
fi

sleep 1.2
echo "==> Active Daemon Status:"
ps aux | grep -E "phucdnh_anydesk_remap" | grep -v grep || echo "Warning: Daemon not currently detected in process list."
