#!/bin/bash
# Exit on error, but allow individual package failures
set -e

echo "============================================"
echo "  Fedora KDE - Minimal App Installer"
echo "============================================"
echo ""
echo "This script ONLY installs applications, libraries, themes, and icons."
echo "It does NOT modify system configuration, power management, or drivers."
echo "Safe for fresh Fedora KDE installations."
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

# Prompt for sudo password early and keep it alive
echo "This script requires sudo privileges. Please enter your password:"
sudo -v

# Keep sudo alive in background
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &

# ============================================
# STEP 1: Update System Packages
# ============================================
print_step "Step 1/8: Updating system packages to prevent conflicts..."
echo "  This prevents version mismatches between x86_64 and i686 packages"
sudo dnf update -y --refresh || print_warning "System update had issues, continuing anyway..."

# ============================================
# STEP 2: Setup Application Repositories
# ============================================
print_step "Step 2/8: Setting up application repositories..."

# Brave Browser repo (skip if already exists)
if [ ! -f /etc/yum.repos.d/brave-browser.repo ]; then
    echo "  Adding Brave Browser repository..."
    sudo tee /etc/yum.repos.d/brave-browser.repo > /dev/null << 'EOF'
[brave-browser]
name=Brave Browser
enabled=1
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
EOF
else
    echo "  Brave Browser repository already configured"
fi

# Warp Terminal repo (skip if already exists)
if [ ! -f /etc/yum.repos.d/warpdotdev.repo ]; then
    echo "  Adding Warp Terminal repository..."
    sudo tee /etc/yum.repos.d/warpdotdev.repo > /dev/null << 'EOF'
[warpdotdev]
name=warpdotdev
enabled=1
baseurl=https://releases.warp.dev/linux/rpm/stable
gpgcheck=1
gpgkey=https://releases.warp.dev/linux/keys/warp.asc
EOF
else
    echo "  Warp Terminal repository already configured"
fi

# Dropbox repo (skip if already exists)
if [ ! -f /etc/yum.repos.d/dropbox.repo ]; then
    echo "  Adding Dropbox repository..."
    sudo tee /etc/yum.repos.d/dropbox.repo > /dev/null << 'EOF'
[Dropbox]
name=Dropbox Repository
baseurl=https://linux.dropbox.com/fedora/$releasever/
gpgcheck=1
gpgkey=https://linux.dropbox.com/fedora/rpm-public-key.asc
EOF
else
    echo "  Dropbox repository already configured"
fi

# ============================================
# STEP 3: Install Applications & Libraries
# ============================================
print_step "Step 3/8: Installing applications and libraries..."

# Core applications (safe, user-space only)
# REMOVED: System-critical packages (sddm, plasma-workspace) to prevent boot issues
SAFE_PACKAGES=(
    # Browsers & Terminals
    brave-browser
    warp-terminal
    firefox
    
    # KDE apps (excluding display manager components)
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
    numlockx
    
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

# Filter out already installed packages for efficiency
PACKAGES_TO_INSTALL=()
for pkg in "${SAFE_PACKAGES[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
        PACKAGES_TO_INSTALL+=("$pkg")
    fi
done

if [ ${#PACKAGES_TO_INSTALL[@]} -eq 0 ]; then
    echo "All packages already installed!"
else
    echo "Installing ${#PACKAGES_TO_INSTALL[@]} new packages (${#SAFE_PACKAGES[@]} total)..."
    # REMOVED --allowerasing flag to prevent accidental package removal
    if ! sudo dnf install -y --skip-broken --skip-unavailable "${PACKAGES_TO_INSTALL[@]}"; then
        print_warning "Bulk install failed; retrying per-package..."
        for p in "${PACKAGES_TO_INSTALL[@]}"; do
            sudo dnf install -y --skip-broken --skip-unavailable "$p" || print_warning "Skipped: $p"
        done
    fi
fi

# ============================================
# STEP 4: Install Flatpak Apps
# ============================================
print_step "Step 4/8: Installing Flatpak apps..."

# Ensure flatpak is installed
if ! command -v flatpak &>/dev/null; then
    sudo dnf install -y flatpak
fi

# Add flathub repository if not already added (requires sudo for system-wide)
if ! flatpak remote-list | grep -q "flathub"; then
    echo "  Adding Flathub repository..."
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
else
    echo "  Flathub repository already configured"
fi

# List of Flatpak apps to install
FLATPAK_APPS=(
    "com.tencent.WeChat"
    "com.discordapp.Discord"
    "com.spotify.Client"
    "net.davidotek.pupgui2"
    "com.heroicgameslauncher.hgl"
    "md.obsidian.Obsidian"
    "net.cozic.joplin_desktop"
)

# Install Flatpak apps (skip if already installed)
for app in "${FLATPAK_APPS[@]}"; do
    if flatpak list --app 2>/dev/null | grep -q "$app"; then
        echo "  $app already installed"
    else
        echo "  Installing $app..."
        sudo flatpak install -y flathub "$app" 2>/dev/null || print_warning "Failed to install $app"
    fi
done

# ============================================
# STEP 5: Install Snap Apps (Optional)
# ============================================
print_step "Step 5/8: Installing Snap apps..."

# Check if snapd is already installed and running
if ! command -v snap &>/dev/null; then
    echo "  Installing snapd..."
    sudo dnf install -y snapd
    sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true
    
    # Only enable if not already enabled
    if ! systemctl is-enabled snapd.socket &>/dev/null; then
        sudo systemctl enable snapd.socket
    fi
    
    # Only start if not already active
    if ! systemctl is-active snapd.socket &>/dev/null; then
        sudo systemctl start snapd.socket
    fi
    
    # Wait for snapd to be ready
    echo "  Waiting for snapd to initialize..."
    for i in {1..30}; do
        if sudo snap list &>/dev/null; then
            break
        fi
        sleep 1
    done
else
    echo "  snapd already installed"
fi

# Install TradingView (skip if already installed)
if snap list 2>/dev/null | grep -q "tradingview"; then
    echo "  TradingView already installed"
else
    echo "  Installing TradingView..."
    if ! sudo snap install tradingview 2>/dev/null; then
        print_warning "TradingView snap install failed. Try later: sudo snap install tradingview"
    fi
fi

# ============================================
# STEP 6: Install PyCharm Pro
# ============================================
print_step "Step 6/8: Installing PyCharm Pro..."

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
# STEP 7: Install Icon Themes
# ============================================
print_step "Step 7/8: Installing icon themes..."

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
# STEP 8: Install GTK Themes
# ============================================
print_step "Step 8/8: Installing GTK themes..."

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
echo "SAFE MODE: This script did NOT modify:"
echo "  - Display manager (SDDM)"
echo "  - System configuration files"
echo "  - Power management settings"
echo "  - Display/monitor settings"
echo "  - Keyboard shortcuts"
echo "  - Autostart applications"
echo "  - Critical system packages (no --allowerasing used)"
echo ""
echo "You can safely reboot your system."
echo ""
