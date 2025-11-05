# WhisperMate iOS Setup Instructions

This guide will help you add iOS targets to the existing WhisperMate Xcode project.

## Project Structure

```
Whispermate.xcodeproj
├── WhisperMateShared (Framework)     - Shared code between macOS and iOS
├── Whispermate (macOS App)           - Existing macOS app
├── WhisperMateIOS (iOS App)          - New iOS container app
└── WhisperMateKeyboard (Extension)   - New keyboard extension
```

## Step 1: Create WhisperMateShared Framework Target

1. Open `Whispermate.xcodeproj` in Xcode
2. Click **File > New > Target**
3. Select **Framework** (under iOS)
4. Name it: `WhisperMateShared`
5. Language: Swift
6. Click **Finish**

### Add Files to Framework

1. In Project Navigator, create groups:
   - `WhisperMateShared/Models`
   - `WhisperMateShared/Networking`
   - `WhisperMateShared/Services`
   - `WhisperMateShared/Storage`

2. Add existing files to the framework target:
   - Right-click each file in `WhisperMateShared` folder
   - Select **Target Membership**
   - Check `WhisperMateShared`

### Configure Framework Settings

1. Select `WhisperMateShared` target
2. **General** tab:
   - Deployment Target: **iOS 15.0**
   - Supported Destinations: **iPhone, iPad**
3. **Build Settings**:
   - Set **Defines Module** to **Yes**
   - Set **Skip Install** to **Yes**

## Step 2: Create iOS App Target

1. Click **File > New > Target**
2. Select **App** (under iOS)
3. Name it: `WhisperMateIOS`
4. Bundle Identifier: `com.whispermate.ios`
5. Language: Swift
6. Interface: SwiftUI
7. Click **Finish**

### Add iOS App Files

1. Delete the default `ContentView.swift` and `WhisperMateIOSApp.swift`
2. Add your custom files from `WhisperMateIOS` folder:
   - `WhisperMateApp.swift`
   - `OnboardingView.swift`
   - `MainView.swift`

3. Link the framework:
   - Select `WhisperMateIOS` target
   - **General** tab > **Frameworks, Libraries, and Embedded Content**
   - Click **+** and add `WhisperMateShared.framework`

### Configure iOS App Settings

1. Select `WhisperMateIOS` target
2. **General** tab:
   - Deployment Target: **iOS 15.0**
3. **Signing & Capabilities**:
   - Enable **App Groups**
   - Add group: `group.com.whispermate.shared`
4. **Info** tab:
   - Ensure `Info.plist` is set to `WhisperMateIOS/Info.plist`

## Step 3: Create Keyboard Extension Target

1. Click **File > New > Target**
2. Select **Custom Keyboard Extension** (under iOS)
3. Name it: `WhisperMateKeyboard`
4. Bundle Identifier: `com.whispermate.ios.keyboard`
5. Language: Swift
6. Click **Finish**
7. Click **Activate** when prompted

### Add Keyboard Files

1. Delete the default `KeyboardViewController.swift`
2. Add your custom `KeyboardViewController.swift`

3. Link the framework:
   - Select `WhisperMateKeyboard` target
   - **General** tab > **Frameworks, Libraries, and Embedded Content**
   - Click **+** and add `WhisperMateShared.framework`

### Configure Keyboard Extension Settings

1. Select `WhisperMateKeyboard` target
2. **General** tab:
   - Deployment Target: **iOS 15.0**
3. **Signing & Capabilities**:
   - Enable **App Groups**
   - Add group: `group.com.whispermate.shared` (same as iOS app)
4. **Info** tab:
   - Ensure `Info.plist` is set to `WhisperMateKeyboard/Info.plist`
   - Verify `RequestsOpenAccess` is set to `true`

## Step 4: Configure App Groups

App Groups are essential for sharing data between the iOS app and keyboard extension.

### iOS App Entitlements

1. Select `WhisperMateIOS` target
2. **Signing & Capabilities** tab
3. Click **+ Capability**
4. Select **App Groups**
5. Click **+** and add: `group.com.whispermate.shared`

### Keyboard Extension Entitlements

1. Select `WhisperMateKeyboard` target
2. **Signing & Capabilities** tab
3. Click **+ Capability**
4. Select **App Groups**
5. Click **+** and add: `group.com.whispermate.shared` (must match iOS app)

## Step 5: Build Settings

### All iOS Targets

For `WhisperMateShared`, `WhisperMateIOS`, and `WhisperMateKeyboard`:

1. **Build Settings** > **Swift Language Version**: Swift 5
2. **Build Settings** > **iOS Deployment Target**: 15.0

### Framework Search Paths

1. Select `WhisperMateIOS` target
2. **Build Settings** > **Framework Search Paths**
3. Add: `$(inherited)`

## Step 6: Build Order

Ensure proper build order:

1. Select Project (top level)
2. **Build Phases** > **Target Dependencies**
3. For `WhisperMateIOS`:
   - Add `WhisperMateShared` dependency
4. For `WhisperMateKeyboard`:
   - Add `WhisperMateShared` dependency

## Step 7: Code Signing

### Development

1. Select each iOS target (`WhisperMateIOS`, `WhisperMateKeyboard`)
2. **Signing & Capabilities** > **Team**: Select your development team
3. Xcode will automatically create provisioning profiles

### Distribution

For App Store distribution:

1. **Provisioning Profiles**:
   - Create App ID: `com.whispermate.ios`
   - Create App ID: `com.whispermate.ios.keyboard`
   - Enable **App Groups** capability for both
2. **Certificates**:
   - Ensure you have an iOS Distribution certificate

## Step 8: Testing

### Simulator Limitations

⚠️ **Important**: Keyboard extensions do NOT work in the iOS Simulator. You MUST test on a physical device.

### Testing on Device

1. Connect iPhone/iPad via USB
2. Select `WhisperMateIOS` scheme
3. Select your device
4. Click **Run** (⌘R)
5. After app launches:
   - Complete onboarding
   - Go to Settings > General > Keyboard > Keyboards
   - Add "WhisperMate" keyboard
   - Enable "Allow Full Access"
6. Open any app with text input (Notes, Messages, etc.)
7. Tap keyboard switcher icon
8. Select WhisperMate keyboard
9. Test voice transcription

## Troubleshooting

### "No such module 'WhisperMateShared'"

- Ensure `WhisperMateShared` framework is built first
- Check Target Dependencies
- Clean build folder (⇧⌘K) and rebuild

### "App Group container not found"

- Verify App Groups capability is enabled on BOTH targets
- Ensure group identifier is exactly the same: `group.com.whispermate.shared`
- Check provisioning profiles include App Groups entitlement

### Microphone permission not working

- Check `NSMicrophoneUsageDescription` in Info.plist
- On keyboard extension, "Allow Full Access" MUST be enabled

### Keychain items not shared

- Verify App Groups are configured correctly
- Check `kSecAttrAccessGroup` matches group identifier
- Ensure both targets use the same team/provisioning profile

## Code Reusability

Approximately **90% of code is shared** between macOS and iOS:

| Component | Reusability | Notes |
|-----------|-------------|-------|
| Models | 100% | Zero changes needed |
| Network Client | 100% | Direct reuse |
| Utilities | 100% | Platform-independent |
| Audio Recording | 85% | iOS audio session added |
| Storage | 90% | App Groups for iOS |
| Keychain | 95% | Access group for iOS |

## Architecture Highlights

### Cross-Platform Code

```swift
#if os(iOS)
// iOS-specific code
#elseif os(macOS)
// macOS-specific code
#endif
```

### Shared Data Access

- **Keychain**: Shared via App Groups
- **History**: JSON file in shared container
- **Audio Files**: Temporary files in shared container

### API Configuration

- Unified `OpenAIClient` works on both platforms
- Default endpoint: `writingmate.ai` API
- API keys stored securely in Keychain

## Next Steps

1. Test all functionality on physical device
2. Add app icon and assets
3. Configure TestFlight for beta testing
4. Submit to App Store

## Support

For issues or questions:
- Check existing macOS implementation in `Whispermate/` folder
- Review shared code in `WhisperMateShared/` folder
- Test on physical iOS device (not simulator)
