#!/bin/bash

echo "Current Bundle IDs:"
echo "  iOS App: com.whispermate.ios"
echo "  Keyboard: com.whispermate.ios.keyboard"
echo ""
read -p "Enter new base bundle ID (e.g., com.yourname.whispermate): " NEW_BUNDLE_ID

if [ -z "$NEW_BUNDLE_ID" ]; then
    echo "❌ No bundle ID provided. Exiting."
    exit 1
fi

APP_BUNDLE_ID="$NEW_BUNDLE_ID"
KEYBOARD_BUNDLE_ID="${NEW_BUNDLE_ID}.keyboard"

echo ""
echo "New Bundle IDs will be:"
echo "  iOS App: $APP_BUNDLE_ID"
echo "  Keyboard: $KEYBOARD_BUNDLE_ID"
echo ""
read -p "Proceed? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo "Cancelled."
    exit 0
fi

# Update using PlistBuddy
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_BUNDLE_ID" WhisperMateIOS/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $KEYBOARD_BUNDLE_ID" WhisperMateKeyboard/Info.plist

# Update entitlements - change app group to match bundle ID
APP_GROUP="group.${NEW_BUNDLE_ID}.shared"

/usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 $APP_GROUP" WhisperMateIOS/WhisperMateIOS.entitlements 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :com.apple.security.application-groups:0 string $APP_GROUP" WhisperMateIOS/WhisperMateIOS.entitlements

/usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 $APP_GROUP" WhisperMateKeyboard/WhisperMateKeyboard.entitlements 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :com.apple.security.application-groups:0 string $APP_GROUP" WhisperMateKeyboard/WhisperMateKeyboard.entitlements

echo ""
echo "✅ Bundle IDs updated!"
echo "✅ App Group updated to: $APP_GROUP"
echo ""
echo "⚠️  IMPORTANT: Update the following in your code:"
echo "  1. In AudioRecorder.swift, change:"
echo "     static let appGroupIdentifier = \"$APP_GROUP\""
echo ""
echo "  2. In HistoryManager.swift, change:"
echo "     static let appGroupIdentifier = \"$APP_GROUP\""
echo ""
echo "  3. In KeychainHelper.swift, change:"
echo "     private static let accessGroup = \"$APP_GROUP\""
echo ""
echo "  4. Rebuild the project in Xcode"

