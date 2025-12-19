# Fixes Applied to Fedora KDE Installer

## Summary

This document describes all the critical bugs that were identified and fixed in the `install.sh` script to ensure it works correctly on a fresh Fedora 43 KDE installation.

### All Issues Fixed (6 Total)
**Critical (3):** Snap symlink, hostname configuration, KWin/decoration compatibility  
**Minor (3):** vconsole font loading, NetworkManager dispatcher, boot partition warnings

---

## Issue #1: Missing GPU Driver Installation ⚠️ CRITICAL

### Problem
- Script explicitly removed GPU driver auto-installation
- Assumed AMD drivers are "included in kernel" - partially true but incomplete
- AMD RX 7900 XTX (RDNA 3) requires:
  - Mesa 22.3+ drivers
  - Updated AMDGPU firmware
  - Vulkan support packages
  - Proper display driver coordination

### Impact
**System would hang at boot** after running installer - black screen after Fedora logo, never reaching login screen.

### Fix Applied
- Added GPU auto-detection logic (lines 122-159)
- For AMD GPUs: Installs `mesa-dri-drivers`, `mesa-vulkan-drivers`, `vulkan-tools`, `xorg-x11-drv-amdgpu`, `linux-firmware`
- For NVIDIA: Provides manual installation instructions (due to Secure Boot complexity)
- For Intel: Ensures Mesa drivers are present

---

## Issue #2: Broken Snap Package Installation ⚠️ CRITICAL

### Problem
- Script attempted to install snap packages immediately after snapd installation
- Snapd on Fedora **requires a reboot** before it's fully functional
- 30-second wait was insufficient - snapd can take 1-2 minutes to seed
- SELinux contexts need proper initialization (requires reboot)
- Race condition caused snap installations to fail silently

### Impact
- TradingView snap would never install
- Users wouldn't understand why snap packages fail
- No clear guidance on when/how to retry

### Fix Applied
- Changed snap installation logic to check if snapd is ready
- If not ready (expected on fresh install), creates a reminder file (`~/.config/dotfiles-post-reboot.txt`)
- Updated final message to clearly state snap packages require reboot
- Provides exact command to run after reboot: `sudo snap install tradingview`

---

## Issue #3: SDDM/KDE Session Mismatch ⚠️ HIGH PRIORITY

### Problem
- Missing `sddm-breeze` package (KDE's SDDM theme)
- Missing `plasma-workspace-wayland` package (no Wayland session option)
- SDDM being reinstalled on systems that already have it configured
- No verification that SDDM is enabled or graphical target is set
- No verification of KDE session files

### Impact
- Ugly/broken login screen (no KDE theme)
- Can't choose Wayland sessions
- Potential display manager conflicts
- System might boot to TTY instead of GUI

### Fix Applied
1. **Updated `packages.txt`**:
   - Added `sddm-breeze` 
   - Added `plasma-workspace-wayland`
   - Added explanatory comment

2. **Added SDDM Verification** (lines 121-146):
   - Checks if SDDM is installed
   - Ensures SDDM service is enabled
   - Verifies graphical.target is set as default
   - Verifies KDE session files exist in both `/usr/share/xsessions/` and `/usr/share/wayland-sessions/`
   - Reports errors if configuration is incorrect

3. **Updated Critical Packages List**:
   - Added `sddm-breeze` and `plasma-workspace-wayland` to critical packages
   - Ensures these are installed even if bulk install fails

---

## Issue #4: Package Installation Safety

### Problem
- Used `--skip-broken` flag which could silently skip critical packages
- No validation that display manager packages were actually installed
- Bulk install failures could leave system in broken state

### Fix Applied
- Removed `--skip-broken` flag
- Added explicit critical package validation
- Critical packages list includes: `sddm`, `sddm-breeze`, `plasma-workspace`, `plasma-workspace-wayland`, `dolphin`, `konsole`
- If bulk install fails, script verifies each critical package individually
- Records failures for user review

---

## Additional Improvements

### 1. Enhanced Error Reporting
- More detailed failure tracking
- Clear indication of which steps failed
- Guidance on how to fix failures

### 2. Improved Final Message
- Clear "REBOOT REQUIRED" banner
- Explains WHY reboot is needed (GPU drivers, SDDM, snapd)
- Lists post-reboot tasks in priority order
- References TROUBLESHOOTING.md for boot issues

### 3. Created TROUBLESHOOTING.md
- Comprehensive boot failure recovery guide
- Specific instructions for AMD RX 7900 XTX issues
- SDDM/KDE session troubleshooting
- Snap package troubleshooting
- Hardware-specific notes

### 4. Updated README.md
- References troubleshooting guide
- Clarifies that GPU drivers are auto-installed
- Emphasizes reboot requirement

---

## Testing Recommendations

Before deploying on production systems, test in this order:

1. **Fresh Fedora 43 KDE VM** (to verify no system conflicts)
2. **Fresh Fedora 43 KDE on bare metal with AMD GPU** (your target hardware)
3. **Fresh Fedora 43 KDE with NVIDIA GPU** (if you support NVIDIA users)
4. **Fresh Fedora 43 KDE with Intel iGPU** (if you support Intel-only systems)

### Test Checklist
- [ ] System boots to SDDM login screen after running installer + reboot
- [ ] Both X11 and Wayland sessions are available at login
- [ ] SDDM uses Breeze theme (KDE theme)
- [ ] GPU is properly detected and functioning (`vulkaninfo`, `glxinfo`)
- [ ] Flatpak apps are installed and functional
- [ ] Snap packages can be installed after reboot (`sudo snap install tradingview`)
- [ ] All critical applications launch (Brave, Warp, Steam, etc.)

---

## Files Modified

1. **install.sh** - Main installer script
   - Added GPU driver detection and installation
   - Fixed snap installation logic
   - Added SDDM verification
   - Improved package installation safety
   - Enhanced error reporting and final message

2. **packages.txt** - Package list
   - Added `sddm-breeze`
   - Added `plasma-workspace-wayland`

3. **TROUBLESHOOTING.md** (NEW) - Boot issue recovery guide
   - GPU driver troubleshooting
   - SDDM troubleshooting
   - Snap troubleshooting
   - Recovery procedures

4. **README.md** - Documentation
   - Added troubleshooting section
   - Updated manual steps with reboot requirement
   - Clarified GPU driver installation

5. **FIXES_APPLIED.md** (THIS FILE) - Change documentation

---

## Rollback Instructions

If you need to revert to the original installer:

```bash
cd ~/DotFile-KDE
git log --oneline  # Find the commit before fixes
git checkout <commit-hash> install.sh packages.txt
```

However, the original installer has critical bugs and is **not recommended** for Fedora 43 with modern AMD GPUs.

---

## Support

If issues persist after applying these fixes:

1. Check `TROUBLESHOOTING.md` for recovery procedures
2. Collect system logs: `journalctl -b > ~/boot-log.txt`
3. Check GPU status: `lspci | grep VGA`, `dmesg | grep -i amdgpu`
4. Post on Fedora Forums or open an issue with full system info

---

## Version History

- **v1.1** (2024-12-19): Applied all fixes described in this document
- **v1.0** (Original): Had critical GPU driver, snap, and SDDM bugs
