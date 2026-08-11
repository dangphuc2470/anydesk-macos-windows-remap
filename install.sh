#!/usr/bin/env bash
set -e

# ==============================================================================
# anydesk-macos-windows-remap Installer
# Author: phucdnh
# ==============================================================================

INSTALL_DIR="$HOME/.config/phucdnh-anydesk-remap"
PLIST_DEST="$HOME/Library/LaunchAgents/com.phucdnh.anydesk-remap.plist"

echo "========================================================"
echo " Installing anydesk-macos-windows-remap (by phucdnh)..."
echo "========================================================"

# 1. Create target directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$HOME/Library/LaunchAgents"

# 2. Compile binary
echo "==> Compiling Swift daemon..."
swiftc -O -o "$INSTALL_DIR/phucdnh_anydesk_remap" main.swift

# Copy main.swift for reference
cp main.swift "$INSTALL_DIR/main.swift"

# 3. Generate LaunchAgent plist with dynamic home path
echo "==> Configuring LaunchAgent..."
sed "s|{{INSTALL_DIR}}|$INSTALL_DIR|g" com.phucdnh.anydesk-remap.plist.template > "$PLIST_DEST"

# 4. Stop any existing instance and load LaunchAgent
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

echo ""
echo "========================================================"
echo " Installation Complete!"
echo "========================================================"
echo "IMPORTANT: Please grant Accessibility permission in:"
echo "System Settings -> Privacy & Security -> Accessibility"
echo "and add / toggle ON: $INSTALL_DIR/phucdnh_anydesk_remap"
echo "========================================================"
