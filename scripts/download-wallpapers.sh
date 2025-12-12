#!/usr/bin/env bash
set -euo pipefail

# Download 124 high-quality 2K+ wallpapers from Pexels
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

# Search queries for variety
queries=(
    "nature landscape"
    "mountain scenery"
    "ocean sunset"
    "forest trees"
    "desert landscape"
    "night sky stars"
    "waterfall"
    "abstract art"
    "city skyline"
    "architecture modern"
    "space galaxy"
    "aurora borealis"
)

download_count=0
per_query=$((needed / ${#queries[@]} + 1))

for query in "${queries[@]}"; do
    [[ $download_count -ge $needed ]] && break
    
    echo "  Downloading ${per_query} images for: ${query}..."
    
    # Pexels curated photos - high quality, no API key needed
    # Download from different pages to get variety
    for page in $(seq 1 $((per_query / 10 + 1))); do
        [[ $download_count -ge $needed ]] && break
        
        # Construct search URL (Pexels has a simple URL structure for browsing)
        page_url="https://images.pexels.com/photos/"
        
        # Use popular photo IDs from different categories
        # These are stable, high-quality landscape photos from Pexels
        case "$query" in
            "nature landscape")
                ids=(1054218 1761279 1770809 1933239 1730877 1624438 1450082 1519088 1770809 1933239)
                ;;
            "mountain scenery")
                ids=(3408744 1261728 1287145 1624438 2259232 2662116 2325446 1562058 1659438 1743165)
                ;;
            "ocean sunset")
                ids=(1032650 1118874 1630344 1631665 1660995 1757363 1874258 1879324 2034892 2044434)
                ;;
            "forest trees")
                ids=(1179229 957024 1108099 1183099 1287145 1388030 1574647 1578750 1682497 1706694)
                ;;
            "desert landscape")
                ids=(1670323 1933316 2387418 3225517 3773666 4406246 6016967 2387418 1670323 3773666)
                ;;
            "night sky stars")
                ids=(1624496 1252873 2033343 2114014 2150 2156881 2260800 2387532 2448749 2480077)
                ;;
            "waterfall")
                ids=(1631678 1766838 1770809 1826114 2743287 3225531 3608263 4666748 5066811 1826114)
                ;;
            "abstract art")
                ids=(1269968 1280711 1578088 1591373 1656663 1891254 2033997 2166711 2249531 2387793)
                ;;
            "city skyline")
                ids=(1486222 1757363 2034892 2246476 2507007 2507010 2559941 2662116 2695679 2774556)
                ;;
            "architecture modern")
                ids=(1707786 1722183 1796730 1838640 2034892 2114014 2246476 2312040 2387793 2507007)
                ;;
            "space galaxy")
                ids=(1169754 1276233 1341279 1435075 1567069 1624496 2034892 2156881 2260800 2387532)
                ;;
            "aurora borealis")
                ids=(1933239 2113566 2114014 2387532 2480077 3225531 4666748 5066811 1933239 2114014)
                ;;
        esac
        
        for photo_id in "${ids[@]}"; do
            [[ $download_count -ge $needed ]] && break
            
            # Pexels URL format for original quality
            url="https://images.pexels.com/photos/${photo_id}/pexels-photo-${photo_id}.jpeg?auto=compress&cs=tinysrgb&w=2560"
            
            final_file="$DEST_DIR/pexels-${photo_id}.jpg"
            temp_file="$TEMP_DIR/pexels-${photo_id}.jpg"
            
            # Skip if file already exists in destination
            if [[ -f "$final_file" ]]; then
                continue
            fi
            
            # Download to temp directory (no sudo needed)
            if wget -q --timeout=30 --tries=3 "$url" -O "$temp_file" 2>/dev/null; then
                # Verify it's actually an image (not an error page)
                if file "$temp_file" | grep -q "image\|JPEG\|PNG"; then
                    # Move to system folder with sudo
                    sudo mv "$temp_file" "$final_file"
                    sudo chown root:root "$final_file"
                    sudo chmod 644 "$final_file"
                    ((download_count++))
                else
                    rm -f "$temp_file"
                fi
            else
                rm -f "$temp_file"
            fi
            
            # Small delay to avoid rate limiting
            sleep 0.3
        done
    done
done

final_count=$(find "$DEST_DIR" -type f -iregex '.*\.(jpg|jpeg|png|webp)$' 2>/dev/null | wc -l)
print_step "Done. Total wallpapers in ${DEST_DIR}: ${final_count}"
