# Troubleshooting Boot Issues

## System Hangs on Boot / Black Screen After Fedora Logo

This typically indicates GPU driver issues. Follow these steps to recover:

### 1. Access Recovery Mode

**Option A: Boot into Recovery Mode**
1. Reboot the system
2. At GRUB menu, select the current kernel
3. Press `e` to edit boot parameters
4. Find the line starting with `linux` or `linuxefi`
5. Add `nomodeset` to the end of that line
6. Press `Ctrl+X` or `F10` to boot with these parameters

**Option B: Access TTY**
1. When stuck at black screen, press `Ctrl+Alt+F3`
2. Login with your username and password

### 2. Fix GPU Drivers (AMD RX 7900 XTX)

Once you have terminal access:

```bash
# Update system first
sudo dnf update --refresh -y

# Reinstall AMD GPU drivers and Mesa
sudo dnf reinstall -y \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    mesa-libGL \
    xorg-x11-drv-amdgpu \
    linux-firmware

# Install any missing packages
sudo dnf install -y \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    vulkan-tools \
    mesa-libGL \
    xorg-x11-drv-amdgpu \
    mesa-libEGL \
    mesa-libgbm \
    libdrm

# Rebuild initramfs
sudo dracut --force --regenerate-all

# Verify SDDM is properly configured
sudo systemctl enable sddm
sudo systemctl set-default graphical.target

# Reboot
sudo reboot
```

### 3. If Problem Persists

Try booting with alternative drivers:

```bash
# Boot with older kernel (select from GRUB menu)
# Or boot with kernel parameter: amdgpu.dc=0

# Edit GRUB permanently if needed
sudo nano /etc/default/grub
# Add to GRUB_CMDLINE_LINUX: amdgpu.dc=0
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

### 4. Nuclear Option: Rollback

If you need to completely rollback the installation:

```bash
# Remove gaming packages that might conflict
sudo dnf remove -y gamemode mangohud gamescope

# Reset display manager
sudo systemctl disable sddm
sudo systemctl enable gdm  # or sddm
sudo systemctl set-default graphical.target

# Clean and rebuild
sudo dnf clean all
sudo dnf update --refresh -y
sudo dracut --force --regenerate-all
```

## Common Issues

### Black Screen but System Responds
- **Cause**: Display manager (SDDM) not starting
- **Fix**: 
  ```bash
  # From TTY (Ctrl+Alt+F3)
  sudo systemctl restart sddm
  
  # If still not working, check status
  sudo systemctl status sddm
  journalctl -xe -u sddm
  ```

### System Boots to TTY Instead of GUI
- **Cause**: Graphical target not set or SDDM not enabled
- **Fix**: 
  ```bash
  sudo systemctl set-default graphical.target
  sudo systemctl enable sddm
  sudo reboot
  ```

### SDDM Shows Wrong Theme or No KDE Session
- **Cause**: Missing sddm-breeze or KDE session files
- **Fix**:
  ```bash
  # Install missing packages
  sudo dnf install -y sddm-breeze plasma-workspace plasma-workspace-wayland
  
  # Verify session files exist
  ls -la /usr/share/xsessions/plasma.desktop
  ls -la /usr/share/wayland-sessions/plasma.desktop
  
  # If missing, reinstall plasma-workspace
  sudo dnf reinstall plasma-workspace plasma-workspace-wayland
  
  sudo systemctl restart sddm
  ```

### Snap Packages Won't Install
- **Cause**: Snapd requires reboot after initial installation on Fedora
- **Fix**:
  ```bash
  # After first reboot, check snapd status
  sudo systemctl status snapd.socket
  sudo systemctl status snapd.seeded.service
  
  # If services are active, install snaps
  sudo snap install tradingview
  
  # If still failing, try
  sudo systemctl restart snapd.socket
  sudo snap install core
  sudo snap refresh
  ```

### GPU Not Detected
```bash
# Check GPU detection
lspci | grep -i vga
lspci | grep -i amd

# Check loaded drivers
lsmod | grep amdgpu
dmesg | grep -i amdgpu | tail -20
```

### Verify GPU is Working After Fix
```bash
# Check Vulkan
vulkaninfo | head -20

# Check OpenGL
glxinfo | grep "OpenGL renderer"

# Check driver version
modinfo amdgpu | grep version
```

## Prevention

Before running the installer on a fresh system:

1. **Update first**: `sudo dnf update --refresh -y && sudo reboot`
2. **Verify GPU drivers**: Ensure base system boots properly
3. **Take snapshot**: If using VM or have BTRFS/LVM snapshots enabled
4. **Run installer in stages**: Comment out sections and test incrementally

## Hardware-Specific Notes

### AMD RX 7900 XTX (RDNA 3)
- Requires Fedora 37+ with kernel 6.0+
- Mesa 22.3+ required for full support
- Fedora 43 should have all required drivers
- If issues persist, check BIOS settings:
  - Disable CSM (Compatibility Support Module)
  - Enable Above 4G Decoding
  - Enable Resizable BAR

### Intel i9-11900
- iGPU should be disabled in BIOS if using dedicated GPU
- Or configure for hybrid graphics if needed

## Getting Help

If problems continue:
1. Check kernel version: `uname -r` (should be 6.x+)
2. Check Mesa version: `glxinfo | grep "Mesa"` (should be 23.x+)
3. Collect logs: `journalctl -b -p err` and `dmesg | grep -i error`
4. Post on Fedora Forums or r/Fedora with full system info
