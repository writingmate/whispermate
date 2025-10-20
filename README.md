# WhisperMate

A secure, simple macOS app for voice-to-text transcription using Groq's Whisper API.

## Features

- Real-time audio recording from microphone
- Fast transcription using Groq's Whisper Large V3 model
- Secure API key storage in macOS Keychain
- Clean, native SwiftUI interface
- Minimal dependencies (AVFoundation only)

## Setup

### Prerequisites

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- Groq API key (get one at https://console.groq.com)

### Installation

1. Open Xcode
2. File → New → Project → macOS → App
3. Name: `WhisperMate`
4. Interface: SwiftUI
5. Language: Swift
6. Replace the generated files with the source files from this repository

### Project Configuration

1. In Xcode, select your project in the navigator
2. Go to "Signing & Capabilities"
3. Add your development team
4. Under "Info" tab, add the microphone permission:
   - Key: `NSMicrophoneUsageDescription`
   - Value: "WhisperMate needs access to your microphone to record audio for transcription."

### Add Info.plist

1. Right-click on your project → New File → Property List
2. Name it `Info.plist`
3. Copy the contents from the provided Info.plist file

### Running the App

1. Build and run (⌘R)
2. On first launch, enter your Groq API key
3. Grant microphone permission when prompted
4. Click "Start Recording" to begin
5. Speak clearly into your microphone
6. Click "Stop Recording" to transcribe

## Security

- API keys are stored securely in macOS Keychain (never in plain text)
- Audio files are temporary and not persisted
- No data is sent anywhere except to Groq's API

## Architecture

```
WhisperMate/
├── WhisperMateApp.swift          # App entry point
├── Views/
│   └── ContentView.swift          # Main UI
├── Services/
│   ├── AudioRecorder.swift        # Audio recording with AVFoundation
│   ├── GroqAPIClient.swift        # Groq API integration
│   └── KeychainHelper.swift       # Secure key storage
└── Info.plist                     # App permissions
```

## Groq API

This app uses Groq's Whisper Large V3 model for transcription:
- Fast inference times (typically < 1 second)
- High accuracy
- Cost-effective

Get your API key: https://console.groq.com

## License

MIT
