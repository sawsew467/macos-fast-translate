#!/bin/bash
# Remove HotLingo installed from DMG and clear local app data.

set -euo pipefail

APP_NAME="HotLingo"
BUNDLE_ID="com.hotlingo.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# Stop the app if it is running.
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

# Remove installed apps and common app data locations.
# Containers is SIP-protected; remove what we can and skip the rest.
for target in \
  "/Applications/$APP_NAME.app" \
  "$HOME/Applications/$APP_NAME.app" \
  "$HOME/Library/Application Support/$APP_NAME" \
  "$HOME/Library/Caches/$APP_NAME" \
  "$HOME/Library/Logs/$APP_NAME" \
  "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState" \
  "$HOME/Library/Containers/$BUNDLE_ID" \
  "$HOME/Library/Group Containers/$BUNDLE_ID" \
  "$HOME/Library/WebKit/$BUNDLE_ID" \
  "$HOME/Library/HTTPStorages/$BUNDLE_ID" \
  "$HOME/Library/Caches/$BUNDLE_ID" \
  "$HOME/Library/Preferences/$BUNDLE_ID.plist"
do
  rm -rf "$target" 2>/dev/null || echo "  skipped (protected): $target"
done

# Clear cached preferences and LaunchServices registration.
defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
killall cfprefsd >/dev/null 2>&1 || true

if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "/Applications/$APP_NAME.app" >/dev/null 2>&1 || true
  "$LSREGISTER" -u "$HOME/Applications/$APP_NAME.app" >/dev/null 2>&1 || true
fi

# Report any obvious leftovers in common Library folders.
echo "HotLingo uninstall cleanup completed. Checking common leftovers..."
find \
  "$HOME/Library/Application Support" \
  "$HOME/Library/Caches" \
  "$HOME/Library/Preferences" \
  "$HOME/Library/Saved Application State" \
  -maxdepth 2 \( -iname "*$APP_NAME*" -o -iname "*$BUNDLE_ID*" \) -print 2>/dev/null || true
