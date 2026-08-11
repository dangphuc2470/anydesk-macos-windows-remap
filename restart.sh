#!/usr/bin/env bash
set -e

# ==============================================================================
# anydesk-macos-windows-remap Restart Script
# Author: dangphuc2470
# ==============================================================================

echo "==> Restarting anydesk-macos-windows-remap daemon..."

# Reload LaunchAgents if present
for PLIST in "$HOME/Library/LaunchAgents/com.dangphuc2470.anydesk-remap.plist" "$HOME/Library/LaunchAgents/com.phucdnh.anydesk-remap.plist"; do
    if [ -f "$PLIST" ]; then
        launchctl unload "$PLIST" 2>/dev/null || true
        launchctl load "$PLIST" 2>/dev/null || true
        echo "==> Reloaded $PLIST"
    fi
done

# Kill running processes so launchd KeepAlive restarts with fresh binary
killall anydesk_remap phucdnh_anydesk_remap 2>/dev/null || true

sleep 0.8
echo "==> Active Daemon Status:"
ps aux | grep -E "anydesk_remap|phucdnh_anydesk_remap" | grep -v grep || echo "Warning: Daemon not currently detected in process list."
