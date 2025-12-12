#!/bin/bash
set -e

echo "============================================"
echo "  Fedora Dotfiles Bootstrap"
echo "============================================"
echo ""

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
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
# STEP 1: Setup Repositories
# ============================================
print_step "Step 1/12: Setting up repositories..."

# RPM Fusion
sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    2>/dev/null || true

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

# ROCm repo for AMD GPU tools
sudo tee /etc/yum.repos.d/rocm.repo > /dev/null << 'EOF'
[ROCm]
name=ROCm
baseurl=https://repo.radeon.com/rocm/rhel9/latest/main
enabled=1
gpgcheck=1
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
EOF

# ============================================
# STEP 2: Install Packages
# ============================================
print_step "Step 2/12: Installing packages (this takes a while)..."

# Filter comments and empty lines, then install
grep -v '^#' "$DOTFILES_DIR/packages.txt" | grep -v '^$' | xargs sudo dnf install -y

# Install Dropbox
sudo dnf install -y dropbox nautilus-dropbox 2>/dev/null || true

# Install rocm-smi for AMD GPUs (may fail on non-AMD systems)
sudo dnf install -y rocm-smi 2>/dev/null || true

# ============================================
# STEP 3: Install Flatpak Apps
# ============================================
print_step "Step 3/12: Installing Flatpak apps..."

# Setup Flatpak and Flathub
sudo dnf install -y flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install Flatpak apps
flatpak install -y flathub com.tencent.WeChat 2>/dev/null || true
flatpak install -y flathub com.discordapp.Discord 2>/dev/null || true

# ============================================
# STEP 4: Install Snap Apps
# ============================================
print_step "Step 4/12: Installing Snap apps (TradingView)..."

# Install snapd
sudo dnf install -y snapd
sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true

# Enable and start snapd
sudo systemctl enable --now snapd.socket

# Wait for snapd to be ready
sleep 5

# Install TradingView
sudo snap install tradingview 2>/dev/null || print_warning "TradingView snap install failed - try manually after reboot"

# ============================================
# STEP 5: Install PyCharm Pro
# ============================================
print_step "Step 5/12: Installing PyCharm Pro..."

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
    
    # Create desktop entry
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
# STEP 6: Install auto-cpufreq
# ============================================
print_step "Step 6/12: Installing auto-cpufreq..."

if ! command -v auto-cpufreq &> /dev/null; then
    cd /tmp
    git clone https://github.com/AdnanHodzic/auto-cpufreq.git
    cd auto-cpufreq
    sudo ./auto-cpufreq-installer --install
    cd /tmp
    rm -rf auto-cpufreq
    
    # Enable the service
    sudo auto-cpufreq --install
fi

# ============================================
# STEP 7: Download Battle.net
# ============================================
print_step "Step 7/12: Downloading Battle.net installer..."

mkdir -p ~/Downloads
if [ ! -f ~/Downloads/Battle.net-Setup.exe ]; then
    wget -q "https://www.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP" \
        -O ~/Downloads/Battle.net-Setup.exe
    echo "  Battle.net installer saved to ~/Downloads/Battle.net-Setup.exe"
    echo "  Run with: lutris or wine ~/Downloads/Battle.net-Setup.exe"
fi

# ============================================
# STEP 8: Install Icon Themes
# ============================================
print_step "Step 8/12: Installing icon themes..."

mkdir -p ~/.local/share/icons
cd /tmp

# Tela Circle Icons (your active theme)
if [ ! -d ~/.local/share/icons/Tela-circle-purple-dark ]; then
    echo "  Installing Tela Circle icons..."
    git clone --depth 1 https://github.com/vinceliuice/Tela-circle-icon-theme.git
    cd Tela-circle-icon-theme
    ./install.sh -c purple
    cd /tmp
    rm -rf Tela-circle-icon-theme
fi

# Papirus Icons
if [ ! -d ~/.local/share/icons/Papirus ]; then
    echo "  Installing Papirus icons..."
    wget -qO- https://git.io/papirus-icon-theme-install | sh
fi

# ============================================
# STEP 9: Install GTK Themes  
# ============================================
print_step "Step 9/12: Installing GTK themes..."

mkdir -p ~/.themes

# Copy custom themes from dotfiles
if [ -d "$DOTFILES_DIR/themes" ]; then
    cp -r "$DOTFILES_DIR/themes/"* ~/.themes/
fi

# ============================================
# STEP 10: Copy Configurations
# ============================================
print_step "Step 10/12: Copying configurations..."

# App configs
if [ -d "$DOTFILES_DIR/configs/dot-config" ]; then
    cp -r "$DOTFILES_DIR/configs/dot-config/"* ~/.config/
fi

# Local share data
if [ -d "$DOTFILES_DIR/configs/dot-local-share" ]; then
    mkdir -p ~/.local/share
    cp -r "$DOTFILES_DIR/configs/dot-local-share/"* ~/.local/share/
fi

# Shell configs
[ -f "$DOTFILES_DIR/configs/.bashrc" ] && cp "$DOTFILES_DIR/configs/.bashrc" ~/
[ -f "$DOTFILES_DIR/configs/.bash_profile" ] && cp "$DOTFILES_DIR/configs/.bash_profile" ~/
[ -f "$DOTFILES_DIR/configs/.gtkrc-2.0" ] && cp "$DOTFILES_DIR/configs/.gtkrc-2.0" ~/

# ============================================
# STEP 11: Apply Cinnamon Settings
# ============================================
print_step "Step 11/12: Applying desktop settings..."

if [ -f "$DOTFILES_DIR/configs/full-dconf.txt" ]; then
    # Replace old home path with current user's home
    sed "s|/home/testbug|$HOME|g" "$DOTFILES_DIR/configs/full-dconf.txt" | dconf load /
fi

# ============================================
# STEP 12: Setup Autostart
# ============================================
print_step "Step 13/12: Setting up autostart apps..."

mkdir -p ~/.config/autostart

# Plank
cat > ~/.config/autostart/plank.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Plank
Exec=plank
X-GNOME-Autostart-enabled=true
EOF

# NumLockX
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
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Please LOG OUT and LOG BACK IN for all changes to take effect."
echo ""
echo "Your setup includes:"
echo "  - DNF packages (Brave, Warp, Steam, rclone, etc.)"
echo "  - Flatpak apps (WeChat, Discord)"
echo "  - Snap apps (TradingView)"
echo "  - PyCharm Pro (activate license on first run)"
echo "  - auto-cpufreq (power management)"
echo "  - GPU tools (nvidia-smi, rocm-smi where applicable)"
echo "  - Tela Circle Purple icons"
echo "  - Custom themes"
echo "  - Plank dock (auto-starts)"
echo "  - Keyboard shortcuts:"
echo "      Ctrl+Alt+End   = Shutdown"
echo "      Ctrl+Alt+Home  = Suspend"
echo "      Ctrl+Alt+Insert = Reboot"
echo ""
echo "Manual steps:"
echo "  - Run Battle.net: lutris or wine ~/Downloads/Battle.net-Setup.exe"
echo "  - Log into Dropbox, Steam, Discord, WeChat"
echo "  - Activate PyCharm license"
echo ""
