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
# STEP 0: System Configuration
# ============================================
print_step "Step 0/10: Configuring system basics..."

# Set hostname if it's still default "fedora"
CURRENT_HOSTNAME=$(hostnamectl hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "")
if [ "$CURRENT_HOSTNAME" = "fedora" ] || [ -z "$CURRENT_HOSTNAME" ]; then
    echo "  Current hostname is default or empty: '$CURRENT_HOSTNAME'"
    read -p "  Enter a hostname for this machine (or press Enter to keep 'fedora'): " NEW_HOSTNAME
    if [ -n "$NEW_HOSTNAME" ] && [ "$NEW_HOSTNAME" != "fedora" ]; then
        if sudo hostnamectl set-hostname "$NEW_HOSTNAME"; then
            echo "  Hostname set to: $NEW_HOSTNAME"
        else
            print_warning "Failed to set hostname"
        fi
    else
        echo "  Keeping default hostname: fedora"
    fi
else
    echo "  Hostname already configured: $CURRENT_HOSTNAME"
fi

# Fix vconsole font loading (common Fedora issue)
if [ ! -f /etc/vconsole.conf ] || ! grep -q "FONT=" /etc/vconsole.conf 2>/dev/null; then
    echo "  Configuring virtual console font..."
    # Use a safe, universally available font
    echo 'FONT=eurlatgr' | sudo tee /etc/vconsole.conf > /dev/null
    echo 'KEYMAP=us' | sudo tee -a /etc/vconsole.conf > /dev/null
fi

# Ensure NetworkManager dispatcher directory exists (prevents activation failures)
if [ ! -d /etc/NetworkManager/dispatcher.d ]; then
    echo "  Creating NetworkManager dispatcher directory..."
    sudo mkdir -p /etc/NetworkManager/dispatcher.d
    sudo chmod 755 /etc/NetworkManager/dispatcher.d
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

# Critical packages that must succeed (display manager and core KDE)
CRITICAL_PKGS=("sddm" "sddm-breeze" "plasma-workspace" "plasma-workspace-wayland" "dolphin" "konsole")

# Try bulk install first (more efficient)
if ! sudo dnf install -y --allowerasing --skip-unavailable "${PKGS[@]}"; then
    print_warning "Bulk install had issues; verifying critical packages..."
    
    # Ensure critical packages are installed
    for p in "${CRITICAL_PKGS[@]}"; do
        if ! rpm -q "$p" &>/dev/null; then
            if ! sudo dnf install -y "$p"; then
                print_error "Failed to install critical package: $p"
                record_failure "Step 2: Critical package installation ($p)"
            fi
        fi
    done
    
    # Install remaining packages individually
    for p in "${PKGS[@]}"; do
        sudo dnf install -y --skip-unavailable "$p" || print_warning "Skipped: $p"
    done
fi

# Install Dropbox
sudo dnf install -y dropbox nautilus-dropbox 2>/dev/null || true

# Verify SDDM is properly configured
print_step "Verifying SDDM display manager configuration..."
if rpm -q sddm &>/dev/null; then
    # Ensure SDDM is enabled and set as default
    if ! sudo systemctl is-enabled sddm.service &>/dev/null; then
        echo "  Enabling SDDM..."
        sudo systemctl enable sddm.service
    fi
    
    # Ensure graphical target is set
    if ! systemctl get-default | grep -q graphical.target; then
        echo "  Setting graphical.target as default..."
        sudo systemctl set-default graphical.target
    fi
    
    # Verify KDE session files exist
    if [ ! -f /usr/share/xsessions/plasma.desktop ] && [ ! -f /usr/share/wayland-sessions/plasma.desktop ]; then
        print_warning "KDE Plasma session files not found! This may cause login issues."
        record_failure "SDDM Configuration: Missing KDE session files"
    else
        echo "  SDDM and KDE Plasma sessions verified"
    fi
else
    print_warning "SDDM package not installed - display manager may not work"
    record_failure "SDDM Configuration: Package not installed"
fi

# ============================================
# GPU Driver Detection and Installation
# ============================================
print_step "Detecting GPU and installing drivers..."

# Detect GPU vendor
if lspci | grep -i vga | grep -iq "amd\|radeon"; then
    echo "  Detected AMD GPU"
    
    # For AMD RX 7000 series (RDNA 3), ensure latest Mesa and firmware
    echo "  Installing AMD drivers and firmware..."
    if ! sudo dnf install -y \
        mesa-dri-drivers \
        mesa-vulkan-drivers \
        vulkan-tools \
        mesa-libGL \
        xorg-x11-drv-amdgpu \
        linux-firmware; then
        print_error "Failed to install AMD drivers"
        record_failure "GPU Driver Installation: AMD"
    fi
    
    # Optional: ROCm for compute (usually not needed for gaming/desktop)
    # sudo dnf install rocm-smi rocm-clinfo 2>/dev/null || true
    
elif lspci | grep -i vga | grep -iq "nvidia"; then
    echo "  Detected NVIDIA GPU"
    print_warning "NVIDIA drivers require manual installation due to Secure Boot considerations."
    print_warning "After reboot, run: sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda"
    print_warning "If Secure Boot is enabled, you'll need to enroll the MOK key on reboot."
    record_failure "GPU Driver Installation: NVIDIA (manual step required)"
    
elif lspci | grep -i vga | grep -iq "intel"; then
    echo "  Detected Intel GPU (drivers included in kernel)"
    # Ensure Intel drivers are present
    sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-tools 2>/dev/null || true
else
    print_warning "Could not detect GPU vendor. Skipping driver installation."
fi

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
print_step "Step 4/10: Setting up Snap (requires reboot)..."

# Install snapd
if sudo dnf install -y snapd; then
    echo "  Enabling snapd services..."
    sudo systemctl enable --now snapd.socket
    sudo systemctl enable --now snapd.seeded.service 2>/dev/null || true
    
    # Create /snap symlink (needed for classic snaps)
    sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true
    
    # Check if snapd is ready (on fresh installs, it won't be)
    if sudo snap list &>/dev/null 2>&1; then
        echo "  Snapd is ready, installing TradingView..."
        if ! sudo snap install tradingview 2>/dev/null; then
            print_warning "TradingView snap install failed"
            record_failure "Step 4: Snap app installation"
        fi
    else
        print_warning "Snapd requires a reboot before snaps can be installed."
        print_warning "After reboot, run: sudo snap install tradingview"
        # Create a post-reboot reminder file
        mkdir -p ~/.config
        cat > ~/.config/dotfiles-post-reboot.txt << 'SNAPEOF'
To complete snap setup, run:
  sudo snap install tradingview

You can also install other snaps:
  sudo snap install spotify slack discord
SNAPEOF
    fi
else
    print_error "Failed to install snapd"
    record_failure "Step 4: Snapd installation"
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
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  REBOOT REQUIRED${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "A reboot is required to complete the installation."
echo "This ensures:"
echo "  - GPU drivers are properly loaded"
echo "  - SDDM display manager is initialized"
echo "  - Snap packages can be installed (snapd requires reboot)"
echo ""
echo -e "${YELLOW}After reboot, complete these steps:${NC}"
if [ -f ~/.config/dotfiles-post-reboot.txt ]; then
    echo -e "${YELLOW}  - Install snap packages: sudo snap install tradingview${NC}"
fi
echo "  - Sign in: Dropbox, Steam, Discord, WeChat"
echo "  - Activate PyCharm Pro license"
echo "  - Configure KDE appearance: System Settings > Appearance"
echo "  - Run Battle.net: lutris or wine ~/Downloads/Battle.net-Setup.exe"
echo ""
echo -e "${YELLOW}IMPORTANT: If system fails to boot:${NC}"
echo "  1. Boot into recovery mode or press Ctrl+Alt+F3 for TTY"
echo "  2. Login and run: sudo dnf update --refresh"
echo "  3. Rebuild initramfs: sudo dracut --force --regenerate-all"
echo "  4. For AMD GPU issues: sudo dnf reinstall mesa-dri-drivers mesa-vulkan-drivers"
echo "  5. See TROUBLESHOOTING.md for detailed recovery steps"
echo ""
echo "Your setup includes:"
echo "  - DNF packages (Brave, Warp, Steam, rclone, etc.)"
echo "  - KDE Plasma with SDDM (X11 + Wayland sessions)"
echo "  - Flatpak apps (WeChat, Discord, Spotify, Obsidian)"
echo "  - Snap support (snapd installed, requires reboot)"
echo "  - PyCharm Pro (activate license on first run)"
echo "  - Multiple icon themes (Tela Circle, Papirus, Colloid, etc.)"
echo "  - Custom GTK themes and 2K+ wallpapers"
echo "  - GPU drivers (auto-detected and installed)"
if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Note: Review the errors above and manually complete any failed steps.${NC}"
fi
echo ""
