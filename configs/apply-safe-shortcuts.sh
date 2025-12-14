#!/bin/bash
# Apply SAFE keyboard shortcuts for KDE Plasma
# NOTE: This does NOT include suspend shortcuts to prevent hardware issues

echo "Applying safe keyboard shortcuts for KDE Plasma..."
echo "This will configure:"
echo "  - Ctrl+Alt+End: Shutdown"
echo "  - Ctrl+Alt+Insert: Reboot"
echo "  - Ctrl+Shift+~: Launch Spectacle (screenshot)"
echo ""
echo "NOTE: Suspend shortcut is NOT configured to prevent hardware issues."
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Ensure kglobalshortcutsrc exists
SHORTCUTS_FILE="$HOME/.config/kglobalshortcutsrc"
mkdir -p "$HOME/.config"

# Backup existing shortcuts
if [ -f "$SHORTCUTS_FILE" ]; then
    cp "$SHORTCUTS_FILE" "$SHORTCUTS_FILE.backup.$(date +%s)"
    echo "Backed up existing shortcuts to $SHORTCUTS_FILE.backup.*"
fi

# Add SAFE shortcuts to kglobalshortcutsrc (NO SUSPEND)
kwriteconfig5 --file kglobalshortcutsrc --group "org.kde.kglobalaccel" --key "poweroff" "Ctrl+Alt+End,none,Power Off"
kwriteconfig5 --file kglobalshortcutsrc --group "org.kde.kglobalaccel" --key "reboot" "Ctrl+Alt+Insert,none,Reboot"

# Configure Spectacle (screenshot tool)
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

cat > "$HOME/.local/share/applications/custom-reboot.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Reboot
Exec=systemctl reboot
Icon=system-reboot
NoDisplay=true
EOF

echo ""
echo "✓ Safe keyboard shortcuts configured!"
echo ""
echo "Active shortcuts:"
echo "  Ctrl+Alt+End    = Shutdown"
echo "  Ctrl+Alt+Insert = Reboot"
echo "  Ctrl+Shift+~    = Launch Spectacle (screenshot)"
echo ""
echo "To configure suspend manually (if your hardware supports it):"
echo "  System Settings > Shortcuts > Power Management"
echo ""
