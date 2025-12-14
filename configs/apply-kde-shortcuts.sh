#!/bin/bash
# Apply custom keyboard shortcuts for KDE Plasma

# Ensure kglobalshortcutsrc exists
SHORTCUTS_FILE="$HOME/.config/kglobalshortcutsrc"
mkdir -p "$HOME/.config"

# Backup existing shortcuts
if [ -f "$SHORTCUTS_FILE" ]; then
    cp "$SHORTCUTS_FILE" "$SHORTCUTS_FILE.backup.$(date +%s)"
fi

# Add custom shortcuts to kglobalshortcutsrc
kwriteconfig5 --file kglobalshortcutsrc --group "org.kde.kglobalaccel" --key "poweroff" "Ctrl+Alt+End,none,Power Off"
kwriteconfig5 --file kglobalshortcutsrc --group "org.kde.kglobalaccel" --key "suspend" "Ctrl+Alt+Home,none,Suspend"
kwriteconfig5 --file kglobalshortcutsrc --group "org.kde.kglobalaccel" --key "reboot" "Ctrl+Alt+Insert,none,Reboot"

# Configure Spectacle (screenshot tool) for area screenshot to clipboard
kwriteconfig5 --file kglobalshortcutsrc --group "org.kde.spectacle.desktop" --key "_launch" "Ctrl+Shift+grave,none,Launch Spectacle"

# Create custom .desktop files for power actions
mkdir -p "$HOME/.local/share/applications"

cat > "$HOME/.local/share/applications/custom-poweroff.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Power Off
Exec=systemctl poweroff
Icon=system-shutdown
NoDisplay=true
EOF

cat > "$HOME/.local/share/applications/custom-suspend.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Suspend
Exec=systemctl suspend
Icon=system-suspend
NoDisplay=true
EOF

cat > "$HOME/.local/share/applications/custom-reboot.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Reboot
Exec=systemctl reboot
Icon=system-reboot
NoDisplay=true
EOF

echo "KDE keyboard shortcuts configured. You may need to log out and back in for changes to take effect."
