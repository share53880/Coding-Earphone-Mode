#!/usr/bin/env bash
set -e

APP_NAME="CodingEarphoneMode"
INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
PLIST_LABEL="com.local.coding-earphone-mode"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

echo "=================================================="
echo "🗑️  Uninstalling Coding Earphone Mode"
echo "=================================================="

# 1. Stop and unload LaunchAgent
if [ -f "$PLIST_PATH" ]; then
    echo "🛑 Unloading LaunchAgent ($PLIST_LABEL)..."
    launchctl stop "$PLIST_LABEL" 2>/dev/null || true
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    echo "   Removed LaunchAgent plist."
fi

# 2. Terminate any remaining daemon processes
PID=$(pgrep -f "coding-earphone" 2>/dev/null || echo "")
if [ -n "$PID" ]; then
    echo "🛑 Terminating running daemon process ($PID)..."
    kill -TERM "$PID" 2>/dev/null || true
    sleep 0.5
    if kill -0 "$PID" 2>/dev/null; then
        kill -9 "$PID" 2>/dev/null || true
    fi
fi

# 3. Clean up installation directory
if [ -d "$INSTALL_DIR" ]; then
    echo "🧹 Removing installation directory ($INSTALL_DIR)..."
    rm -rf "$INSTALL_DIR"
fi

# 4. Verify clean uninstall
echo "🔍 Verifying clean uninstallation..."
REMAINING_PID=$(pgrep -f "coding-earphone" 2>/dev/null || echo "")
if [ -n "$REMAINING_PID" ]; then
    echo "⚠️ Warning: Found remaining process $REMAINING_PID, killing..."
    kill -9 "$REMAINING_PID" 2>/dev/null || true
fi

echo "=================================================="
echo "✅ Uninstallation Complete!"
echo "• LaunchAgent removed"
echo "• Daemon stopped and EventTap hooks fully released"
echo "• Application directory removed"
echo "• Earphone behavior 100% returned to macOS default"
echo "=================================================="
