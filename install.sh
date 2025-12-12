#!/bin/bash
set -e

echo "============================================"
echo "  Fedora Dotfiles Bootstrap"
echo "============================================"
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
# STEP 1: Setup Repositories
# ============================================
print_step "Step 1/10: Setting up repositories..."

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

# Conditionally install NVIDIA 32-bit userspace if NVIDIA driver is present
if command -v nvidia-smi &>/dev/null || rpm -q akmod-nvidia &>/dev/null || rpm -q xorg-x11-drv-nvidia &>/dev/null; then
  print_step "NVIDIA detected: installing 32-bit userspace libs..."
  sudo dnf install -y --skip-broken --skip-unavailable xorg-x11-drv-nvidia-libs.i686 cuda-libs.i686 2>/dev/null || true
fi

# ============================================
# STEP 3: Install Flatpak Apps
# ============================================
print_step "Step 3/10: Installing Flatpak apps..."

sudo dnf install -y flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install -y flathub com.tencent.WeChat 2>/dev/null || true
flatpak install -y flathub com.discordapp.Discord 2>/dev/null || true
# Gaming helpers
flatpak install -y flathub net.davidotek.pupgui2 2>/dev/null || true
flatpak install -y flathub com.heroicgameslauncher.hgl 2>/dev/null || true

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
# STEP 6: Install auto-cpufreq
# ============================================
print_step "Step 6/10: Installing auto-cpufreq..."

if ! command -v auto-cpufreq &> /dev/null; then
    cd /tmp
    git clone https://github.com/AdnanHodzic/auto-cpufreq.git
    cd auto-cpufreq
    sudo ./auto-cpufreq-installer --install
    cd /tmp
    rm -rf auto-cpufreq
    sudo auto-cpufreq --install
fi

# ============================================
# STEP 7: Download Battle.net
# ============================================
print_step "Step 7/10: Downloading Battle.net installer..."

mkdir -p ~/Downloads
if [ ! -f ~/Downloads/Battle.net-Setup.exe ]; then
    wget -q "https://www.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP" \
        -O ~/Downloads/Battle.net-Setup.exe
    echo "  Battle.net installer saved to ~/Downloads/Battle.net-Setup.exe"
fi

# ============================================
# STEP 8: Install Icon Themes
# ============================================
print_step "Step 8/10: Installing icon themes..."

mkdir -p ~/.local/share/icons
cd /tmp

# Tela Circle (all colors)
if [ ! -d ~/.local/share/icons/Tela-circle-purple-dark ]; then
    echo "  Installing Tela Circle icons (all colors)..."
    git clone --depth 1 https://github.com/vinceliuice/Tela-circle-icon-theme.git
    cd Tela-circle-icon-theme
    ./install.sh
    cd /tmp
    rm -rf Tela-circle-icon-theme
fi

# Papirus (includes Dark, Light variants)
if [ ! -d ~/.local/share/icons/Papirus ]; then
    echo "  Installing Papirus icons..."
    wget -qO- https://git.io/papirus-icon-theme-install | sh
fi

# Colloid (Purple, Teal, Yellow - all variants)
if [ ! -d ~/.local/share/icons/Colloid-Purple ]; then
    echo "  Installing Colloid icons..."
    git clone --depth 1 https://github.com/vinceliuice/Colloid-icon-theme.git
    cd Colloid-icon-theme
    ./install.sh -t all
    cd /tmp
    rm -rf Colloid-icon-theme
fi

# Flat-Remix (all colors)
if [ ! -d ~/.local/share/icons/Flat-Remix-Blue-Dark ]; then
    echo "  Installing Flat-Remix icons..."
    git clone --depth 1 https://github.com/daniruiz/flat-remix.git
    cd flat-remix
    mkdir -p ~/.local/share/icons
    cp -r Flat-Remix-* ~/.local/share/icons/
    cd /tmp
    rm -rf flat-remix
fi

# McMojave Circle (all colors)
if [ ! -d ~/.local/share/icons/McMojave-circle-purple ]; then
    echo "  Installing McMojave Circle icons..."
    git clone --depth 1 https://github.com/vinceliuice/McMojave-circle.git
    cd McMojave-circle
    ./install.sh
    cd /tmp
    rm -rf McMojave-circle
fi

# WhiteSur (all colors)
if [ ! -d ~/.local/share/icons/WhiteSur-purple ]; then
    echo "  Installing WhiteSur icons..."
    git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme.git
    cd WhiteSur-icon-theme
    ./install.sh -a
    cd /tmp
    rm -rf WhiteSur-icon-theme
fi

# Inverse (orange)
if [ ! -d ~/.local/share/icons/Inverse-orange ]; then
    echo "  Installing Inverse icons..."
    git clone --depth 1 https://github.com/yeyushengfan258/Inverse-icon-theme.git
    cd Inverse-icon-theme
    ./install.sh -orange
    cd /tmp
    rm -rf Inverse-icon-theme
fi

# Oranchelo
if [ ! -d ~/.local/share/icons/Oranchelo ]; then
    echo "  Installing Oranchelo icons..."
    git clone --depth 1 https://github.com/OrancheloTeam/oranchelo-icon-theme.git
    cd oranchelo-icon-theme
    mkdir -p ~/.local/share/icons
    cp -r Oranchelo ~/.local/share/icons/
    cd /tmp
    rm -rf oranchelo-icon-theme
fi

# Zafiro (Dark + Blue-f variants)
if [ ! -d ~/.local/share/icons/Zafiro-Icons-Dark ]; then
    echo "  Installing Zafiro icons..."
    git clone --depth 1 https://github.com/zayronxio/Zafiro-icons.git
    cd Zafiro-icons
    mkdir -p ~/.local/share/icons
    cp -r Zafiro* ~/.local/share/icons/
    cd /tmp
    rm -rf Zafiro-icons
fi

# ============================================
# STEP 9: Install GTK Themes
# ============================================
print_step "Step 9/10: Installing GTK themes..."

mkdir -p ~/.themes
if [ -d "$DOTFILES_DIR/themes" ]; then
    cp -r "$DOTFILES_DIR/themes/"* ~/.themes/
fi

# ============================================
# STEP 10: Apply Keyboard Shortcuts
# ============================================
print_step "Step 10/10: Applying keyboard shortcuts..."

if [ -f "$DOTFILES_DIR/configs/keyboard-shortcuts.dconf" ]; then
    dconf load /org/cinnamon/desktop/keybindings/ < "$DOTFILES_DIR/configs/keyboard-shortcuts.dconf" || \
        print_warning "Could not apply keyboard shortcuts; you may need to set them manually."
fi

# Setup autostart
mkdir -p ~/.config/autostart

cat > ~/.config/autostart/plank.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Plank
Exec=plank
X-GNOME-Autostart-enabled=true
EOF

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
echo "  - Tela Circle Purple icons"
echo "  - Custom themes"
echo "  - Plank dock (auto-starts)"
echo "  - Keyboard shortcuts:"
echo "      Ctrl+Alt+End    = Shutdown"
echo "      Ctrl+Alt+Home   = Suspend"
echo "      Ctrl+Alt+Insert = Reboot"
echo "      Ctrl+Shift+~    = Area screenshot to clipboard"
echo ""
echo "Manual steps:"
echo "  - Run Battle.net: lutris or wine ~/Downloads/Battle.net-Setup.exe"
echo "  - Log into Dropbox, Steam, Discord, WeChat"
echo "  - Activate PyCharm license"
echo "  - Install GPU drivers manually if needed:"
echo "      NVIDIA: sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda"
echo "      AMD:    sudo dnf install rocm-smi"
echo ""
