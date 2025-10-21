import SwiftUI
import AppKit

struct HotkeyRecorderView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @State private var isRecording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recording Hotkey")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text(displayText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(isRecording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 2)
                    )
                    .onTapGesture {
                        startRecording()
                    }

                if hotkeyManager.currentHotkey != nil {
                    Button(action: {
                        hotkeyManager.clearHotkey()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isRecording {
                Text("Press your desired key combination...")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .background(HotkeyEventHandler(isRecording: $isRecording, hotkeyManager: hotkeyManager))
    }

    private var displayText: String {
        if isRecording {
            return "Recording..."
        } else if let hotkey = hotkeyManager.currentHotkey {
            return hotkey.displayString
        } else {
            return "Click to set hotkey"
        }
    }

    private func startRecording() {
        print("[HotkeyRecorder LOG] ========================================")
        print("[HotkeyRecorder LOG] Starting hotkey recording mode")
        print("[HotkeyRecorder LOG] Waiting for key press or modifier change...")
        print("[HotkeyRecorder LOG] ========================================")
        isRecording = true
    }
}

struct HotkeyEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    let hotkeyManager: HotkeyManager

    func makeNSView(context: Context) -> NSView {
        print("[HotkeyRecorder LOG] Creating KeyEventView")
        let view = KeyEventView()
        view.onKeyDown = { event in
            print("[HotkeyRecorder LOG] keyDown event received")
            print("[HotkeyRecorder LOG]   - isRecording: \(isRecording)")
            if isRecording {
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                print("[HotkeyRecorder LOG]   - keyCode: \(event.keyCode)")
                print("[HotkeyRecorder LOG]   - modifiers: \(modifiers.rawValue)")
                print("[HotkeyRecorder LOG]   - modifiers description: \(modifiers)")

                // Allow just Fn key, or any modifier combination
                if !modifiers.isEmpty {
                    print("[HotkeyRecorder LOG]   - Modifiers not empty, setting hotkey")
                    let hotkey = Hotkey(keyCode: event.keyCode, modifiers: modifiers)
                    hotkeyManager.setHotkey(hotkey)
                    isRecording = false
                } else {
                    print("[HotkeyRecorder LOG]   - Modifiers empty, ignoring")
                }
            }
        }
        view.onFlagsChanged = { event in
            print("[HotkeyRecorder LOG] ⚡️ flagsChanged event received ⚡️")
            print("[HotkeyRecorder LOG]   - isRecording: \(isRecording)")
            if isRecording {
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                print("[HotkeyRecorder LOG]   - Raw modifierFlags: \(event.modifierFlags.rawValue)")
                print("[HotkeyRecorder LOG]   - Masked modifiers: \(modifiers.rawValue)")
                print("[HotkeyRecorder LOG]   - Modifiers description: \(modifiers)")
                print("[HotkeyRecorder LOG]   - Contains .function: \(modifiers.contains(.function))")
                print("[HotkeyRecorder LOG]   - NSEvent.ModifierFlags.function value: \(NSEvent.ModifierFlags.function.rawValue)")

                // Check if only Fn key is pressed (no other modifiers)
                if modifiers == .function {
                    print("[HotkeyRecorder LOG] ✅ MATCH: Detected Fn key ONLY - setting hotkey")
                    // Use a special keyCode for Fn-only hotkey
                    let hotkey = Hotkey(keyCode: 63, modifiers: .function)
                    hotkeyManager.setHotkey(hotkey)
                    isRecording = false
                } else if modifiers.contains(.function) {
                    print("[HotkeyRecorder LOG] ⚠️ Fn detected but with other modifiers: \(modifiers)")
                } else {
                    print("[HotkeyRecorder LOG] ❌ Modifiers do not contain Fn: \(modifiers)")
                }
            }
        }
        print("[HotkeyRecorder LOG] KeyEventView created with handlers attached")
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isRecording {
            print("[HotkeyRecorder LOG] updateNSView: Making view first responder")
            let didBecomeFirstResponder = nsView.window?.makeFirstResponder(nsView)
            print("[HotkeyRecorder LOG] updateNSView: First responder result: \(didBecomeFirstResponder ?? false)")
            print("[HotkeyRecorder LOG] updateNSView: Current first responder: \(nsView.window?.firstResponder?.description ?? "none")")
        }
    }
}

class KeyEventView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?
    var onFlagsChanged: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool {
        print("[KeyEventView LOG] acceptsFirstResponder queried, returning true")
        return true
    }

    override func keyDown(with event: NSEvent) {
        print("[KeyEventView LOG] keyDown method called in NSView")
        onKeyDown?(event)
    }

    override func flagsChanged(with event: NSEvent) {
        print("[KeyEventView LOG] flagsChanged method called in NSView")
        onFlagsChanged?(event)
    }

    override func mouseDown(with event: NSEvent) {
        print("[KeyEventView LOG] mouseDown - accepting click to become first responder")
        // Accept clicks to become first responder
        let result = window?.makeFirstResponder(self)
        print("[KeyEventView LOG] makeFirstResponder result: \(result ?? false)")
    }
}
