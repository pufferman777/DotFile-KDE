#!/bin/bash

echo "============================================"
echo "  Fedora KDE Plasma Dotfiles Bootstrap"
echo "============================================"
echo ""

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPLETION_MARKER="$HOME/.config/dotfiles-install-complete"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Track failed steps
FAILED_STEPS=()

print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

record_failure() {
    FAILED_STEPS+=("$1")
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script as root. Run as your normal user."
    echo "The script will ask for sudo password when needed."
    exit 1
fi


# ============================================
# STEP 1: Setup Repositories
# ============================================
print_step "Step 1/10: Setting up repositories..."

# RPM Fusion (Free and Nonfree)
echo "  Setting up RPM Fusion repositories..."
if ! sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm; then
    print_warning "Failed to install RPM Fusion repositories"
    record_failure "Step 1: RPM Fusion setup"
fi

# Brave Browser repo
sudo tee /etc/yum.repos.d/brave-browser.repo > /dev/null << 'EOF'
[brave-browser]
name=Brave Browser
enabled=1
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
EOF

# Warp Terminal repo
sudo tee /etc/yum.repos.d/warpdotdev.repo > /dev/null << 'EOF'
[warpdotdev]
name=warpdotdev
enabled=1
baseurl=https://releases.warp.dev/linux/rpm/stable
gpgcheck=1
gpgkey=https://releases.warp.dev/linux/keys/warp.asc
EOF

# Dropbox repo
sudo tee /etc/yum.repos.d/dropbox.repo > /dev/null << 'EOF'
[Dropbox]
name=Dropbox Repository
baseurl=https://linux.dropbox.com/fedora/$releasever/
gpgcheck=1
gpgkey=https://linux.dropbox.com/fedora/rpm-public-key.asc
EOF

# ============================================
# STEP 2: Install Packages
# ============================================
print_step "Step 2/10: Installing packages (this takes a while)..."

# Filter comments and empty lines, then install
mapfile -t PKGS < <(grep -v '^#' "$DOTFILES_DIR/packages.txt" | grep -v '^$')
if ! sudo dnf install -y --allowerasing --skip-broken --skip-unavailable "${PKGS[@]}"; then
    print_warning "Bulk install failed; retrying per-package..."
    for p in "${PKGS[@]}"; do
        sudo dnf install -y --allowerasing --skip-broken --skip-unavailable "$p" || print_warning "Skipped: $p"
    done
fi

# Install Dropbox
sudo dnf install -y dropbox nautilus-dropbox 2>/dev/null || true

# NOTE: GPU driver auto-installation has been removed to prevent hardware-specific issues.
# To install GPU drivers manually:
#   NVIDIA: sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda
#   AMD:    sudo dnf install rocm-smi (optional, drivers included in kernel)
#   Intel:  Drivers included in kernel (no action needed)

# ============================================
# STEP 3: Install Flatpak Apps
# ============================================
print_step "Step 3/10: Installing Flatpak apps..."

if sudo dnf install -y flatpak; then
    # Add flathub remote at user level (no sudo/authentication needed)
    echo "  Setting up Flathub repository (user-level)..."
    if ! flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        print_error "Failed to add flathub repository"
        record_failure "Step 3: Flatpak repository setup"
    else
        # Install all flatpak apps in one batch (user-level, no authentication)
        echo "  Installing Flatpak apps..."
        FLATPAK_APPS=(
            "com.tencent.WeChat"
            "com.discordapp.Discord"
            "com.spotify.Client"
            "net.davidotek.pupgui2"
            "com.heroicgameslauncher.hgl"
            "md.obsidian.Obsidian"
            "net.cozic.joplin_desktop"
            "com.github.calo001.fondo"
            "org.gabmus.hydrapaper"
        )
        
        if ! flatpak install --user -y flathub "${FLATPAK_APPS[@]}" 2>&1 | grep -v "^$"; then
            print_warning "Some flatpak apps may have failed to install"
        fi
    fi
else
    print_error "Failed to install flatpak package"
    record_failure "Step 3: Flatpak installation"
fi

# ============================================
# STEP 4: Install Snap Apps
# ============================================
print_step "Step 4/10: Installing Snap apps (TradingView)..."

sudo dnf install -y snapd
sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true
sudo systemctl enable --now snapd.socket

# Wait for snapd to be ready (with retries)
echo "  Waiting for snapd to initialize..."
for i in {1..30}; do
    if sudo snap list &>/dev/null; then
        break
    fi
    sleep 1
done

# Install TradingView
if ! sudo snap install tradingview 2>/dev/null; then
    print_warning "TradingView snap install failed. After reboot, run: sudo snap install tradingview"
fi

# ============================================
# STEP 5: Install PyCharm Pro
# ============================================
print_step "Step 5/10: Installing PyCharm Pro..."

PYCHARM_VERSION="2024.3.1.1"
PYCHARM_URL="https://download.jetbrains.com/python/pycharm-professional-${PYCHARM_VERSION}.tar.gz"
PYCHARM_DIR="/opt/pycharm"

if [ ! -d "$PYCHARM_DIR" ]; then
    echo "  Downloading PyCharm Pro..."
    cd /tmp
    wget -q "$PYCHARM_URL" -O pycharm.tar.gz
    sudo mkdir -p /opt
    sudo tar -xzf pycharm.tar.gz -C /opt
    sudo mv /opt/pycharm-* "$PYCHARM_DIR"
    rm pycharm.tar.gz
    
    mkdir -p ~/.local/share/applications
    cat > ~/.local/share/applications/pycharm.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=PyCharm Professional
Icon=${PYCHARM_DIR}/bin/pycharm.svg
Exec="${PYCHARM_DIR}/bin/pycharm.sh" %f
Comment=Python IDE for Professional Developers
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-pycharm
EOF
fi

# ============================================
# STEP 6: Download Battle.net
# ============================================
print_step "Step 6/9: Downloading Battle.net installer..."

mkdir -p ~/Downloads
if [ ! -f ~/Downloads/Battle.net-Setup.exe ]; then
    wget -q "https://www.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP" \
        -O ~/Downloads/Battle.net-Setup.exe
    echo "  Battle.net installer saved to ~/Downloads/Battle.net-Setup.exe"
fi

# ============================================
# STEP 7: Install Icon Themes
# ============================================
if grep -q "^icons_installed$" "$COMPLETION_MARKER" 2>/dev/null; then
    print_step "Step 7/9: Icon themes already installed (skipping)..."
else
    print_step "Step 7/9: Installing icon themes..."
    
    mkdir -p ~/.local/share/icons
    cd /tmp

# Tela Circle (all colors)
if [ ! -d ~/.local/share/icons/Tela-circle-purple-dark ]; then
    echo "  Installing Tela Circle icons (all colors)..."
    if git clone --depth 1 https://github.com/vinceliuice/Tela-circle-icon-theme.git; then
        cd Tela-circle-icon-theme
        ./install.sh || print_warning "Failed to install Tela Circle icons"
        cd /tmp
        rm -rf Tela-circle-icon-theme
    else
        print_warning "Failed to clone Tela Circle icons repository"
    fi
fi

# Papirus (includes Dark, Light variants)
if [ ! -d ~/.local/share/icons/Papirus ]; then
    echo "  Installing Papirus icons..."
    wget -qO- https://git.io/papirus-icon-theme-install | sh || print_warning "Failed to install Papirus icons"
fi

# Colloid (Purple, Teal, Yellow - all variants)
if [ ! -d ~/.local/share/icons/Colloid-Purple ]; then
    echo "  Installing Colloid icons..."
    if git clone --depth 1 https://github.com/vinceliuice/Colloid-icon-theme.git; then
        cd Colloid-icon-theme
        ./install.sh -t all || print_warning "Failed to install Colloid icons"
        cd /tmp
        rm -rf Colloid-icon-theme
    else
        print_warning "Failed to clone Colloid icons repository"
    fi
fi

# Flat-Remix (all colors)
if [ ! -d ~/.local/share/icons/Flat-Remix-Blue-Dark ]; then
    echo "  Installing Flat-Remix icons..."
    if git clone --depth 1 https://github.com/daniruiz/flat-remix.git; then
        cd flat-remix
        mkdir -p ~/.local/share/icons
        cp -r Flat-Remix-* ~/.local/share/icons/ 2>/dev/null || print_warning "Failed to copy Flat-Remix icons"
        cd /tmp
        rm -rf flat-remix
    else
        print_warning "Failed to clone Flat-Remix icons repository"
    fi
fi

# McMojave Circle (all colors)
if [ ! -d ~/.local/share/icons/McMojave-circle-purple ]; then
    echo "  Installing McMojave Circle icons..."
    if git clone --depth 1 https://github.com/vinceliuice/McMojave-circle.git; then
        cd McMojave-circle
        ./install.sh || print_warning "Failed to install McMojave Circle icons"
        cd /tmp
        rm -rf McMojave-circle
    else
        print_warning "Failed to clone McMojave Circle icons repository"
    fi
fi

# WhiteSur (all colors)
if [ ! -d ~/.local/share/icons/WhiteSur-purple ]; then
    echo "  Installing WhiteSur icons..."
    if git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme.git; then
        cd WhiteSur-icon-theme
        ./install.sh -a || print_warning "Failed to install WhiteSur icons"
        cd /tmp
        rm -rf WhiteSur-icon-theme
    else
        print_warning "Failed to clone WhiteSur icons repository"
    fi
fi

# Inverse (orange)
if [ ! -d ~/.local/share/icons/Inverse-orange ]; then
    echo "  Installing Inverse icons..."
    if git clone --depth 1 https://github.com/yeyushengfan258/Inverse-icon-theme.git; then
        cd Inverse-icon-theme
        ./install.sh -orange || print_warning "Failed to install Inverse icons"
        cd /tmp
        rm -rf Inverse-icon-theme
    else
        print_warning "Failed to clone Inverse icons repository"
    fi
fi

# Oranchelo
if [ ! -d ~/.local/share/icons/Oranchelo ]; then
    echo "  Installing Oranchelo icons..."
    if git clone --depth 1 https://github.com/OrancheloTeam/oranchelo-icon-theme.git; then
        cd oranchelo-icon-theme
        mkdir -p ~/.local/share/icons
        cp -r Oranchelo ~/.local/share/icons/ 2>/dev/null || print_warning "Failed to copy Oranchelo icons"
        cd /tmp
        rm -rf oranchelo-icon-theme
    else
        print_warning "Failed to clone Oranchelo icons repository"
    fi
fi

# Zafiro (Dark + Blue-f variants)
if [ ! -d ~/.local/share/icons/Zafiro-Icons-Dark ]; then
    echo "  Installing Zafiro icons..."
    if git clone --depth 1 https://github.com/zayronxio/Zafiro-icons.git; then
        cd Zafiro-icons
        mkdir -p ~/.local/share/icons
        cp -r Zafiro* ~/.local/share/icons/ 2>/dev/null || print_warning "Failed to copy Zafiro icons"
        cd /tmp
        rm -rf Zafiro-icons
    else
        print_warning "Failed to clone Zafiro icons repository"
    fi
fi

    # Mark icons as installed
    mkdir -p "$(dirname "$COMPLETION_MARKER")"
    echo "icons_installed" >> "$COMPLETION_MARKER"
fi

# ============================================
# STEP 8: Install GTK Themes & Wallpapers
# ============================================
print_step "Step 8/9: Installing GTK themes and wallpapers..."

mkdir -p ~/.themes

# Install GTK themes (skip if already present)
if [ -d "$DOTFILES_DIR/themes" ]; then
    themes_to_install=()
    for theme in "$DOTFILES_DIR/themes/"*; do
        theme_name=$(basename "$theme")
        if [ ! -d ~/.themes/"$theme_name" ]; then
            themes_to_install+=("$theme_name")
        fi
    done
    
    if [ ${#themes_to_install[@]} -gt 0 ]; then
        echo "  Installing ${#themes_to_install[@]} GTK themes..."
        for theme_name in "${themes_to_install[@]}"; do
            cp -r "$DOTFILES_DIR/themes/$theme_name" ~/.themes/
        done
    else
        echo "  All GTK themes already installed"
    fi
fi

# Download wallpapers from Unsplash (124 high-quality 2K+ images)
echo "  Downloading wallpapers from Unsplash..."
if [ -f "$DOTFILES_DIR/scripts/download-wallpapers.sh" ]; then
    "$DOTFILES_DIR/scripts/download-wallpapers.sh" || print_warning "Wallpaper download failed"
else
    print_warning "Wallpaper download script not found"
fi

# Promote any additional wallpapers from user's Pictures folder
echo "  Promoting wallpapers from Pictures folder..."
if [ -f "$DOTFILES_DIR/scripts/promote-wallpapers.sh" ]; then
    "$DOTFILES_DIR/scripts/promote-wallpapers.sh" --min-width 2560 || print_warning "Wallpaper promotion failed"
else
    print_warning "Wallpaper promotion script not found"
fi

# ============================================
# STEP 9: Setup Autostart
# ============================================
print_step "Step 9/9: Setting up autostart apps..."

# NOTE: Keyboard shortcut configuration has been removed to prevent system suspend issues.
# To manually configure keyboard shortcuts, see: configs/apply-kde-shortcuts.sh

# Setup autostart
mkdir -p ~/.config/autostart

cat > ~/.config/autostart/numlockx.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=NumLockX
Exec=numlockx on
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

# ============================================
# DONE
# ============================================
echo ""
if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Setup Complete!${NC}"
    echo -e "${GREEN}============================================${NC}"
else
    echo -e "${YELLOW}============================================${NC}"
    echo -e "${YELLOW}  Setup Complete with Some Failures${NC}"
    echo -e "${YELLOW}============================================${NC}"
    echo ""
    echo -e "${RED}The following steps encountered errors:${NC}"
    for failure in "${FAILED_STEPS[@]}"; do
        echo -e "  ${RED}✗${NC} $failure"
    done
fi
echo ""
echo "Please LOG OUT and LOG BACK IN for all changes to take effect."
echo ""
echo "Your setup includes:"
echo "  - DNF packages (Brave, Warp, Steam, rclone, etc.)"
echo "  - KDE Plasma apps (Dolphin, Konsole, Spectacle, Kate)"
echo "  - Flatpak apps (WeChat, Discord, Spotify, Obsidian)"
echo "  - Snap apps (TradingView)"
echo "  - PyCharm Pro (activate license on first run)"
echo "  - Multiple icon themes (Tela Circle, Papirus, Colloid, etc.)"
echo "  - Custom GTK themes"
echo ""
echo "Manual steps:"
echo "  - Run Battle.net: lutris or wine ~/Downloads/Battle.net-Setup.exe"
echo "  - Log into Dropbox, Steam, Discord, WeChat"
echo "  - Activate PyCharm license"
echo "  - Configure KDE appearance: System Settings > Appearance"
echo "  - GPU drivers: Install manually if needed (see script comments)"
if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Note: Review the errors above and manually complete any failed steps.${NC}"
fi
echo ""
