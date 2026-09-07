#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CodingEarphoneMode"
INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
BIN_DIR="$INSTALL_DIR/bin"
LOGS_DIR="$INSTALL_DIR/logs"
RUNTIME_DIR="$INSTALL_DIR/runtime"
TARGET_BIN="$BIN_DIR/coding-earphone"
VERSION_FILE="$INSTALL_DIR/VERSION"

PLIST_LABEL="com.local.coding-earphone-mode"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_LABEL.plist"

VERSION="0.1.0"

echo "=================================================="
echo "📦 Installing Coding Earphone Mode to Local User Space"
echo "=================================================="
echo "Target Directory: $INSTALL_DIR"

# 1. Build release binary if not present or outdated
if [ ! -f "$REPO_DIR/bin/coding-earphone" ] || [ "$REPO_DIR/src/main.swift" -nt "$REPO_DIR/bin/coding-earphone" ] || [ "$REPO_DIR/Info.plist" -nt "$REPO_DIR/bin/coding-earphone" ]; then
    echo "🔨 Building optimized release binary with embedded bundle identity..."
    mkdir -p "$REPO_DIR/bin"
    swiftc -O -o "$REPO_DIR/bin/coding-earphone" "$REPO_DIR/src/main.swift" \
        -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$REPO_DIR/Info.plist"
    codesign -s - --force --identifier "$PLIST_LABEL" "$REPO_DIR/bin/coding-earphone"
fi

# 2. Prepare directories
mkdir -p "$BIN_DIR" "$LOGS_DIR" "$RUNTIME_DIR" "$LAUNCH_AGENTS_DIR"

# 3. Copy binary and write version
echo "📋 Installing binary and version metadata..."
cp -f "$REPO_DIR/bin/coding-earphone" "$TARGET_BIN"
chmod +x "$TARGET_BIN"
echo "$VERSION" > "$VERSION_FILE"

BIN_SHA=$(shasum -a 256 "$TARGET_BIN" | awk '{print $1}')
echo "   Binary SHA256: $BIN_SHA"
echo "   Version: $VERSION"

# 4. Generate LaunchAgent plist
echo "⚙️ Configuring LaunchAgent: $PLIST_PATH..."
cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TARGET_BIN</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>5</integer>
    <key>StandardOutPath</key>
    <string>$LOGS_DIR/daemon_stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGS_DIR/daemon_stderr.log</string>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF

chmod 644 "$PLIST_PATH"

# 5. Reload LaunchAgent in user domain
echo "🚀 Loading LaunchAgent via launchctl..."
if launchctl list 2>/dev/null | grep -q "$PLIST_LABEL"; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    sleep 0.5
fi
launchctl load "$PLIST_PATH"

sleep 1

# 6. Verification
echo ""
"$REPO_DIR/scripts/coding-earphone" status

echo ""
echo "=================================================="
echo "✅ Installation Completed Successfully!"
echo "Daemon will automatically launch upon user login."
echo "Management command: $REPO_DIR/scripts/coding-earphone {start|stop|status|doctor}"
echo "=================================================="
