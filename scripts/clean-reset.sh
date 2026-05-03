#!/bin/bash
# Reset FastTranslate to fresh state for testing.
# Usage: ./scripts/clean-reset.sh

set -e

BUNDLE_ID="com.fasttranslate.app"
KEYCHAIN_SERVICE="com.fasttranslate.app"
KEYCHAIN_ACCOUNT="openai_api_key"
APP_SUPPORT=~/Library/Application\ Support/FastTranslate

echo "=== FastTranslate Clean Reset ==="

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

# Xcode DerivedData
if ls ~/Library/Developer/Xcode/DerivedData/FastTranslate-* 1>/dev/null 2>&1; then
    rm -rf ~/Library/Developer/Xcode/DerivedData/FastTranslate-*
    echo "✓ DerivedData cleared"
else
    echo "· DerivedData already clean"
fi

echo ""
echo "Done — app will show onboarding on next launch."
