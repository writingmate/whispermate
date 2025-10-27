import SwiftUI
import AppKit

struct HotkeyRecorderView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            Text(displayText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 40)
                .padding(.horizontal, 12)
                .background(isRecording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 2)
                )
                .onTapGesture {
                    startRecording()
                }

            // Always reserve space for X button to prevent jumping
            Button(action: {
                hotkeyManager.clearHotkey()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .opacity(hotkeyManager.currentHotkey != nil ? 1.0 : 0.0)
            }
            .buttonStyle(.plain)
            .frame(width: 20, height: 20)
            .disabled(hotkeyManager.currentHotkey == nil)
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
        DebugLog.info("[HotkeyRecorder LOG] ========================================", context: "HotkeyRecorderView")
        DebugLog.info("[HotkeyRecorder LOG] Starting hotkey recording mode", context: "HotkeyRecorderView")
        DebugLog.info("[HotkeyRecorder LOG] Waiting for key press or modifier change...", context: "HotkeyRecorderView")
        DebugLog.info("[HotkeyRecorder LOG] ========================================", context: "HotkeyRecorderView")
        isRecording = true
    }
}

struct HotkeyEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    let hotkeyManager: HotkeyManager

    func makeNSView(context: Context) -> NSView {
        DebugLog.info("[HotkeyRecorder LOG] Creating KeyEventView", context: "HotkeyRecorderView")
        let view = KeyEventView()
        view.onKeyDown = { event in
            DebugLog.info("[HotkeyRecorder LOG] keyDown event received", context: "HotkeyRecorderView")
            DebugLog.info("[HotkeyRecorder LOG]   - isRecording: \(isRecording)", context: "HotkeyRecorderView")
            if isRecording {
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                DebugLog.info("[HotkeyRecorder LOG]   - keyCode: \(event.keyCode)", context: "HotkeyRecorderView")
                DebugLog.info("[HotkeyRecorder LOG]   - modifiers: \(modifiers.rawValue)", context: "HotkeyRecorderView")
                DebugLog.info("[HotkeyRecorder LOG]   - modifiers description: \(modifiers)", context: "HotkeyRecorderView")

                // Check if it's a function key (F1-F20, keyCode 122-145, or individual codes)
                let functionKeys: [UInt16] = [
                    122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,  // F1-F12
                    105, 107, 113, 106                                          // F13-F16
                ]
                let isFunctionKey = functionKeys.contains(event.keyCode)

                // Allow: modifiers present, OR function key without modifiers
                if !modifiers.isEmpty {
                    DebugLog.info("[HotkeyRecorder LOG]   - Modifiers not empty, setting hotkey", context: "HotkeyRecorderView")
                    let hotkey = Hotkey(keyCode: event.keyCode, modifiers: modifiers)
                    hotkeyManager.setHotkey(hotkey)
                    isRecording = false
                } else if isFunctionKey {
                    DebugLog.info("[HotkeyRecorder LOG]   - Function key detected, setting hotkey", context: "HotkeyRecorderView")
                    let hotkey = Hotkey(keyCode: event.keyCode, modifiers: [])
                    hotkeyManager.setHotkey(hotkey)
                    isRecording = false
                } else {
                    DebugLog.info("[HotkeyRecorder LOG]   - Not a valid hotkey (need modifiers or function key)", context: "HotkeyRecorderView")
                }
            }
        }
        view.onFlagsChanged = { event in
            DebugLog.info("[HotkeyRecorder LOG] ⚡️ flagsChanged event received ⚡️", context: "HotkeyRecorderView")
            DebugLog.info("[HotkeyRecorder LOG]   - isRecording: \(isRecording)", context: "HotkeyRecorderView")
            if isRecording {
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                DebugLog.info("[HotkeyRecorder LOG]   - Raw modifierFlags: \(event.modifierFlags.rawValue)", context: "HotkeyRecorderView")
                DebugLog.info("[HotkeyRecorder LOG]   - Masked modifiers: \(modifiers.rawValue)", context: "HotkeyRecorderView")
                DebugLog.info("[HotkeyRecorder LOG]   - Modifiers description: \(modifiers)", context: "HotkeyRecorderView")
                DebugLog.info("[HotkeyRecorder LOG]   - Contains .function: \(modifiers.contains(.function))", context: "HotkeyRecorderView")
                DebugLog.info("[HotkeyRecorder LOG]   - NSEvent.ModifierFlags.function value: \(NSEvent.ModifierFlags.function.rawValue)", context: "HotkeyRecorderView")

                // Check if only Fn key is pressed (no other modifiers)
                if modifiers == .function {
                    DebugLog.info("[HotkeyRecorder LOG] ✅ MATCH: Detected Fn key ONLY - setting hotkey", context: "HotkeyRecorderView")
                    // Use a special keyCode for Fn-only hotkey
                    let hotkey = Hotkey(keyCode: 63, modifiers: .function)
                    hotkeyManager.setHotkey(hotkey)
                    isRecording = false
                } else if modifiers.contains(.function) {
                    DebugLog.info("[HotkeyRecorder LOG] ⚠️ Fn detected but with other modifiers: \(modifiers)", context: "HotkeyRecorderView")
                } else {
                    DebugLog.info("[HotkeyRecorder LOG] ❌ Modifiers do not contain Fn: \(modifiers)", context: "HotkeyRecorderView")
                }
            }
        }
        DebugLog.info("[HotkeyRecorder LOG] KeyEventView created with handlers attached", context: "HotkeyRecorderView")
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isRecording {
            DebugLog.info("[HotkeyRecorder LOG] updateNSView: Making view first responder", context: "HotkeyRecorderView")
            let didBecomeFirstResponder = nsView.window?.makeFirstResponder(nsView)
            DebugLog.info("[HotkeyRecorder LOG] updateNSView: First responder result: \(didBecomeFirstResponder ?? false)", context: "HotkeyRecorderView")
            DebugLog.info("updateNSView: Current first responder: \(nsView.window?.firstResponder?.description ?? "none")", context: "HotkeyRecorderView")
        }
    }
}

class KeyEventView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?
    var onFlagsChanged: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool {
        DebugLog.info("[KeyEventView LOG] acceptsFirstResponder queried, returning true", context: "HotkeyRecorderView")
        return true
    }

    override func keyDown(with event: NSEvent) {
        DebugLog.info("[KeyEventView LOG] keyDown method called in NSView", context: "HotkeyRecorderView")
        onKeyDown?(event)
    }

    override func flagsChanged(with event: NSEvent) {
        DebugLog.info("[KeyEventView LOG] flagsChanged method called in NSView", context: "HotkeyRecorderView")
        onFlagsChanged?(event)
    }

    override func mouseDown(with event: NSEvent) {
        DebugLog.info("[KeyEventView LOG] mouseDown - accepting click to become first responder", context: "HotkeyRecorderView")
        // Accept clicks to become first responder
        let result = window?.makeFirstResponder(self)
        DebugLog.info("[KeyEventView LOG] makeFirstResponder result: \(result ?? false)", context: "HotkeyRecorderView")
    }
}
