# Fedora KDE Plasma Dotfiles

My personal Fedora KDE Plasma setup with custom themes, icons, and configurations.

## Quick Install

On a fresh Fedora KDE Plasma installation, run:

```bash
sudo dnf install -y git gh
# Authenticate in your browser (uses your GitHub login)
gh auth login --hostname github.com --git-protocol https --web
# Clone and run
gh repo clone pufferman777/DotFile-KDE ~/DotFile-KDE
cd ~/DotFile-KDE
./install.sh
```

Then log out and log back in.

## What's Included

### Apps & Packages
- **Desktop**: KDE Plasma, Dolphin, Konsole, Spectacle, Kate, Ark, NumLockX
- **Browsers**: Brave Browser, Firefox
- **Terminals**: Warp Terminal, Konsole
- **Gaming**: Steam, Lutris, Wine, gamemode, mangohud
- **Flatpak**: WeChat, Discord, Spotify, Obsidian, Joplin, Heroic Games Launcher
- **Snap**: TradingView
- **Dev Tools**: PyCharm Professional
- **System**: rclone, Dropbox, neofetch, htop, powertop

### Themes & Icons and Wallpapers
- **Icons**: Tela Circle (all colors), Papirus, WhiteSur, Colloid, Flat-Remix, McMojave Circle, Inverse, Oranchelo, Zafiro
- **GTK Themes**: Adapta-Nokto, Carta, CBlue, Faded-Dream, Numix (for GTK apps in KDE)
- **Wallpapers**: High-quality 2K+ images from Unsplash, Variety (auto-download/rotate), Fondo, Hydrapaper

### Keyboard Shortcuts
- `Ctrl+Alt+End` - Shutdown
- `Ctrl+Alt+Home` - Suspend
- `Ctrl+Alt+Insert` - Reboot
- `Ctrl+Shift+~` - Launch Spectacle (screenshot tool)

### Autostart
- NumLockX

## Manual Steps After Install

1. **Log out and log back in** (required for all changes to take effect)
2. **GPU Drivers** (if needed):
   - **NVIDIA**: `sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda`
     - If Secure Boot is enabled, you'll need to enroll the MOK key on reboot
   - **AMD**: Drivers included in kernel (optional: `sudo dnf install rocm-smi`)
   - **Intel**: Drivers included in kernel (no action needed)
3. **Sign in to apps**: Steam, Discord, WeChat, Dropbox
4. **Activate PyCharm Pro license**
5. **Run Battle.net**: `lutris` or `wine ~/Downloads/Battle.net-Setup.exe`
6. **Configure KDE**: System Settings > Appearance to set icon theme, GTK theme, wallpaper, etc.

## Optional Hardware-Specific Tools

### auto-cpufreq (Power Management)
For laptops or systems that need advanced CPU frequency management:
```bash
cd /tmp
git clone https://github.com/AdnanHodzic/auto-cpufreq.git
cd auto-cpufreq
sudo ./auto-cpufreq-installer --install
sudo auto-cpufreq --install
```

## Updating

To update configs after making changes on your system:

```bash
cd ~/dotfiles
./backup.sh  # Creates backup of current configs
git add -A
git commit -m "Update configs"
git push
```
