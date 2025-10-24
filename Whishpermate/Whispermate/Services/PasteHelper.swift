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

        // Check accessibility permissions early
        let trusted = AXIsProcessTrusted()
        print("[PasteHelper LOG] Accessibility trusted: \(trusted)")

        if !trusted {
            print("[PasteHelper LOG] ⚠️ WARNING: Accessibility permissions not granted!")
            // Prompt user to grant accessibility
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
            let enabled = AXIsProcessTrustedWithOptions(options)
            print("[PasteHelper LOG] Prompted for accessibility - enabled: \(enabled)")

            if !enabled {
                // Just copy to clipboard without pasting
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                print("[PasteHelper LOG] ⚠️ Only copied to clipboard (no paste - permissions needed)")
                return
            }
        }

        // Check if we need to add a space before pasting
        var textToPaste = text
        if let focusedElement = getFocusedTextElement() {
            if let existingText = getTextFromElement(focusedElement) {
                print("[PasteHelper LOG] Existing text found: \"\(existingText.prefix(50))...\"")
                // Add space if there's existing text and it doesn't end with whitespace
                if !existingText.isEmpty && !existingText.hasSuffix(" ") && !existingText.hasSuffix("\n") && !existingText.hasSuffix("\t") {
                    textToPaste = " " + text
                    print("[PasteHelper LOG] ✅ Added space before text")
                } else {
                    print("[PasteHelper LOG] ℹ️ No space needed (text is empty or ends with whitespace)")
                }
            }
        } else {
            print("[PasteHelper LOG] ℹ️ Could not get focused element, pasting without space check")
        }

        let pasteboard = NSPasteboard.general

        // Store original clipboard content
        let originalContent = pasteboard.string(forType: .string)
        print("[PasteHelper LOG] Stored original clipboard content: \(originalContent != nil ? "yes (\(originalContent!.count) chars)" : "none")")

        // Copy transcription to clipboard (use the prepared text with space if needed)
        pasteboard.clearContents()
        let success = pasteboard.setString(textToPaste, forType: .string)
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

    // MARK: - Accessibility Helpers

    private static func getFocusedTextElement() -> AXUIElement? {
        // Get the system-wide accessibility element
        let systemWideElement = AXUIElementCreateSystemWide()

        // Get the focused application
        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)

        guard appResult == .success, let appElement = focusedApp else {
            print("[PasteHelper LOG] Could not get focused application")
            return nil
        }

        // Get the focused UI element in that application
        var focusedElement: AnyObject?
        let elementResult = AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard elementResult == .success else {
            print("[PasteHelper LOG] Could not get focused UI element")
            return nil
        }

        return (focusedElement as! AXUIElement)
    }

    private static func getTextFromElement(_ element: AXUIElement) -> String? {
        // Try to get the value (text content) from the element
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)

        if result == .success, let text = value as? String {
            return text
        }

        // If that didn't work, try getting selected text range and then the full value
        var selectedRange: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedRange)

        if rangeResult == .success, let text = selectedRange as? String {
            return text
        }

        print("[PasteHelper LOG] Could not get text from element")
        return nil
    }
}
