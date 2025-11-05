# WhisperMate iOS - App Store Screenshot Guide

## Current Screenshots Captured

Located in: `Screenshots/iOS/`

1. **01-onboarding.png** (1320x2868) - Welcome screen with app features
   - Shows: Welcome message, key features (Speak naturally, Fast transcription, Secure & private)
   - Status: ✅ Ready for App Store

## Required Screenshots for App Store Submission

### iPhone 6.7" Display (Required - Primary)
**Device**: iPhone 17 Pro Max (1320x2868 pixels)

#### Recommended Screenshot Set (5-10 screenshots):

1. **Welcome/Onboarding** ✅ CAPTURED
   - Current: 01-onboarding.png
   - Shows app's core value proposition

2. **Recording in Progress** 🔴 NEEDED
   - Show the main recording interface with audio visualization
   - Microphone button pressed, waveform animation visible
   - Status text: "Recording..."

3. **Transcription Result** 📝 NEEDED
   - Show completed transcription in the text area
   - Include copy and share buttons visible
   - Sample text displayed

4. **Keyboard Extension** ⌨️ NEEDED
   - Show WhisperMate keyboard activated in Messages/Notes app
   - Microphone button on keyboard
   - Demonstrates the keyboard extension feature

5. **Share Menu** 🔗 NEEDED
   - Show the share dropdown menu
   - Display options: Writingmate, Claude, ChatGPT, Perplexity, etc.

6. **Text Rules** ⚙️ NEEDED (Optional)
   - Show the text formatting rules screen
   - Custom rules for text processing

### Additional Device Sizes (Optional but Recommended)

#### iPhone 6.5" Display
**Device**: iPhone 15 Pro Max, iPhone 14 Pro Max
**Resolution**: 1284x2778 pixels

#### iPhone 5.5" Display
**Device**: iPhone 8 Plus
**Resolution**: 1242x2208 pixels

#### iPad Pro 12.9" Display
**Device**: iPad Pro 12.9"
**Resolution**: 2048x2732 pixels

## How to Capture Missing Screenshots

### Manual Method (Recommended):

1. **Open Simulator**:
   ```bash
   open -a Simulator
   # Select iPhone 17 Pro Max from device menu
   ```

2. **Install and Launch App**:
   ```bash
   xcrun simctl install booted path/to/WhisperMateIOS.app
   xcrun simctl launch booted com.whispermate.ios
   ```

3. **Navigate to Each Screen**:
   - Tap through the onboarding flow
   - Grant microphone permissions
   - Record sample audio
   - Access different screens

4. **Take Screenshots**:
   - In Simulator: `Cmd + S` (saves to Desktop)
   - Or via command line:
     ```bash
     xcrun simctl io booted screenshot screenshot-name.png
     ```

### Automated Method (Using UI Tests):

Create UI test cases that:
1. Navigate through each screen
2. Capture screenshots at each step
3. Save to designated folder

## Screenshot Best Practices

### Content Guidelines:
- **Show Real Content**: Use actual transcriptions, not lorem ipsum
- **Localized**: Ensure text is in English (or add localizations)
- **No Personal Info**: Don't include sensitive data
- **High Quality**: Use highest resolution device
- **Status Bar**: Clean status bar (full battery, strong signal, 9:41 AM)

### Visual Guidelines:
- **Consistent Theme**: Keep light/dark mode consistent across all screenshots
- **Clear Focus**: Each screenshot should highlight one key feature
- **Text Readable**: Ensure all text is legible
- **Proper Framing**: Center UI elements appropriately

## Current Status

### Captured Screenshots:
- ✅ Welcome/Onboarding (1x)

### Needed Screenshots:
- 🔴 Recording Interface
- 📝 Transcription Result
- ⌨️ Keyboard Extension
- 🔗 Share Menu
- ⚙️ Settings/Rules (Optional)

### Total Screenshots Required:
- **Minimum**: 3 screenshots (Welcome, Recording, Result)
- **Recommended**: 5-6 screenshots
- **Maximum**: 10 screenshots per device size

## Device Requirements Summary

| Device | Resolution | Status | Priority |
|--------|------------|--------|----------|
| iPhone 6.7" (17 Pro Max) | 1320x2868 | 1/5 | **Required** |
| iPhone 6.5" (15 Pro Max) | 1284x2778 | 0/5 | Optional |
| iPhone 5.5" (8 Plus) | 1242x2208 | 0/5 | Optional |
| iPad Pro 12.9" | 2048x2732 | 0/5 | Optional |

## Next Steps

1. **Launch the app in Simulator** with iPhone 17 Pro Max
2. **Manually capture screenshots** of:
   - Recording screen (press record button)
   - Transcription result (after recording)
   - Keyboard extension (open in Messages app)
   - Share menu (tap share button)
3. **Save screenshots** to `Screenshots/iOS/` with descriptive names
4. **Review and optimize** screenshots for App Store compliance
5. **Add captions** (optional but recommended) for each screenshot in App Store Connect

## App Store Connect Upload

When ready to upload:
1. Log in to App Store Connect
2. Go to your app → App Store → Media Manager
3. Upload screenshots for each device size
4. Add localized captions describing each screenshot
5. Preview how they appear in the App Store listing

---

**Note**: Screenshots must be uploaded before submitting the app for review. Plan to capture all required screenshots during the testing phase.
