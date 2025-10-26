# 🎙️ WhisperMate (Voice2Text)

Fast, private voice-to-text transcription for macOS using Groq, OpenAI, or any OpenAI-compatible API.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Security](https://img.shields.io/badge/security-OWASP%20Mobile%20Top%2010-brightgreen.svg)

## ✨ Features

- **🎯 Global Hotkey** - Record with Fn key from any app
- **⚡ Fast Transcription** - Powered by Whisper models via Groq/OpenAI
- **🔒 Privacy First** - All data stays local, you control the API providers
- **✏️ Smart Formatting** - AI-powered text correction with custom rules
- **📝 History** - Keep track of your recent transcriptions
- **🌍 Multi-Language** - Support for 50+ languages
- **🔧 Customizable** - Configure your own API endpoints and models

## 🔐 Security

WhisperMate follows industry-standard security practices:

- ✅ **OWASP Mobile Top 10 2024** compliant
- ✅ Code signed and notarized by Apple
- ✅ Hardened runtime enabled
- ✅ API keys stored in macOS Keychain
- ✅ No telemetry or analytics
- ✅ Zero sensitive data logging in production builds

**Security Score: 85/100**

For detailed security information, see [SECURITY.md](SECURITY.md)

## 📥 Download

**Latest Release: [v0.0.7](https://github.com/writingmate/whispermate/releases/latest)**

### Requirements
- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3) or Intel Mac
- Microphone permission
- Accessibility permission (for global hotkey)

## 🚀 Quick Start

1. **Download** the latest DMG from [Releases](https://github.com/writingmate/whispermate/releases)
2. **Open** the DMG and drag WhisperMate to Applications
3. **Launch** WhisperMate
4. **Complete** the onboarding:
   - Grant microphone permission
   - Grant accessibility permission
   - Set up global hotkey (default: Fn key)
   - Configure prompt rules (optional)
5. **Add API Key** in Settings:
   - Get a free API key from [Groq](https://console.groq.com) or [OpenAI](https://platform.openai.com)
   - Paste it in Settings → Audio or Settings → Rules

## 💡 Usage

### Basic Recording
1. Press and hold **Fn** key (or your custom hotkey)
2. Speak your message
3. Release to transcribe
4. Text automatically pastes to your active app (optional)

### Custom Rules
Add formatting rules to improve transcription quality:
- "Use proper punctuation"
- "Capitalize proper nouns"
- "Format as bullet points"
- "Use British English spelling"

## ⚙️ Settings

### Audio Provider
- **Groq** (recommended) - Fast and free
- **OpenAI** - High quality
- **Custom** - Use any OpenAI-compatible endpoint

### LLM Provider (for formatting)
- Configure the AI model for text correction
- Enable/disable custom formatting rules

### Hotkeys
- Customize your global hotkey
- Currently supports Fn key and modifier combinations

## 🏗️ Architecture

```
┌─────────────────────────────────────┐
│         WhisperMate App             │
├─────────────────────────────────────┤
│                                     │
│  ┌──────────────┐  ┌─────────────┐ │
│  │ Audio        │  │ Transcription│ │
│  │ Recorder     │──▶│ Service     │ │
│  └──────────────┘  └─────────────┘ │
│         │                 │         │
│         │                 ▼         │
│         │         ┌─────────────┐   │
│         │         │ OpenAI      │   │
│         │         │ Client      │   │
│         │         └─────────────┘   │
│         │                 │         │
│         ▼                 ▼         │
│  ┌──────────────┐  ┌─────────────┐ │
│  │ macOS        │  │ API         │ │
│  │ Keychain     │  │ (HTTPS)     │ │
│  └──────────────┘  └─────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

### Key Components

- **AudioRecorder** - Handles microphone input
- **OpenAIClient** - Unified API client for transcription and chat
- **KeychainHelper** - Secure credential storage
- **HotkeyManager** - Global hotkey monitoring (Fn key support)
- **DebugLog** - Privacy-preserving logging utility

## 🔧 Development

### Prerequisites
- Xcode 15.0+
- macOS 13.0+ SDK
- Swift 5.9+

### Building from Source

```bash
git clone https://github.com/writingmate/whispermate.git
cd whispermate/Whishpermate
open Whispermate.xcodeproj
```

Build configurations:
- **Debug**: Full logging enabled
- **Release**: Sensitive logging stripped, optimized

### Code Signing

For distribution:
```bash
xcodebuild -project Whispermate.xcodeproj \
  -scheme Whispermate \
  -configuration Release \
  build \
  CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
  ENABLE_HARDENED_RUNTIME=YES
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Security Issues
Please report security vulnerabilities privately to: **hello@writingmate.ai**

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- OpenAI for Whisper model
- Groq for fast inference
- Apple for macOS frameworks
- The open-source community

## 📧 Contact

- **Email**: hello@writingmate.ai
- **Issues**: [GitHub Issues](https://github.com/writingmate/whispermate/issues)
- **Security**: See [SECURITY.md](SECURITY.md)

## 🗺️ Roadmap

- [ ] Biometric authentication for sensitive operations
- [ ] Certificate pinning for API endpoints
- [ ] Data export functionality
- [ ] App Store distribution
- [ ] Custom keyboard shortcuts
- [ ] Multi-window support
- [ ] Encrypted history storage

---

**Made with ❤️ for productivity and privacy**
