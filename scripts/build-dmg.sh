#!/bin/bash
# Build Release app and package a branded DMG with volume icon, background, and Finder layout.
# Usage: ./scripts/build-dmg.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/HotLingo.xcodeproj"
SCHEME="HotLingo"
DERIVED="$ROOT/build/DerivedData"
PRODUCTS="$DERIVED/Build/Products/Release"
APP="$PRODUCTS/HotLingo.app"
DIST="$ROOT/build/dist"
STAGE="$DIST/dmg-staging"
RW_DMG="$DIST/HotLingo-rw.dmg"
DMG="$DIST/HotLingo.dmg"
VOLNAME="HotLingo"
BG_DIR="$STAGE/.background"
BG_PNG="$BG_DIR/background.png"
APP_ICON="$APP/Contents/Resources/AppIcon.icns"

mkdir -p "$DIST"

echo "==> Building Release app"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  build

echo "==> Preparing DMG staging"
rm -rf "$STAGE" "$RW_DMG" "$DMG"
mkdir -p "$BG_DIR"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
find "$STAGE" -name "._*" -delete
cp "$APP_ICON" "$STAGE/.VolumeIcon.icns"

python3 - <<'PY' "$BG_PNG"
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

out = Path(sys.argv[1])
w, h = 760, 460
img = Image.new('RGBA', (w, h), (246, 247, 248, 255))
px = img.load()
for y in range(h):
    for x in range(w):
        t = (x / w) * 0.35 + (y / h) * 0.65
        r = int(252 * (1 - t) + 224 * t)
        g = int(253 * (1 - t) + 231 * t)
        b = int(253 * (1 - t) + 236 * t)
        px[x, y] = (r, g, b, 255)

# Soft neutral background, no app logo. Keep it calm so Finder icons stay readable.
layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
d = ImageDraw.Draw(layer, 'RGBA')
d.ellipse((-180, -150, 360, 320), fill=(255, 255, 255, 120))
d.ellipse((410, -90, 880, 300), fill=(188, 205, 214, 58))
d.ellipse((260, 220, 850, 610), fill=(255, 255, 255, 96))
d.rounded_rectangle((70, 74, 690, 386), radius=36, fill=(255, 255, 255, 82), outline=(255, 255, 255, 118), width=1)
img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(34)))

noise = Image.new('RGBA', (w, h), (0, 0, 0, 0))
nd = ImageDraw.Draw(noise, 'RGBA')
for yy in range(0, h, 8):
    for xx in range(0, w, 8):
        alpha = 5 if (xx + yy) % 16 == 0 else 2
        nd.point((xx, yy), fill=(120, 130, 135, alpha))
img.alpha_composite(noise)

d = ImageDraw.Draw(img)
font_paths = ['/System/Library/Fonts/HelveticaNeue.ttc', '/System/Library/Fonts/Supplemental/Arial Bold.ttf']
def font(size):
    for p in font_paths:
        try:
            return ImageFont.truetype(p, size=size)
        except Exception:
            pass
    return ImageFont.load_default()

# Header text only, intentionally no logo.
d.text((66, 56), 'HotLingo', font=font(36), fill=(27, 33, 37, 255))
d.text((68, 102), 'Drag HotLingo into Applications to install', font=font(17), fill=(86, 94, 100, 225))

# Install direction arrow sits between Finder icons.
d.line((312, 260, 452, 260), fill=(32, 123, 255, 210), width=8)
d.polygon([(458, 260), (426, 239), (426, 281)], fill=(32, 123, 255, 210))


out.parent.mkdir(parents=True, exist_ok=True)
img.convert('RGB').save(out, quality=95)
PY

echo "==> Creating writable DMG"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -ov -format UDRW "$RW_DMG" >/dev/null

cleanup() {
  [ -n "${MOUNT_DIR:-}" ] && hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Mounting and applying Finder layout"
# Let hdiutil pick the mountpoint to avoid /Volumes permission issues
MOUNT_DIR=$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen | awk 'END{$1=$2=""; print substr($0,3)}')
# Trim leading/trailing whitespace
MOUNT_DIR="${MOUNT_DIR#"${MOUNT_DIR%%[![:space:]]*}"}"
MOUNT_DIR="${MOUNT_DIR%"${MOUNT_DIR##*[![:space:]]}"}"
# Derive actual disk name from mount path (e.g. /Volumes/HotLingo 1 → HotLingo 1)
DISK_NAME="${MOUNT_DIR#/Volumes/}"
echo "    Mounted at: $MOUNT_DIR (disk: $DISK_NAME)"

# Custom mounted-volume icon shown on the Desktop/Finder sidebar while the DMG is mounted.
if command -v SetFile >/dev/null 2>&1; then
  SetFile -a C "$MOUNT_DIR"
  SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns"
fi

# Finder layout requires Finder/AppleScript. If it fails, the DMG still builds.
osascript <<OSA || true
tell application "Finder"
  tell disk "$DISK_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {120, 120, 880, 580}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "HotLingo.app" of container window to {225, 263}
    set position of item "Applications" of container window to {545, 263}
    close
    open
    update without registering applications
  end tell
end tell
OSA

sync
hdiutil detach "$MOUNT_DIR" -quiet
trap - EXIT
echo "==> Compressing final DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" -quiet
rm -f "$RW_DMG"

echo "==> Applying Finder icon to DMG file"
if command -v sips >/dev/null 2>&1 && command -v DeRez >/dev/null 2>&1 && command -v Rez >/dev/null 2>&1 && command -v SetFile >/dev/null 2>&1; then
  DMG_ICON_PNG="$DIST/HotLingo-dmg-icon.png"
  DMG_ICON_RSRC="$DIST/HotLingo-dmg-icon.rsrc"
  cp "$ROOT/HotLingo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" "$DMG_ICON_PNG"
  sips -i "$DMG_ICON_PNG" >/dev/null
  DeRez -only icns "$DMG_ICON_PNG" > "$DMG_ICON_RSRC"
  Rez -append "$DMG_ICON_RSRC" -o "$DMG"
  SetFile -a C "$DMG"
  rm -f "$DMG_ICON_PNG" "$DMG_ICON_RSRC"
else
  echo "    Skipping DMG file icon: required macOS developer tools are unavailable."
fi

ls -lh "$DMG"

# Create versioned .zip of the signed app for auto-update (UpdateService expects a .zip asset in GitHub Releases)
APP_VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
ZIP="$DIST/HotLingo-${APP_VERSION}.zip"
echo "==> Creating update ZIP: $ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
ls -lh "$ZIP"

echo "Done: $DMG | $ZIP"
