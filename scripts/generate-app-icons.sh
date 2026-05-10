#!/bin/bash
# Generate macOS app icons from a source image with squircle rounded corners.
# Usage: ./scripts/generate-app-icons.sh <source-image>
# Example: ./scripts/generate-app-icons.sh ~/Downloads/logo.png

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/HotLingo/Resources/Assets.xcassets/AppIcon.appiconset"

# --- Validate input ---
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <source-image>"
  echo "Example: $0 ~/Downloads/logo.png"
  exit 1
fi

SOURCE="$1"

if [[ ! -f "$SOURCE" ]]; then
  echo "Error: File not found: $SOURCE"
  exit 1
fi

if ! command -v magick &>/dev/null; then
  echo "Error: ImageMagick not found. Install with: brew install imagemagick"
  exit 1
fi

# --- Generate icon ---
# Corner radius = 22% of size (macOS squircle standard)
gen_icon() {
  local size=$1
  local output=$2
  local radius=$((size * 22 / 100))

  magick "$SOURCE" -filter Lanczos -resize ${size}x${size}! -alpha set \
    \( -size ${size}x${size} xc:none \
       -fill white \
       -draw "roundrectangle 0,0,$((size-1)),$((size-1)),$radius,$radius" \
    \) \
    -compose DstIn -composite \
    "PNG32:$DEST/$output"

  local corner_alpha
  corner_alpha=$(magick "$DEST/$output" -format "%[fx:p{0,0}.a]" info:)
  echo "  ✓ $output (${size}x${size}, corner_alpha:${corner_alpha})"
}

echo "Generating app icons from: $SOURCE"
echo "Output: $DEST"
echo ""

gen_icon 16   "icon_16x16.png"
gen_icon 32   "icon_16x16@2x.png"
gen_icon 32   "icon_32x32.png"
gen_icon 64   "icon_32x32@2x.png"
gen_icon 128  "icon_128x128.png"
gen_icon 256  "icon_128x128@2x.png"
gen_icon 256  "icon_256x256.png"
gen_icon 512  "icon_256x256@2x.png"
gen_icon 512  "icon_512x512.png"
gen_icon 1024 "icon_512x512@2x.png"
gen_icon 1024 "AppIcon.png"

echo ""
echo "Done. Rebuild the app in Xcode to apply the new icons."
