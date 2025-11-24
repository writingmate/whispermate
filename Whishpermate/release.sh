#!/bin/bash
# release.sh - Automated WhisperMate release script
# Usage: ./release.sh [version]
# Example: ./release.sh 0.0.26

set -e

echo "🚀 WhisperMate Release Script"
echo "=============================="

# 1. Get version number
if [ -z "$1" ]; then
    CURRENT_VERSION=$(grep -m 1 'MARKETING_VERSION = ' Whispermate.xcodeproj/project.pbxproj | sed 's/.*= \(.*\);/\1/' | tr -d ' ')
    echo "Current version: $CURRENT_VERSION"
    read -p "Enter new version (e.g., 0.0.26): " NEW_VERSION
else
    NEW_VERSION=$1
fi

echo ""
echo "📝 Version: $NEW_VERSION"
echo ""

# 2. Bump version in project file
echo "⬆️  Bumping version to $NEW_VERSION..."
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $NEW_VERSION;/g" Whispermate.xcodeproj/project.pbxproj

# 3. Commit all changes
echo "💾 Committing all changes..."
git add -A
git commit -m "Release v$NEW_VERSION"

# 4. Build with proper distribution signing
echo "🔨 Building Release configuration..."
xcodebuild -scheme Whispermate \
  -configuration Release \
  -derivedDataPath build \
  clean build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM=G7DJ6P37KU \
  PROVISIONING_PROFILE_SPECIFIER="" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"

# 5. Create distribution package
echo "📦 Creating distribution package..."
APP_PATH="build/Build/Products/Release/Whispermate.app"
DMG_PATH="Whispermate-v$NEW_VERSION.dmg"
ZIP_PATH="Whispermate-v$NEW_VERSION.zip"
NOTARIZE_PATH=""

# Try to create DMG first
echo "Attempting to create DMG..."
if command -v create-dmg &> /dev/null; then
    # Use create-dmg if available
    create-dmg \
      --volname "Whispermate" \
      --window-pos 200 120 \
      --window-size 600 400 \
      --icon-size 100 \
      --app-drop-link 425 120 \
      --hide-extension "Whispermate.app" \
      "$DMG_PATH" \
      "$APP_PATH" 2>/dev/null

    if [ $? -eq 0 ]; then
        NOTARIZE_PATH="$DMG_PATH"
        echo "✅ DMG created with create-dmg"
    fi
else
    # Try hdiutil (may fail due to permissions)
    TEMP_DIR=$(mktemp -d)
    cp -R "$APP_PATH" "$TEMP_DIR/"
    hdiutil create -volname "Whispermate" -srcfolder "$TEMP_DIR" -ov -format UDZO "$DMG_PATH" 2>/dev/null
    rm -rf "$TEMP_DIR"

    if [ $? -eq 0 ]; then
        NOTARIZE_PATH="$DMG_PATH"
        echo "✅ DMG created with hdiutil"
    fi
fi

# If DMG creation failed, fall back to ZIP
if [ -z "$NOTARIZE_PATH" ]; then
    echo "⚠️  DMG creation failed (permissions issue), using ZIP instead..."
    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
    NOTARIZE_PATH="$ZIP_PATH"
    echo "✅ ZIP created: $ZIP_PATH"
fi

# 6. Sign the package if it's a DMG
if [ "$NOTARIZE_PATH" = "$DMG_PATH" ] && [ -f "$DMG_PATH" ]; then
    echo "🔏 Signing DMG..."
    codesign --sign "Developer ID Application" \
      --timestamp \
      "$DMG_PATH"

    if [ $? -ne 0 ]; then
        echo "⚠️  DMG signing failed, continuing with notarization..."
    else
        echo "✅ DMG signed"
    fi
fi

# 7. Notarize the package
echo "📮 Submitting for notarization: $NOTARIZE_PATH..."
xcrun notarytool submit "$NOTARIZE_PATH" \
  --keychain-profile "notarytool-password" \
  --wait

if [ $? -ne 0 ]; then
    echo "❌ Notarization failed!"
    echo "Check notarization log with: xcrun notarytool log <submission-id> --keychain-profile notarytool-password"
    exit 1
fi

echo "✅ Notarization successful!"

# 8. Staple notarization ticket (only works for DMG and APP)
if [ "$NOTARIZE_PATH" = "$DMG_PATH" ]; then
    echo "🎫 Stapling notarization ticket to DMG..."
    xcrun stapler staple "$DMG_PATH"
    if [ $? -ne 0 ]; then
        echo "⚠️  Stapling failed (not critical)"
    else
        echo "✅ DMG stapled"
    fi
else
    echo "🎫 Stapling notarization ticket to app..."
    xcrun stapler staple "$APP_PATH"
    if [ $? -ne 0 ]; then
        echo "⚠️  Stapling failed (not critical)"
    else
        echo "✅ App stapled"
        # Recreate ZIP with stapled app
        rm -f "$ZIP_PATH"
        ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
        echo "✅ ZIP recreated with stapled app"
    fi
fi

# 9. Create notarized app zip for distribution (if we made a DMG)
if [ "$NOTARIZE_PATH" = "$DMG_PATH" ]; then
    echo "📦 Creating notarized app archive..."
    NOTARIZED_APP="Whispermate-v$NEW_VERSION-app.zip"
    ditto -c -k --keepParent "$APP_PATH" "$NOTARIZED_APP"
    echo "✅ App archive created: $NOTARIZED_APP"
fi

# 10. Push to GitHub
echo "📤 Pushing to GitHub..."
git push origin main

# 11. Create git tag
echo "🏷️  Creating git tag..."
git tag "v$NEW_VERSION"
git push origin "v$NEW_VERSION"

# 12. Create GitHub release
echo "🎉 Creating GitHub release..."
RELEASE_FILES=()
if [ "$NOTARIZE_PATH" = "$DMG_PATH" ] && [ -f "$DMG_PATH" ]; then
    RELEASE_FILES+=("$DMG_PATH")
fi
if [ -f "$ZIP_PATH" ]; then
    RELEASE_FILES+=("$ZIP_PATH")
fi
if [ -f "$NOTARIZED_APP" ]; then
    RELEASE_FILES+=("$NOTARIZED_APP")
fi

if command -v gh &> /dev/null; then
    gh release create "v$NEW_VERSION" \
      "${RELEASE_FILES[@]}" \
      --title "v$NEW_VERSION" \
      --generate-notes

    if [ $? -eq 0 ]; then
        echo "✅ GitHub release created!"
    else
        echo "⚠️  GitHub release creation failed. Create it manually at:"
        echo "   https://github.com/$(git config --get remote.origin.url | sed 's/.*:\(.*\)\.git/\1/')/releases/new?tag=v$NEW_VERSION"
    fi
else
    echo "⚠️  gh CLI not installed. Create release manually at:"
    echo "   https://github.com/$(git config --get remote.origin.url | sed 's/.*:\(.*\)\.git/\1/')/releases/new?tag=v$NEW_VERSION"
    echo "   Upload files: ${RELEASE_FILES[@]}"
fi

echo ""
echo "✨ Release v$NEW_VERSION complete!"
echo ""
if [ -f "$DMG_PATH" ]; then
    echo "📦 DMG: $DMG_PATH"
fi
if [ -f "$ZIP_PATH" ]; then
    echo "📦 ZIP: $ZIP_PATH"
fi
if [ -f "$NOTARIZED_APP" ]; then
    echo "📦 App Archive: $NOTARIZED_APP"
fi
echo ""
