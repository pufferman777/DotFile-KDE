# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Overview

Personal dotfiles for Fedora Cinnamon desktop environment. The repository bootstraps a fresh Fedora installation with packages, themes, icons, and desktop configurations.

## Key Commands

```bash
# Full system bootstrap (on fresh Fedora install)
./install.sh

# Export current dconf settings to file
dconf dump / > configs/full-dconf.txt

# Load dconf settings from file
dconf load / < configs/full-dconf.txt

# Install packages from packages.txt
grep -v '^#' packages.txt | grep -v '^$' | xargs sudo dnf install -y
```

## Repository Structure

- `install.sh` - Main bootstrap script (12 steps: repos, packages, flatpak, snap, pycharm, auto-cpufreq, battle.net, icons, themes, configs, dconf, autostart)
- `packages.txt` - DNF packages to install (comments with `#`, one package per line)
- `configs/dot-config/` - Maps to `~/.config/` (app configs for Plank, Cinnamon, Warp, Brave, etc.)
- `configs/dot-local-share/` - Maps to `~/.local/share/` (Cinnamon applets, Nemo actions, Plank themes)
- `configs/full-dconf.txt` - Complete dconf dump for Cinnamon desktop settings
- `themes/` - Custom GTK/Cinnamon themes (copied to `~/.themes/`)
- `icons/` - Custom icon themes (copied to `~/.local/share/icons/`)

## Architecture Notes

**Config Path Mapping**: The `configs/` directory uses a naming convention where `dot-config` → `~/.config` and `dot-local-share` → `~/.local/share`. The install script copies contents recursively.

**dconf Settings**: Cinnamon desktop settings (keyboard shortcuts, theme selections, panel configs) are stored in `configs/full-dconf.txt`. The install script replaces `/home/testbug` with the current user's `$HOME` before loading.

**External Theme Installation**: Tela Circle icons and Papirus icons are cloned from GitHub during install (not stored in this repo). Custom themes in `themes/` are copied directly.

## Installation Methods

The install script uses multiple package managers:

- **DNF**: Core packages, NVIDIA drivers, rclone, wine, lutris (from packages.txt + repos)
- **Flatpak**: WeChat (`com.tencent.WeChat`), Discord (`com.discordapp.Discord`)
- **Snap**: TradingView
- **Direct download**: PyCharm Pro (from JetBrains), Battle.net-Setup.exe
- **GitHub install**: auto-cpufreq (cloned and installed via its installer)

## Repos Added by install.sh

- RPM Fusion (free + nonfree)
- Brave Browser
- Warp Terminal
- Dropbox
- ROCm (for AMD GPU tools)

## Post-Install Manual Steps

- Run Battle.net: `lutris` or `wine ~/Downloads/Battle.net-Setup.exe`
- Log into Dropbox, Steam, Discord, WeChat
- Activate PyCharm license on first run
