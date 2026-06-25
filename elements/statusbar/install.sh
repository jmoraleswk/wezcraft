#!/bin/zsh

# Define paths
CONFIG_DIR="$HOME/.config/wezterm"
SCRIPT_SRC="$CONFIG_DIR/elements/statusbar/update_stats.sh"
PLIST_DEST="$HOME/Library/LaunchAgents/com.user.wezterm-stats.plist"

# 1. Set executable permissions on stats script
chmod +x "$SCRIPT_SRC"

# 2. Create .plist file dynamically using $HOME
cat <<EOF > "$PLIST_DEST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.wezterm-stats</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_SRC</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# 3. Load agent into launchd
# Unload first if it already exists to avoid errors
launchctl unload "$PLIST_DEST" 2>/dev/null
launchctl load "$PLIST_DEST"

echo "✅ Installation completed:"
echo "   - Script: $SCRIPT_SRC"
echo "   - Plist: $PLIST_DEST"
echo "   - Service loaded successfully."