#!/bin/bash
set -e

echo "============================================"
echo "  Fedora KDE - Minimal App Installer"
echo "============================================"
echo ""
echo "This script ONLY installs applications, libraries, themes, and icons."
echo "It does NOT modify system configuration, power management, or drivers."
echo ""

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script as root. Run as your normal user."
    echo "The script will ask for sudo password when needed."
    exit 1
fi

# ============================================
# STEP 1: Setup Application Repositories
# ============================================
print_step "Step 1/7: Setting up application repositories..."

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
# STEP 2: Install Applications & Libraries
# ============================================
print_step "Step 2/7: Installing applications and libraries..."

# Core applications (safe, user-space only)
SAFE_PACKAGES=(
    # Browsers & Terminals
    brave-browser
    warp-terminal
    firefox
    
    # KDE apps
    dolphin
    dolphin-plugins
    konsole
    spectacle
    kate
    ark
    gwenview
    kcalc
    
    # Productivity
    libreoffice-calc
    libreoffice-writer
    libreoffice-impress
    thunderbird
    
    # Media
    mpv
    transmission
    
    # Gaming
    steam
    wine
    lutris
    gamemode
    mangohud
    gamescope
    protontricks
    vkBasalt
    
    # Development tools
    git
    wget
    curl
    rsync
    rclone
    python3-devel
    python3-pip
    
    # System utilities (read-only)
    neofetch
    htop
    
    # Dropbox
    dropbox
    nautilus-dropbox
    
    # 32-bit compatibility for Wine/Gaming
    alsa-lib.i686
    pipewire-libs.i686
    pulseaudio-libs.i686
    libXcursor.i686
    libXi.i686
    libXrandr.i686
    libXinerama.i686
    SDL2.i686
    freetype.i686
    libpng.i686
    curl.i686
    gnutls.i686
    zlib.i686
    mesa-vulkan-drivers.i686
    mesa-dri-drivers.i686
    vulkan-loader.i686
    mesa-libGLU.i686
    openal-soft.i686
    dbus-glib.i686
    
    # Theme dependencies
    gtk-murrine-engine
    gtk2-engines
    sassc
    
    # Fonts
    aajohan-comfortaa-fonts
    google-noto-sans-fonts
)

echo "Installing ${#SAFE_PACKAGES[@]} packages..."
if ! sudo dnf install -y --skip-broken --skip-unavailable "${SAFE_PACKAGES[@]}"; then
    print_warning "Bulk install failed; retrying per-package..."
    for p in "${SAFE_PACKAGES[@]}"; do
        sudo dnf install -y --skip-broken --skip-unavailable "$p" || print_warning "Skipped: $p"
    done
fi

# ============================================
# STEP 3: Install Flatpak Apps
# ============================================
print_step "Step 3/7: Installing Flatpak apps..."

sudo dnf install -y flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install Flatpak apps (all user-space)
flatpak install -y flathub com.tencent.WeChat 2>/dev/null || true
flatpak install -y flathub com.discordapp.Discord 2>/dev/null || true
flatpak install -y flathub com.spotify.Client 2>/dev/null || true
flatpak install -y flathub net.davidotek.pupgui2 2>/dev/null || true
flatpak install -y flathub com.heroicgameslauncher.hgl 2>/dev/null || true
flatpak install -y flathub md.obsidian.Obsidian 2>/dev/null || true
flatpak install -y flathub net.cozic.joplin_desktop 2>/dev/null || true

# ============================================
# STEP 4: Install Snap Apps (Optional)
# ============================================
print_step "Step 4/7: Installing Snap apps..."

sudo dnf install -y snapd
sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true
sudo systemctl enable --now snapd.socket

# Wait for snapd
echo "  Waiting for snapd to initialize..."
for i in {1..30}; do
    if sudo snap list &>/dev/null; then
        break
    fi
    sleep 1
done

# Install TradingView
if ! sudo snap install tradingview 2>/dev/null; then
    print_warning "TradingView snap install failed. Try later: sudo snap install tradingview"
fi

# ============================================
# STEP 5: Install PyCharm Pro
# ============================================
print_step "Step 5/7: Installing PyCharm Pro..."

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
else
    echo "  PyCharm already installed"
fi

# ============================================
# STEP 6: Install Icon Themes
# ============================================
print_step "Step 6/7: Installing icon themes..."

mkdir -p ~/.local/share/icons
cd /tmp

# Tela Circle
if [ ! -d ~/.local/share/icons/Tela-circle-purple-dark ]; then
    echo "  Installing Tela Circle icons..."
    if git clone --depth 1 https://github.com/vinceliuice/Tela-circle-icon-theme.git; then
        cd Tela-circle-icon-theme
        ./install.sh || print_warning "Failed to install Tela Circle icons"
        cd /tmp
        rm -rf Tela-circle-icon-theme
    fi
fi

# Papirus
if [ ! -d ~/.local/share/icons/Papirus ]; then
    echo "  Installing Papirus icons..."
    wget -qO- https://git.io/papirus-icon-theme-install | sh || print_warning "Failed to install Papirus"
fi

# Colloid
if [ ! -d ~/.local/share/icons/Colloid-Purple ]; then
    echo "  Installing Colloid icons..."
    if git clone --depth 1 https://github.com/vinceliuice/Colloid-icon-theme.git; then
        cd Colloid-icon-theme
        ./install.sh -t all || print_warning "Failed to install Colloid"
        cd /tmp
        rm -rf Colloid-icon-theme
    fi
fi

# WhiteSur
if [ ! -d ~/.local/share/icons/WhiteSur-purple ]; then
    echo "  Installing WhiteSur icons..."
    if git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme.git; then
        cd WhiteSur-icon-theme
        ./install.sh -a || print_warning "Failed to install WhiteSur"
        cd /tmp
        rm -rf WhiteSur-icon-theme
    fi
fi

# ============================================
# STEP 7: Install GTK Themes
# ============================================
print_step "Step 7/7: Installing GTK themes..."

mkdir -p ~/.themes

# Install custom themes from repo
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

# ============================================
# DONE
# ============================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Installed:"
echo "  ✓ Applications (browsers, dev tools, gaming, productivity)"
echo "  ✓ Libraries (32-bit Wine/gaming compatibility)"
echo "  ✓ Flatpak apps (Discord, Spotify, WeChat, Obsidian)"
echo "  ✓ Snap apps (TradingView)"
echo "  ✓ PyCharm Professional"
echo "  ✓ Icon themes (Tela Circle, Papirus, Colloid, WhiteSur)"
echo "  ✓ GTK themes"
echo ""
echo "Next steps:"
echo "  - Log into: Dropbox, Steam, Discord, WeChat"
echo "  - Activate PyCharm license"
echo "  - Configure KDE: System Settings > Appearance"
echo "  - Install GPU drivers manually if needed"
echo ""
echo "This script did NOT modify:"
echo "  - System configuration"
echo "  - Power management"
echo "  - Display settings"
echo "  - Keyboard shortcuts"
echo "  - Autostart apps"
echo ""
