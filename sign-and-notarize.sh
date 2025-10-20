#!/bin/bash

# WhisperMate Code Signing and Notarization Script
# Prerequisites:
# 1. Apple Developer Program membership
# 2. Developer ID Application certificate installed in Keychain
# 3. App-specific password for notarization

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== WhisperMate Signing and Notarization ===${NC}\n"

# Configuration
APP_NAME="Whishpermate"
BUNDLE_ID="com.whispermate.Whishpermate"
BUILD_DIR="build/Build/Products/Release"
DMG_NAME="WhisperMate-signed.dmg"

# Step 1: Check for Developer ID certificate
echo -e "${YELLOW}Step 1: Checking for Developer ID certificate...${NC}"
CERT_NAME=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | sed -n 's/.*"\(.*\)"/\1/p')

if [ -z "$CERT_NAME" ]; then
    echo -e "${RED}Error: No Developer ID Application certificate found!${NC}"
    echo "Please install your Developer ID Application certificate from developer.apple.com"
    exit 1
fi

echo -e "${GREEN}✓ Found certificate: $CERT_NAME${NC}\n"

# Step 2: Build the app
echo -e "${YELLOW}Step 2: Building app in Release mode...${NC}"
cd Whishpermate
xcodebuild -project Whishpermate.xcodeproj \
    -scheme Whishpermate \
    -configuration Release \
    -derivedDataPath ../build \
    clean build \
    CODE_SIGN_IDENTITY="$CERT_NAME" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

cd ..
echo -e "${GREEN}✓ Build complete${NC}\n"

# Step 3: Sign the app bundle
echo -e "${YELLOW}Step 3: Signing app bundle...${NC}"
codesign --force --deep --sign "$CERT_NAME" \
    --options runtime \
    --entitlements Whishpermate/Whishpermate/Whishpermate.entitlements \
    --timestamp \
    "$BUILD_DIR/$APP_NAME.app"

echo -e "${GREEN}✓ App signed successfully${NC}\n"

# Step 4: Verify signature
echo -e "${YELLOW}Step 4: Verifying signature...${NC}"
codesign --verify --deep --strict --verbose=2 "$BUILD_DIR/$APP_NAME.app"
spctl --assess --type execute --verbose=4 "$BUILD_DIR/$APP_NAME.app"
echo -e "${GREEN}✓ Signature verified${NC}\n"

# Step 5: Create DMG
echo -e "${YELLOW}Step 5: Creating DMG...${NC}"
rm -f "$DMG_NAME"
hdiutil create -volname "WhisperMate" \
    -srcfolder "$BUILD_DIR/$APP_NAME.app" \
    -ov -format UDZO \
    "$DMG_NAME"
echo -e "${GREEN}✓ DMG created: $DMG_NAME${NC}\n"

# Step 6: Sign DMG
echo -e "${YELLOW}Step 6: Signing DMG...${NC}"
codesign --force --sign "$CERT_NAME" --timestamp "$DMG_NAME"
echo -e "${GREEN}✓ DMG signed${NC}\n"

# Step 7: Notarize (requires credentials)
echo -e "${YELLOW}Step 7: Notarizing with Apple...${NC}"
echo "For notarization, you need:"
echo "  1. Your Apple ID email"
echo "  2. An app-specific password (create at appleid.apple.com)"
echo "  3. Your Team ID (found at developer.apple.com/account)"
echo ""
read -p "Do you want to notarize now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Apple ID: " APPLE_ID
    read -p "Team ID: " TEAM_ID
    read -sp "App-specific password: " APP_PASSWORD
    echo ""

    echo "Uploading for notarization (this may take several minutes)..."
    xcrun notarytool submit "$DMG_NAME" \
        --apple-id "$APPLE_ID" \
        --password "$APP_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait

    echo -e "${GREEN}✓ Notarization complete${NC}\n"

    # Step 8: Staple notarization ticket
    echo -e "${YELLOW}Step 8: Stapling notarization ticket...${NC}"
    xcrun stapler staple "$DMG_NAME"
    echo -e "${GREEN}✓ Notarization ticket stapled${NC}\n"

    # Step 9: Verify notarization
    echo -e "${YELLOW}Step 9: Verifying notarization...${NC}"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_NAME"
    echo -e "${GREEN}✓ DMG is properly signed and notarized!${NC}\n"
else
    echo -e "${YELLOW}Skipping notarization. DMG is signed but not notarized.${NC}"
    echo -e "${YELLOW}Users will still see a security warning.${NC}\n"
fi

echo -e "${GREEN}=== Complete! ===${NC}"
echo "Signed DMG: $DMG_NAME"
echo "Size: $(ls -lh "$DMG_NAME" | awk '{print $5}')"
