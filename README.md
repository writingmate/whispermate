# WhisperMate

A blazing-fast, secure, and native macOS voice-to-text app powered by Groq's Whisper API.

## Why WhisperMate?

### 🔒 Security & Open Source by Design
- **100% Transparent**: Read the code to see exactly how your data is handled
- **Zero Storage**: Nothing is stored locally or remotely - audio is transcribed and immediately discarded
- **Direct API**: Data only sent to Groq API, no third-party servers
- **Keychain Security**: API keys stored in macOS Keychain, never in plain text

### ⚡ Extremely Fast
- **400-800ms Response Times**: Powered by Groq's high-performance inference
- **Real-time Transcription**: Near-instant results using Whisper Large V3 Turbo
- **Optimized Pipeline**: Direct audio-to-text with minimal overhead
- **Try It Yourself**: Experience the speed difference immediately

### 🤖 LLM Post-Processing
- **Smart Transformations**: Configure how transcriptions are processed
- **Multi-Language Support**: Speak in Russian, transcribe to English instantly
- **Tone Adjustment**: Change casual speech to formal text automatically
- **Custom Glossaries**: Define industry-specific terms and corrections
- **Powered by Groq's LLMs**: Lightning-fast post-processing with llama models

### ⌨️ Push-to-Talk Hotkey
- **Hold to Record**: Press and hold Fn (or any key) while dictating
- **Instant Activation**: No need to click buttons or switch windows
- **Continuous Mode**: Double-tap for hands-free extended recording
- **Auto-Paste**: Transcription appears instantly in your active app

### 🪶 Tiny & Native
- **1.35 MB Size**: Comparing to 200+ MB Electron-based alternatives (Whisper Flow, etc.)
- **Minimal Resource Use**: Native macOS SDK - no Chrome/Electron overhead
- **Swift + SwiftUI**: Built with Apple's modern frameworks
- **Efficient**: Barely uses any CPU or memory when idle

### 💰 Free While in Beta
- **No Subscription**: Completely free during beta period
- **Pay for API Only**: You only pay for your Groq API usage (extremely affordable)
- **No Hidden Costs**: Open source, transparent pricing

## Features

- **Hotkey-Driven Recording**: Press and hold your hotkey to record, or double-tap for continuous recording
- **Live Audio Visualization**: Real-time waveform display during recording
- **Smart Overlay Mode**: Minimal recording indicator that stays out of your way
- **Fast Transcription**: Uses Groq's Whisper Large V3 model for near-instant results
- **Auto-Paste**: Transcriptions automatically pasted into your active app
- **Secure Storage**: API keys stored safely in macOS Keychain
- **Native UI**: Clean SwiftUI interface with dark mode support
- **Guided Onboarding**: First-time setup wizard for permissions and hotkey configuration

## Installation

### Option 1: Download Release (Recommended)

1. Download the latest `WhisperMate-v0.0.4.dmg` from the [Releases page](https://github.com/writingmate/whispermate/releases/latest)
2. Open the DMG file
3. Drag Whispermate to your Applications folder
4. Launch Whispermate from Applications
5. Follow the onboarding wizard to:
   - Grant microphone permission
   - Grant accessibility permission (for auto-paste)
   - Configure your recording hotkey

### Option 2: Build from Source

#### Prerequisites

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- Groq API key (get one at https://console.groq.com)

#### Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/writingmate/whispermate.git
   cd whispermate/Whishpermate
   ```

2. Open the project:
   ```bash
   open Whispermate.xcodeproj
   ```

3. Build and run (⌘R)

4. Follow the onboarding wizard on first launch

## Getting Started

1. **First Launch**: Complete the onboarding wizard
   - Enable microphone access
   - Enable accessibility permissions (needed for auto-paste)
   - Set your recording hotkey (Fn key recommended)

2. **Recording**:
   - **Hold-to-Record**: Press and hold your hotkey, release to transcribe
   - **Continuous Recording**: Double-tap your hotkey to start, tap once to stop

3. **Modes**:
   - **Overlay Mode**: Minimal indicator in bottom-right corner
   - **Full Mode**: Expanded window with settings and transcription history

4. **Settings**:
   - Configure your Groq API key
   - Choose between OpenAI Whisper or Groq transcription
   - Customize hotkey
   - Toggle auto-paste functionality

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
