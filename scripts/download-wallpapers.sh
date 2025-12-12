#!/usr/bin/env bash
set -euo pipefail

# Download 124 high-quality 2K+ wallpapers from Wallhaven
# Images are downloaded directly to /usr/share/backgrounds/custom

DEST_DIR="/usr/share/backgrounds/custom"
TARGET_COUNT=124
MIN_WIDTH=2560

print_step() { echo -e "\033[0;32m==>\033[0m $1"; }
print_warn() { echo -e "\033[1;33mWarning:\033[0m $1"; }

print_step "Downloading ${TARGET_COUNT} high-quality wallpapers..."

# Create destination directory
sudo mkdir -p "$DEST_DIR"

# Count existing wallpapers
existing_count=$(find "$DEST_DIR" -type f -iregex '.*\.(jpg|jpeg|png|webp)$' 2>/dev/null | wc -l)

if [[ $existing_count -ge $TARGET_COUNT ]]; then
    print_step "Already have ${existing_count} wallpapers (target: ${TARGET_COUNT}). Skipping download."
    exit 0
fi

needed=$((TARGET_COUNT - existing_count))
print_step "Downloading ${needed} new wallpapers (already have ${existing_count})..."

# Download to temp directory first, then move with sudo
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Use Wallhaven API (public, no auth needed for SFW general content)
echo "  Downloading wallpapers from Wallhaven..."

# Categories: general (100), anime (010), people (001)
# Purity: sfw (100), sketchy (010), nsfw (001) - we use only SFW
# Sorting: toplist for highest quality
categories="100"  # General only
purity="100"     # SFW only
sorting="toplist"
atleast="2560x1440"  # Min resolution

download_count=0
page=1

while [[ $download_count -lt $needed ]]; do
    echo "  Fetching page ${page}..."
    
    # Wallhaven API: get wallpaper list
    api_url="https://wallhaven.cc/api/v1/search?categories=${categories}&purity=${purity}&sorting=${sorting}&atleast=${atleast}&page=${page}"
    
    # Download API response
    response_file="$TEMP_DIR/api_response_${page}.json"
    if ! wget -q --timeout=30 "$api_url" -O "$response_file" 2>/dev/null; then
        print_warn "Failed to fetch API page ${page}"
        break
    fi
    
    # Extract image URLs from JSON response  
    # Wallhaven API returns: {"data": [{"path": "https://...", ...}, ...]}
    # The path field contains URLs like: https:\/\/w.wallhaven.cc\/full\/k8\/wallhaven-k881zd.jpg
    # Need to unescape the backslashes
    mapfile -t image_urls < <(grep -oP '"path":"\K[^"]+' "$response_file" | sed 's/\\//g' || true)
    
    if [[ ${#image_urls[@]} -eq 0 ]]; then
        echo "  No more images available"
        break
    fi
    
    for url in "${image_urls[@]}"; do
        [[ $download_count -ge $needed ]] && break
        
        # Extract filename from URL
        filename=$(basename "$url")
        final_file="$DEST_DIR/${filename}"
        temp_file="$TEMP_DIR/${filename}"
        
        # Skip if already exists
        if [[ -f "$final_file" ]]; then
            continue
        fi
        
        # Download image
        if wget -q --timeout=30 --tries=2 "$url" -O "$temp_file" 2>/dev/null; then
            # Verify it's an image
            if file "$temp_file" | grep -qi "image\|jpeg\|png"; then
                # Move to destination with sudo
                sudo mv "$temp_file" "$final_file"
                sudo chown root:root "$final_file"
                sudo chmod 644 "$final_file"
                ((download_count++))
                echo "    Downloaded: ${filename} (${download_count}/${needed})"
            else
                rm -f "$temp_file"
            fi
        else
            rm -f "$temp_file"
        fi
        
        # Small delay
        sleep 0.2
    done
    
    ((page++))
    
    # Safety: don't loop forever
    if [[ $page -gt 10 ]]; then
        break
    fi
done

final_count=$(find "$DEST_DIR" -type f -iregex '.*\.(jpg|jpeg|png|webp)$' 2>/dev/null | wc -l)
print_step "Done. Total wallpapers in ${DEST_DIR}: ${final_count}"
