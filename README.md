# Fedora Cinnamon Dotfiles

My personal Fedora Cinnamon setup with custom themes, icons, and configurations.

## Quick Install

On a fresh Fedora Cinnamon installation, run:

```bash
sudo dnf install -y git gh
# Authenticate in your browser (uses your GitHub login)
gh auth login --hostname github.com --git-protocol https --web
# Clone and run
gh repo clone pufferman777/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh
```

Then log out and log back in.

## What's Included

### Apps & Packages
- **Desktop**: Plank dock, NumLockX
- **Browsers**: Brave Browser
- **Terminals**: Warp Terminal
- **Gaming**: Steam, Lutris, Wine
- **Flatpak**: WeChat, Discord, Obsidian, Joplin
- **Snap**: TradingView
- **Dev Tools**: PyCharm Professional
- **System**: auto-cpufreq, rclone, Dropbox, neofetch, htop, powertop

### Themes & Icons and Wallpapers
- **Icons**: Tela Circle Purple Dark, Papirus (plus full color sets for WhiteSur, Colloid, Flat-Remix, McMojave, Inverse, Oranchelo, Zafiro)
- **Themes**: Adapta-Nokto, Carta, CBlue, Faded-Dream, Numix-Cinnamon-Transparent
- **Wallpapers**: Variety (auto-download/rotate), Fondo (search/download), Hydrapaper (per‑monitor)

### Keyboard Shortcuts
- `Ctrl+Alt+End` - Shutdown
- `Ctrl+Alt+Home` - Suspend
- `Ctrl+Alt+Insert` - Reboot
- `Ctrl+Shift+~` - Area screenshot to clipboard

### Autostart
- Plank dock
- NumLockX

## Manual Steps After Install

1. **Log out and log back in** (required for all changes to take effect)
2. **GPU Drivers**: Automatically detected and installed (NVIDIA/AMD)
   - If you have Secure Boot enabled with NVIDIA, you'll need to enroll the MOK key on reboot
3. **Sign in to apps**: Steam, Discord, WeChat, Dropbox
4. **Activate PyCharm Pro license**
5. **Run Battle.net**: `lutris` or `wine ~/Downloads/Battle.net-Setup.exe`
6. **Configure Cinnamon**: Add applets, set wallpaper, adjust monitor settings

## Updating

To update configs after making changes on your system:

```bash
cd ~/dotfiles
./backup.sh  # Creates backup of current configs
git add -A
git commit -m "Update configs"
git push
```
