#!/bin/bash

# WhisperMate iOS - fastlane Setup Script
# This script helps you set up fastlane for automated App Store submission

set -e

echo "🚀 WhisperMate iOS - fastlane Setup"
echo "===================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if fastlane is installed
if ! command -v fastlane &> /dev/null; then
    echo -e "${RED}❌ fastlane is not installed${NC}"
    echo ""
    echo "Install fastlane:"
    echo "  brew install fastlane"
    echo ""
    echo "Or:"
    echo "  sudo gem install fastlane"
    exit 1
fi

echo -e "${GREEN}✅ fastlane installed${NC}"
echo ""

# Check for .env file
if [ ! -f "fastlane/.env" ]; then
    echo -e "${YELLOW}⚠️  No .env file found${NC}"
    echo ""
    echo "Creating .env from template..."
    cp fastlane/.env.example fastlane/.env
    echo -e "${GREEN}✅ Created fastlane/.env${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Please edit fastlane/.env with your credentials${NC}"
    echo ""
    read -p "Press Enter to open .env in editor..."
    ${EDITOR:-nano} fastlane/.env
else
    echo -e "${GREEN}✅ .env file exists${NC}"
fi

echo ""
echo "📋 Checklist:"
echo ""

# Check Apple ID
if grep -q "your.email@example.com" fastlane/.env 2>/dev/null; then
    echo -e "${RED}❌ Apple ID not configured${NC}"
else
    echo -e "${GREEN}✅ Apple ID configured${NC}"
fi

# Check API Key
if grep -q "YOUR_KEY_ID" fastlane/.env 2>/dev/null; then
    echo -e "${YELLOW}⚠️  App Store Connect API key not configured (optional but recommended)${NC}"
else
    echo -e "${GREEN}✅ App Store Connect API key configured${NC}"
fi

# Check Match repository
if grep -q "yourorg/whispermate-certificates" fastlane/.env 2>/dev/null; then
    echo -e "${RED}❌ Match repository not configured${NC}"
else
    echo -e "${GREEN}✅ Match repository configured${NC}"
fi

echo ""
echo "🔧 Next Steps:"
echo ""
echo "1. Configure environment:"
echo "   Edit fastlane/.env with your Apple ID and credentials"
echo ""
echo "2. Set up code signing (Match):"
echo "   fastlane match init"
echo "   fastlane match appstore"
echo ""
echo "3. Create app in App Store Connect:"
echo "   fastlane setup"
echo ""
echo "4. Add screenshots:"
echo "   cp Screenshots/iOS/*.png fastlane/screenshots/en-US/"
echo ""
echo "5. Test build:"
echo "   fastlane build"
echo ""
echo "6. Upload to TestFlight:"
echo "   fastlane beta"
echo ""
echo "7. Submit to App Store:"
echo "   fastlane release"
echo ""
echo "For detailed documentation, see: FASTLANE_AUTOMATION.md"
echo ""
echo -e "${GREEN}✅ Setup script complete!${NC}"
