# WhisperMate for Windows - Screen-by-Screen Design

## Technology Stack
- **Framework**: WPF (Windows Presentation Foundation)
- **Runtime**: .NET 8 (latest LTS)
- **Language**: C# 12
- **UI**: XAML (similar to SwiftUI's declarative syntax)

## 1. Main Window (ContentView equivalent)

### Design
**Size**: 400x320px (fixed)
**Style**: Borderless, rounded corners (8px), drop shadow
**Draggable**: Yes, anywhere on window
**Always on top**: No (default), Yes (overlay mode)

### Layout States

#### State 1: Idle (No recording)
```
┌────────────────────────────────────┐
│  [Copy] [Minimize]            400px│
│                                    │
│         ╭─────────╮                │
│         │  🎤     │   48px icon    │
│         ╰─────────╯                │
│                                    │
│      Ready to record               │
│      (14pt, secondary)             │
│                                    │
│                                    │
│   Press Fn to record               │
│   (11pt, tertiary)                 │
│                                    │
└────────────────────────────────────┘
       320px height
```

**Elements**:
- Top toolbar (copy button hidden, minimize button visible)
- Centered microphone icon (48pt, gray)
- "Ready to record" text (14pt)
- Hotkey hint at bottom (11pt, showing configured hotkey)

#### State 2: Recording
```
┌────────────────────────────────────┐
│  [Copy] [Minimize]                 │
│                                    │
│    ▁▃▅▇█▇▅▃▁▃▅▇█▇▅▃▁               │
│    ▁▃▅▇█▇▅▃▁▃▅▇█▇▅▃▁  100px       │
│    (Waveform visualization)        │
│                                    │
│      Recording...                  │
│      (14pt, blue accent)           │
│                                    │
│   Release Fn to stop               │
│   (11pt, tertiary)                 │
│                                    │
└────────────────────────────────────┘
```

**Elements**:
- Animated waveform (blue accent color)
- "Recording..." text with pulsing animation
- Updated hint text

#### State 3: Processing
```
┌────────────────────────────────────┐
│  [Copy] [Minimize]                 │
│                                    │
│         ⟳                          │
│    (Spinning loader)   Large       │
│                                    │
│    Transcribing...                 │
│    (14pt, secondary)               │
│                                    │
│                                    │
│                                    │
│                                    │
└────────────────────────────────────┘
```

**Elements**:
- Circular progress indicator
- "Transcribing..." text

#### State 4: Result
```
┌────────────────────────────────────┐
│  [📋 Copy] [Minimize]              │
│                                    │
│  This is the transcribed text      │
│  from the audio recording. It      │
│  can span multiple lines and       │
│  the user can select and copy      │
│  portions of it. The text area     │
│  is scrollable if content is       │
│  very long.                        │
│  (14pt, editable TextBox)          │
│                                    │
│   Press Fn to record               │
└────────────────────────────────────┘
```

**Elements**:
- Copy button now visible and enabled
- Editable text area (scrollable)
- Can select text
- Hotkey hint returns

---

## 2. Onboarding Window

### Design
**Size**: 600x500px (fixed)
**Style**: Standard window with title bar
**Navigation**: Page indicators (dots) + Next/Back buttons

### Step 1: Welcome & Microphone
```
┌─────────────────────────────────────────┐
│ WhisperMate Setup              [×]      │
├─────────────────────────────────────────┤
│                                         │
│            🎙️ (64px icon)              │
│                                         │
│         Microphone Access               │
│         (24pt semibold)                 │
│                                         │
│  WhisperMate needs access to your      │
│  microphone to record and transcribe   │
│  your voice.                            │
│  (14pt, centered, secondary)            │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  [Open Windows Settings]          │ │
│  └───────────────────────────────────┘ │
│                                         │
│         ● ○ ○ ○  (page indicators)     │
│                                         │
│  [Skip]                     [Next →]   │
└─────────────────────────────────────────┘
```

### Step 2: Hotkey Configuration
```
┌─────────────────────────────────────────┐
│ WhisperMate Setup              [×]      │
├─────────────────────────────────────────┤
│                                         │
│            ⌨️ (64px icon)               │
│                                         │
│         Recording Hotkey                │
│         (24pt semibold)                 │
│                                         │
│  Set a global hotkey to start/stop     │
│  recording from anywhere.               │
│  (14pt, centered, secondary)            │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  Click to set hotkey              │ │
│  │  (or) [Ctrl + Shift + R]          │ │
│  │  (Large input box, clickable)  [×]│ │
│  └───────────────────────────────────┘ │
│                                         │
│  Tip: Function keys work best          │
│  (11pt, secondary)                      │
│                                         │
│         ○ ● ○ ○                        │
│                                         │
│  [← Back]                   [Next →]   │
└─────────────────────────────────────────┘
```

### Step 3: Prompt Rules
```
┌─────────────────────────────────────────┐
│ WhisperMate Setup              [×]      │
├─────────────────────────────────────────┤
│          ✏️ (64px icon)                 │
│                                         │
│         Customize Output                │
│         (24pt semibold)                 │
│                                         │
│  Add rules to improve transcription    │
│  quality. You can modify these anytime │
│  in settings. (14pt, centered)         │
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ ☑ Format numbers as digits      [🗑]││
│ │ ☐ Always speak yoda style       [🗑]││
│ │                                      ││
│ │ ┌─────────────────────────────┐ [+] ││
│ │ │Add custom rule...            │     ││
│ │ └─────────────────────────────┘     ││
│ │                                      ││
│ │ ─── See it in action ───            ││
│ │                                      ││
│ │ I have 2 apples  [→]                ││
│ │ I have two apples (result)          ││
│ └─────────────────────────────────────┘│
│                                         │
│         ○ ○ ● ○                        │
│                                         │
│  [← Back]                   [Next →]   │
└─────────────────────────────────────────┘
```

### Step 4: Complete
```
┌─────────────────────────────────────────┐
│ WhisperMate Setup              [×]      │
├─────────────────────────────────────────┤
│                                         │
│            ✅ (64px icon)               │
│                                         │
│         You're All Set!                 │
│         (24pt semibold)                 │
│                                         │
│  WhisperMate is ready to use.          │
│  Press your hotkey from anywhere to    │
│  start recording.                       │
│  (14pt, centered, secondary)            │
│                                         │
│  Quick tips:                            │
│  • Hold hotkey to record               │
│  • Double-tap for continuous mode      │
│  • Access settings from system tray    │
│  (13pt, left-aligned, bulleted)        │
│                                         │
│         ○ ○ ○ ●                        │
│                                         │
│  [← Back]              [Get Started]   │
└─────────────────────────────────────────┘
```

---

## 3. Settings Window

### Design
**Size**: 600x500px (minimum), resizable
**Layout**: Sidebar (160px) + Content area
**Style**: Standard window

### Overall Layout
```
┌─────────────────────────────────────────────────────────┐
│ Settings                                         [_][□][×]│
├──────────────┬──────────────────────────────────────────┤
│              │  Audio                          [×]      │
│  🔊 Audio    │                                          │
│  📝 Text Rules│  ┌────────────────────────────────────┐│
│  ⌨️ Hotkeys   │  │ Input Device                       ││
│              │  │ (15pt semibold)                    ││
│              │  │                                     ││
│              │  │ Select your microphone or audio    ││
│              │  │ input device (12pt secondary)      ││
│              │  │                                     ││
│              │  │ [Dropdown: Built-in Microphone ▼] ││
│              │  │                                     ││
│              │  │ ─────────────────────────────────  ││
│              │  │                                     ││
│              │  │ Language                           ││
│              │  │ (15pt semibold)                    ││
│              │  │                                     ││
│              │  │ Select languages for transcription ││
│              │  │ (12pt secondary)                   ││
│              │  │                                     ││
│              │  │ [🌍 Auto] [🇺🇸 English] [🇷🇺 Russian]││
│              │  │ [🇩🇪 German] [🇫🇷 French] [🇪🇸 Spanish]│
│              │  │                                     ││
│              │  └────────────────────────────────────┘│
└──────────────┴──────────────────────────────────────────┘
```

### Audio Section
**Header**: "Audio" (20pt semibold) with close button
**Content**:
- Input Device selector
- Language grid (2 columns)
- Selected languages highlighted in blue

### Text Rules Section
- Add rule text box with + button
- Checkbox list with delete buttons
- Combined prompt preview
- Scrollable content area

### Hotkeys Section
- Hotkey input box (40px height)
- Clear button
- Configuration status indicator

---

## 4. History Window

### Design
**Size**: 800x800px (minimum), resizable
**Style**: Standard window with search

```
┌───────────────────────────────────────────────────────────┐
│ History                                          [_][□][×] │
├───────────────────────────────────────────────────────────┤
│  🔍 [Search transcriptions...                          ] │
│                                                           │
├───────────────────────────────────────────────────────────┤
│ 12/25/2024 3:45 PM  │  This is the first recording text  │
│ 2.3s                │  and it can span multiple lines... │📋🗑│
├───────────────────────────────────────────────────────────┤
│ 12/25/2024 3:42 PM  │  Another transcription here that   │   │
│ 1.8s                │  was recorded earlier today...     │📋🗑│
├───────────────────────────────────────────────────────────┤
```

**Features**:
- Search bar at top
- Scrollable list with dividers
- Hover shows copy/delete buttons (fade in, no layout shift)
- "Clear All" button at bottom
- Empty state with helpful message

---

## 5. System Tray

**Icon**: Small microphone icon (16x16px)
**Menu**: Show/Hide, Settings, History, Quit

---

## Color Scheme

### Light Theme
- Background: White (#FFFFFF)
- Accent: Windows Blue (#0078D4)
- Text Primary: Black (#000000)
- Text Secondary: Gray (#6B6B6B)

### Dark Theme Support
- Background: Dark Gray (#1E1E1E)
- Accent: Light Blue (#60CDFF)
- Text Primary: White (#FFFFFF)

---

## Typography
- **Font**: Segoe UI (Windows default)
- **Sizes**: 20pt (titles), 15pt (labels), 13pt (body), 12pt (descriptions), 11pt (captions)

---

## Implementation Notes

### Required NuGet Packages
- `NAudio` - Audio recording
- `Newtonsoft.Json` - JSON handling
- `Hardcodet.NotifyIcon.Wpf` - System tray
- `NHotkey.Wpf` - Global hotkeys
- `CommunityToolkit.Mvvm` - MVVM helpers

### Platform-Specific Features
- Windows Credential Manager for API keys
- AppData for settings/history storage
- SendInput for auto-paste functionality
- WASAPI for audio recording

### Estimated Timeline
- Setup & Services: 4-5 days
- UI Implementation: 5-7 days
- Testing & Polish: 2-3 days
- **Total**: ~2.5-3 weeks
