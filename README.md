# Fedora Cinnamon Dotfiles

My personal Fedora Cinnamon setup with custom themes, icons, and configurations.

## Quick Install

On a fresh Fedora Cinnamon installation, run:

```bash
sudo dnf install -y git
git clone https://github.com/pufferman777/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Then log out and log back in.

## What's Included

### Packages
- **Desktop**: Cinnamon, Plank dock, Slick Greeter
- **Apps**: Brave Browser, Warp Terminal, Steam, Firefox, Thunderbird
- **Media**: MPV, Transmission, Shotwell
- **Productivity**: LibreOffice, Calculator, Screenshot tools
- **Utilities**: neofetch, htop, powertop

### Themes & Icons
- GTK Theme: Mint-Y-Dark-Teal
- Icons: Tela Circle Purple Dark
- Custom themes: Adapta-Nokto, Carta, CBlue, Faded-Dream, Numix-Cinnamon-Transparent

### Keyboard Shortcuts
- `Ctrl+Alt+End` - Shutdown
- `Ctrl+Alt+Home` - Suspend  
- `Ctrl+Alt+Insert` - Reboot
- `Ctrl+Shift+~` - Area screenshot to clipboard

### Autostart
- Plank dock
- NumLockX

## Manual Steps After Install

1. Set your wallpaper
2. Configure Brave Browser sync (if needed)
3. Log into Steam
4. Set up cloud storage (Dropbox, etc.)

## Updating

To update configs after making changes on your system:

```bash
cd ~/dotfiles
./backup.sh  # Creates backup of current configs
git add -A
git commit -m "Update configs"
git push
```
