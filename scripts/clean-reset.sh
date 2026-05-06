#!/bin/bash
# Reset FastTranslate to fresh state for testing.
# Usage: ./scripts/clean-reset.sh
# Note: Permission reset requires sudo (tccutil) and reboot to take full effect.

set -e

BUNDLE_ID="com.fasttranslate.app"
KEYCHAIN_SERVICE="com.fasttranslate.app"
KEYCHAIN_ACCOUNT="openai_api_key"
APP_SUPPORT=~/Library/Application\ Support/FastTranslate

echo "=== FastTranslate Clean Reset ==="
echo ""

# Kill running instances
if pgrep -f "FastTranslate" > /dev/null 2>&1; then
    killall FastTranslate 2>/dev/null && echo "✓ Killed running FastTranslate" || true
else
    echo "· App not running"
fi

# Keychain
if security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" 2>/dev/null; then
    echo "✓ Keychain API key deleted"
else
    echo "· Keychain already clean"
fi

# UserDefaults
if defaults delete "$BUNDLE_ID" 2>/dev/null; then
    echo "✓ UserDefaults cleared"
else
    echo "· UserDefaults already clean"
fi

# Translation history
if [ -f "$APP_SUPPORT/history.json" ]; then
    rm -f "$APP_SUPPORT/history.json"
    echo "✓ History deleted"
else
    echo "· History already clean"
fi

# macOS permissions (Accessibility + Screen Recording)
# tccutil resets the TCC database entries for this bundle ID
echo ""
echo "--- Resetting macOS Permissions ---"
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null && echo "✓ Accessibility permission reset" || echo "· Accessibility reset skipped"
tccutil reset ScreenCapture "$BUNDLE_ID" 2>/dev/null && echo "✓ Screen Recording permission reset" || echo "· Screen Recording reset skipped"

# Also reset for Xcode debug builds (often registered under Xcode's signature)
tccutil reset Accessibility com.apple.dt.Xcode 2>/dev/null && echo "✓ Xcode Accessibility reset" || true
tccutil reset ScreenCapture com.apple.dt.Xcode 2>/dev/null && echo "✓ Xcode Screen Recording reset" || true

# Xcode DerivedData
echo ""
echo "--- Clearing Build Cache ---"
if ls ~/Library/Developer/Xcode/DerivedData/FastTranslate-* 1>/dev/null 2>&1; then
    rm -rf ~/Library/Developer/Xcode/DerivedData/FastTranslate-*
    echo "✓ DerivedData cleared"
else
    echo "· DerivedData already clean"
fi

# Launch Services (reset app registration cache)
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -kill -r -domain local -domain system -domain user 2>/dev/null && echo "✓ Launch Services cache rebuilt" || true

echo ""
echo "=== Done ==="
echo ""
echo "IMPORTANT next steps:"
echo "  1. Open System Settings > Privacy & Security > Accessibility"
echo "     → Remove any old FastTranslate entries manually if they remain"
echo "  2. Same for Screen Recording"
echo "  3. Clean Build in Xcode (Cmd+Shift+K) then Build (Cmd+B)"
echo "  4. On first run, macOS will prompt for permissions again"
echo ""
echo "If permissions still stick, reboot your Mac — macOS caches TCC decisions aggressively."
