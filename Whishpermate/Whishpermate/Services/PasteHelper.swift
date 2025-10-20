import AppKit
import CoreGraphics

class PasteHelper {
    private static var previousApp: NSRunningApplication?

    static func storePreviousApp() {
        // Store the currently active app (before WhisperMate gets focus)
        let workspace = NSWorkspace.shared
        if let activeApp = workspace.frontmostApplication {
            previousApp = activeApp
            print("[PasteHelper LOG] Stored previous app: \(activeApp.localizedName ?? "unknown")")
        }
    }

    static func copyAndPaste(_ text: String) {
        print("[PasteHelper LOG] ========================================")
        print("[PasteHelper LOG] copyAndPaste called")
        print("[PasteHelper LOG] Text length: \(text.count) characters")

        let pasteboard = NSPasteboard.general

        // Store original clipboard content
        let originalContent = pasteboard.string(forType: .string)
        print("[PasteHelper LOG] Stored original clipboard content: \(originalContent != nil ? "yes (\(originalContent!.count) chars)" : "none")")

        // Copy transcription to clipboard
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        print("[PasteHelper LOG] Clipboard set success: \(success)")

        // Verify clipboard contents
        if let clipboardContent = pasteboard.string(forType: .string) {
            print("[PasteHelper LOG] Clipboard verification: \(clipboardContent.prefix(50))...")
        } else {
            print("[PasteHelper LOG] ERROR: Failed to verify clipboard contents!")
        }

        // Get the app to paste into
        let targetApp = previousApp ?? NSWorkspace.shared.frontmostApplication
        print("[PasteHelper LOG] Target app for paste: \(targetApp?.localizedName ?? "unknown")")

        // Activate the target app first
        if let app = targetApp, app.bundleIdentifier != Bundle.main.bundleIdentifier {
            print("[PasteHelper LOG] Activating target app: \(app.localizedName ?? "unknown")")
            app.activate(options: [])

            // Wait for app to become active, then paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("[PasteHelper LOG] Delay complete, simulating paste...")
                simulatePaste()

                // Restore original clipboard content after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if let original = originalContent {
                        pasteboard.clearContents()
                        pasteboard.setString(original, forType: .string)
                        print("[PasteHelper LOG] Restored original clipboard content")
                    }
                    previousApp = nil // Clear stored app
                }
            }
        } else {
            print("[PasteHelper LOG] No target app, pasting directly")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                simulatePaste()

                // Restore original clipboard content after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if let original = originalContent {
                        pasteboard.clearContents()
                        pasteboard.setString(original, forType: .string)
                        print("[PasteHelper LOG] Restored original clipboard content")
                    }
                    previousApp = nil
                }
            }
        }
    }

    private static func simulatePaste() {
        print("[PasteHelper LOG] simulatePaste started")

        // Check accessibility permissions
        let trusted = AXIsProcessTrusted()
        print("[PasteHelper LOG] Accessibility trusted: \(trusted)")

        if !trusted {
            print("[PasteHelper LOG] ⚠️ WARNING: Accessibility permissions not granted!")
            print("[PasteHelper LOG] Paste may not work without accessibility access")
        }

        // Simulate Cmd+V keypress
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("[PasteHelper LOG] ERROR: Failed to create CGEventSource")
            return
        }

        print("[PasteHelper LOG] Creating keyboard events...")

        // Key codes
        let cmdKeyCode: CGKeyCode = 0x37  // Left Command
        let vKeyCode: CGKeyCode = 0x09    // V key

        // Create Cmd key down event
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: true) else {
            print("[PasteHelper LOG] ERROR: Failed to create cmdDown event")
            return
        }
        cmdDown.flags = .maskCommand

        // Create V key down event with Cmd modifier
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            print("[PasteHelper LOG] ERROR: Failed to create vDown event")
            return
        }
        vDown.flags = .maskCommand

        // Create V key up event with Cmd modifier
        guard let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("[PasteHelper LOG] ERROR: Failed to create vUp event")
            return
        }
        vUp.flags = .maskCommand

        // Create Cmd key up event
        guard let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: false) else {
            print("[PasteHelper LOG] ERROR: Failed to create cmdUp event")
            return
        }

        print("[PasteHelper LOG] Events created successfully")
        print("[PasteHelper LOG] Posting events to system...")

        // Post events in sequence with small delays
        let loc = CGEventTapLocation.cghidEventTap

        cmdDown.post(tap: loc)
        print("[PasteHelper LOG] Posted: Cmd down")

        usleep(1000) // 1ms delay
        vDown.post(tap: loc)
        print("[PasteHelper LOG] Posted: V down")

        usleep(1000) // 1ms delay
        vUp.post(tap: loc)
        print("[PasteHelper LOG] Posted: V up")

        usleep(1000) // 1ms delay
        cmdUp.post(tap: loc)
        print("[PasteHelper LOG] Posted: Cmd up")

        print("[PasteHelper LOG] All events posted successfully")
        print("[PasteHelper LOG] ========================================")
    }
}
