#!/bin/bash
SIMULATOR_ID="B7A48B5A-9DAC-4CE8-B946-7217A88DE2B8"
OUTPUT_DIR="Screenshots/iOS"

# Function to take screenshot
take_screenshot() {
    local name=$1
    echo "Taking screenshot: $name"
    xcrun simctl io $SIMULATOR_ID screenshot "$OUTPUT_DIR/$name"
    sleep 1
}

# Function to tap coordinates  
tap() {
    local x=$1
    local y=$2
    xcrun simctl io $SIMULATOR_ID tap $x $y
    sleep 1.5
}

# Take initial onboarding screenshot (already have 01)
echo "Capturing onboarding screens..."

# Tap "Get Started" button (approximate center-bottom)
tap 196 750

# Take microphone permission screen
take_screenshot "02-microphone-permission.png"

# Skip button or grant permission (center-bottom)
tap 196 750

sleep 2
# Take keyboard setup screen  
take_screenshot "03-keyboard-setup.png"

# Complete onboarding
tap 196 750

sleep 2
# Main screen ready to record
take_screenshot "04-main-ready.png"

echo "Screenshots captured!"
