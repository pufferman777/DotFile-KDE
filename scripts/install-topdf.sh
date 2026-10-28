#!/usr/bin/env bash
set -euo pipefail

# Install "Convert to PDF" for Dolphin (right-click on .docx/.doc/.odt files)
# - Installs LibreOffice Writer if missing (needs sudo)
# - Writes ~/.local/bin/topdf (headless LibreOffice converter, also usable from a terminal)
# - Writes the Dolphin right-click entry to ~/.local/share/kio/servicemenus/topdf.desktop
# - Safe to re-run; overwrites both files with the current version
#
# Usage:
#   scripts/install-topdf.sh
#   curl -fsSL https://raw.githubusercontent.com/pufferman777/DotFile-KDE/master/scripts/install-topdf.sh | bash
#
# After installing: quit Dolphin (Ctrl+Q) and reopen it.

if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script as root. Run as your normal user."
    exit 1
fi

if ! command -v soffice >/dev/null 2>&1; then
    echo "==> Installing LibreOffice Writer (needed for the PDF conversion)..."
    sudo dnf install -y libreoffice-writer
fi

BIN_DIR="$HOME/.local/bin"
MENU_DIR="$HOME/.local/share/kio/servicemenus"
mkdir -p "$BIN_DIR" "$MENU_DIR"

cat > "$BIN_DIR/topdf" << 'EOF'
#!/usr/bin/env bash
# Convert .docx/.odt/.doc files to PDF next to each original (headless LibreOffice).
# Usage: topdf file1.docx [file2.docx ...]   — also used by the Dolphin right-click menu.
# Uses its own LibreOffice profile so it works even while LibreOffice is open.
profile="file://$HOME/.cache/topdf-lo-profile"
ok=0; fail=0
for f in "$@"; do
  [ -f "$f" ] || { echo "skip (not a file): $f"; fail=$((fail+1)); continue; }
  dir=$(dirname -- "$f")
  if soffice -env:UserInstallation="$profile" --headless --convert-to pdf --outdir "$dir" "$f" >/dev/null 2>&1 \
     && [ -f "$dir/$(basename -- "${f%.*}").pdf" ]; then
    ok=$((ok+1)); echo "ok: ${f%.*}.pdf"
  else
    fail=$((fail+1)); echo "FAILED: $f"
  fi
done
msg="$ok converted to PDF"; [ "$fail" -gt 0 ] && msg="$msg, $fail failed"
if command -v kdialog >/dev/null; then kdialog --passivepopup "$msg" 5 --title "Convert to PDF" >/dev/null 2>&1 &
elif command -v notify-send >/dev/null; then notify-send -i application-pdf "Convert to PDF" "$msg" >/dev/null 2>&1; fi
echo "$msg"
EOF
chmod +x "$BIN_DIR/topdf"

# KDE ignores service menus in the user folder unless they are executable
cat > "$MENU_DIR/topdf.desktop" << EOF
[Desktop Entry]
Type=Service
MimeType=application/vnd.openxmlformats-officedocument.wordprocessingml.document;application/msword;application/vnd.oasis.opendocument.text;
Actions=topdf
X-KDE-Priority=TopLevel

[Desktop Action topdf]
Name=Convert to PDF
Icon=application-pdf
Exec=$BIN_DIR/topdf %F
EOF
chmod +x "$MENU_DIR/topdf.desktop"

echo "==> Convert to PDF installed."
echo "    Right-click: quit Dolphin (Ctrl+Q), reopen it, then right-click Word files."
echo "    Terminal:    topdf file.docx"
