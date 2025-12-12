#!/usr/bin/env bash
set -euo pipefail

# Download 124 high-quality 2K+ wallpapers from Unsplash
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

# Unsplash collections for variety (nature, landscapes, architecture, abstract)
# Format: collection_id:count
collections=(
    "3330445:31"  # Nature
    "1065976:31"  # Landscapes  
    "1478726:31"  # Abstract
    "139386:31"   # Architecture
)

download_count=0
for collection_data in "${collections[@]}"; do
    IFS=':' read -r collection_id count <<< "$collection_data"
    
    # Break if we've downloaded enough
    [[ $download_count -ge $needed ]] && break
    
    # Adjust count if we need fewer than the collection allocation
    remaining=$((needed - download_count))
    [[ $count -gt $remaining ]] && count=$remaining
    
    echo "  Downloading ${count} from collection ${collection_id}..."
    
    for i in $(seq 1 "$count"); do
        # Use Unsplash Source API (no auth required)
        # &w=2560 ensures minimum width, &fit=max maintains aspect ratio
        url="https://source.unsplash.com/collection/${collection_id}/${MIN_WIDTH}x1440/?sig=${RANDOM}"
        
        output_file="$DEST_DIR/unsplash-${collection_id}-${i}.jpg"
        
        # Skip if file already exists
        if [[ -f "$output_file" ]]; then
            continue
        fi
        
        # Download with retry logic
        if wget -q --timeout=30 --tries=3 "$url" -O "$output_file" 2>/dev/null; then
            sudo chown root:root "$output_file"
            sudo chmod 644 "$output_file"
            ((download_count++))
        else
            print_warn "Failed to download image $i from collection ${collection_id}"
            rm -f "$output_file"
        fi
        
        # Small delay to avoid rate limiting
        sleep 0.5
    done
done

final_count=$(find "$DEST_DIR" -type f -iregex '.*\.(jpg|jpeg|png|webp)$' 2>/dev/null | wc -l)
print_step "Done. Total wallpapers in ${DEST_DIR}: ${final_count}"
