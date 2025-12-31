# AIDictation - Voice to Text for macOS

A native macOS **AI dictation** and **voice to text** app powered by Groq's Whisper API. Convert speech to text instantly with the fastest AI-powered dictation tool for Mac.

🌐 **Website**: [aidictation.com](https://aidictation.com)

📺 **Video Overview**: [Watch on YouTube](https://www.youtube.com/watch?v=FQkePjWlDqY)

<img width="812" height="612" alt="AIDictation Screenshot" src="https://github.com/user-attachments/assets/334c3d93-d1e5-4bba-9402-d451f917457a" />

## Why AIDictation?

AIDictation is a lightweight, privacy-focused **voice to text** solution that brings AI dictation to your Mac. Unlike built-in macOS dictation, AIDictation uses state-of-the-art AI speech recognition for superior accuracy and supports LLM-powered text transformations.

## Key Features

### Fast AI Dictation
- **400-800ms voice to text** conversion using Groq's lightning-fast inference
- Native Swift/SwiftUI implementation for seamless macOS integration
- 1.35 MB app size (vs 200+ MB for Electron-based alternatives)
- Minimal CPU and memory usage

### Security & Privacy
- Open source - read the code to see exactly how your voice data is handled
- Audio is transcribed and immediately discarded, nothing is stored
- Voice data only sent to Groq API, no third-party servers
- API keys stored in macOS Keychain

### AI-Powered Text Processing
- Optional LLM transformations using Groq's AI models
- Translate between languages (e.g. speak Russian, get English text)
- Adjust tone or formality of your dictation
- Custom glossaries for domain-specific terminology

### Intuitive Voice to Text Controls
- Press and hold a hotkey (like Fn) to dictate
- Double-tap for continuous dictation mode
- Auto-paste transcribed text into any application
- Minimal overlay indicator or full window mode

### Pricing
Free during beta. You only pay for Groq API usage.

## Installation

### Option 1: Download Release (Recommended)

1. Download the latest DMG from the [Releases page](https://github.com/writingmate/whispermate/releases/latest)
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

2. **Voice to Text**:
   - **Hold-to-Dictate**: Press and hold your hotkey, release to transcribe
   - **Continuous Dictation**: Double-tap your hotkey to start, tap once to stop

3. **Modes**:
   - **Overlay Mode**: Minimal indicator in bottom-right corner
   - **Full Mode**: Expanded window with settings and transcription history

4. **Settings**:
   - Configure your Groq API key for voice to text
   - Choose between OpenAI Whisper or Groq for AI dictation
   - Customize dictation hotkey
   - Toggle auto-paste functionality

## Security & Privacy

- API keys are stored securely in macOS Keychain (never in plain text)
- Voice recordings are temporary and not persisted
- Your voice data is only sent to Groq's API for speech to text conversion

## Architecture

```
AIDictation/
├── WhisperMateApp.swift          # App entry point
├── Views/
│   └── ContentView.swift          # Main UI
├── Services/
│   ├── AudioRecorder.swift        # Voice recording with AVFoundation
│   ├── GroqAPIClient.swift        # Groq API integration (voice to text)
│   └── KeychainHelper.swift       # Secure key storage
└── Info.plist                     # App permissions
```

## Groq API - Powering Voice to Text

AIDictation uses Groq's Whisper Large V3 model for AI speech recognition:
- Fast voice to text inference (typically < 1 second)
- High accuracy speech recognition
- Cost-effective AI dictation

Get your API key: https://console.groq.com

## License

MIT
