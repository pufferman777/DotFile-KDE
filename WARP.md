# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Overview

Personal dotfiles for Fedora Cinnamon desktop environment. The repository bootstraps a fresh Fedora installation with packages, themes, icons, and desktop configurations.

## Key Commands

```bash
# Full system bootstrap (on fresh Fedora install)
# Includes automatic GPU driver detection/installation and wallpaper promotion
./install.sh

# Export current dconf settings to file
dconf dump / > configs/full-dconf.txt

# Load dconf settings from file
dconf load / < configs/full-dconf.txt

# Install packages from packages.txt
grep -v '^#' packages.txt | grep -v '^$' | xargs sudo dnf install -y
```

## Repository Structure

- `install.sh` - Main bootstrap script (10 steps: repos, packages, flatpak, snap, pycharm, auto-cpufreq, battle.net, icons, themes, keyboard shortcuts + autostart)
- `packages.txt` - DNF packages to install (comments with `#`, one package per line)
- `configs/keyboard-shortcuts.dconf` - Keyboard shortcuts only (safe to apply)
- `themes/` - Custom GTK/Cinnamon themes (copied to `~/.themes/`)

## Architecture Notes

**Safe-Only Design**: This repo automatically detects and installs GPU drivers (NVIDIA/AMD), but intentionally excludes other hardware-specific configs (monitor layouts, Cinnamon applet states) to ensure it works on any Fedora Cinnamon system. User-specific configs (browser profiles, app settings) are also excluded.

**Keyboard Shortcuts**: Only keyboard bindings are versioned (`configs/keyboard-shortcuts.dconf`). They're applied via `dconf load /org/cinnamon/desktop/keybindings/`.

**External Installs**: Tela Circle icons and Papirus icons are cloned from GitHub during install. PyCharm Pro is downloaded directly from JetBrains. Custom GTK themes in `themes/` are copied to `~/.themes/`.

## Installation Methods

The install script uses multiple package managers:

- **DNF**: Core packages, rclone, wine, lutris, Dropbox (from packages.txt + repos)
- **Flatpak**: WeChat (`com.tencent.WeChat`), Discord (`com.discordapp.Discord`)
- **Snap**: TradingView
- **Direct download**: PyCharm Pro (from JetBrains), Battle.net-Setup.exe
- **GitHub install**: auto-cpufreq (cloned and installed via its installer), Tela Circle icons, Papirus icons

## Repos Added by install.sh

- RPM Fusion (free + nonfree)
- Brave Browser
- Warp Terminal
- Dropbox

## Post-Install Manual Steps

- **Log out and log back in** (required)
- **GPU drivers**: Automatically installed (NVIDIA/AMD detected via lspci)
  - If Secure Boot is enabled with NVIDIA, enroll MOK key on reboot
- Run Battle.net: `lutris` or `wine ~/Downloads/Battle.net-Setup.exe`
- Log into Dropbox, Steam, Discord, WeChat
- Activate PyCharm license
- Configure Cinnamon: add applets, set wallpaper, adjust monitor settings
