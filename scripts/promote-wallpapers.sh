#!/usr/bin/env bash
set -euo pipefail

# Promote 2K+ wallpapers to system folder for the Cinnamon Backgrounds picker
# - Collects images from common user locations
# - Filters by MIN_WIDTH (default 2560)
# - Copies to /usr/share/backgrounds/custom (creates if missing)
# - Removes images in the destination below MIN_WIDTH
#
# Usage:
#   scripts/promote-wallpapers.sh [--min-width 2560] [--source DIR ...]

MIN_WIDTH=2560
DEST_DIR="/usr/share/backgrounds/custom"

# Default sources (can be overridden/appended via --source flags)
SOURCES=(
  "$HOME/Pictures/Wallpapers"
  "$HOME/Pictures"
  "$HOME/.config/variety/Downloaded"
)

print_step() { echo -e "\033[0;32m==>\033[0m $1"; }
print_warn() { echo -e "\033[1;33mWarning:\033[0m $1"; }

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --min-width)
      MIN_WIDTH=${2:-2560}
      shift 2 ;;
    --source)
      SOURCES+=("${2:-}")
      shift 2 ;;
    *)
      print_warn "Unknown arg: $1 (ignored)"; shift ;;
  esac
done

print_step "Ensuring ImageMagick is available..."
if ! command -v identify &>/dev/null; then
  sudo dnf install -y ImageMagick >/dev/null
fi

print_step "Creating destination: $DEST_DIR"
sudo mkdir -p "$DEST_DIR"

# Gather candidates (common image formats, >2 MiB for quality)
TMP_LIST=$(mktemp)
for src in "${SOURCES[@]}"; do
  [[ -d "$src" ]] || continue
  find "$src" -type f -iregex '.*\.(jpg|jpeg|png|webp)$' -size +2M -print >> "$TMP_LIST" || true
done

if [[ ! -s "$TMP_LIST" ]]; then
  print_warn "No candidate images found in: ${SOURCES[*]}"; exit 0
fi

print_step "Filtering images by width >= ${MIN_WIDTH}px and copying (skip existing by name)"
while IFS= read -r img; do
  # Some files may fail identify; skip those quietly
  width=$(identify -format '%w' "$img" 2>/dev/null || echo 0)
  [[ ${width:-0} -ge $MIN_WIDTH ]] || continue
  base=$(basename "$img")
  if [[ -e "$DEST_DIR/$base" ]]; then
    continue
  fi
  sudo cp -n "$img" "$DEST_DIR/" || true
done < "$TMP_LIST"

rm -f "$TMP_LIST"

print_step "Removing destination images below ${MIN_WIDTH}px (cleanup)"
# Remove only files that are images and are below threshold
while IFS= read -r img; do
  width=$(identify -format '%w' "$img" 2>/dev/null || echo 0)
  if [[ ${width:-0} -lt $MIN_WIDTH ]]; then
    sudo rm -f "$img"
  fi
done < <(find "$DEST_DIR" -type f -iregex '.*\.(jpg|jpeg|png|webp)$' -print)

print_step "Done. Wallpapers available in Cinnamon under Backgrounds -> /usr/share/backgrounds/custom"
