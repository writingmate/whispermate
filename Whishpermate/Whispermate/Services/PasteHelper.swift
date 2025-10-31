import AppKit
import CoreGraphics

class PasteHelper {
    private static var previousApp: NSRunningApplication?

    static func storePreviousApp() {
        // Store the currently active app (before WhisperMate gets focus)
        let workspace = NSWorkspace.shared
        if let activeApp = workspace.frontmostApplication {
            previousApp = activeApp
            DebugLog.info("Stored previous app: \(activeApp.localizedName ?? "unknown")", context: "PasteHelper")
        }
    }

    static func copyAndPaste(_ text: String) {
        DebugLog.info("========================================", context: "PasteHelper")
        DebugLog.info("copyAndPaste called", context: "PasteHelper")
        DebugLog.info("Text length: \(text.count) characters", context: "PasteHelper")

        // Check accessibility permissions early
        let trusted = AXIsProcessTrusted()
        DebugLog.info("Accessibility trusted: \(trusted)", context: "PasteHelper")

        if !trusted {
            DebugLog.info("⚠️ WARNING: Accessibility permissions not granted!", context: "PasteHelper")
            // Just copy to clipboard without pasting (prevents beep)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            DebugLog.info("⚠️ Only copied to clipboard (no paste - permissions needed)", context: "PasteHelper")
            return
        }

        // Note: We proceed with paste even if we can't detect a focused element
        // because web contenteditable fields (Gmail, etc.) often don't report via Accessibility API
        if getFocusedTextElement() == nil {
            DebugLog.info("⚠️ No focused text element detected (may be web contenteditable), will attempt paste anyway", context: "PasteHelper")
        }

        // Check if we need to add a space before pasting
        var textToPaste = text
        if let focusedElement = getFocusedTextElement() {
            if let existingText = getTextFromElement(focusedElement) {
                DebugLog.info("Existing text found: \"\(existingText.prefix(50))...\"", context: "PasteHelper")
                // Add space if there's existing text and it doesn't end with whitespace
                if !existingText.isEmpty && !existingText.hasSuffix(" ") && !existingText.hasSuffix("\n") && !existingText.hasSuffix("\t") {
                    textToPaste = " " + text
                    DebugLog.info("✅ Added space before text", context: "PasteHelper")
                } else {
                    DebugLog.info("ℹ️ No space needed (text is empty or ends with whitespace)", context: "PasteHelper")
                }
            }
        } else {
            // For web contenteditable fields, we can't detect existing text, so add a leading space
            // to be safe (user can delete if not needed)
            textToPaste = " " + text
            DebugLog.info("ℹ️ Could not get focused element (web field?), adding leading space to be safe", context: "PasteHelper")
        }

        let pasteboard = NSPasteboard.general

        // Store original clipboard content
        let originalContent = pasteboard.string(forType: .string)
        DebugLog.info("Stored original clipboard content: \(originalContent != nil ? "yes (\(originalContent!.count) chars)" : "none")", context: "PasteHelper")

        // Copy transcription to clipboard (use the prepared text with space if needed)
        pasteboard.clearContents()
        let success = pasteboard.setString(textToPaste, forType: .string)
        DebugLog.info("Clipboard set success: \(success)", context: "PasteHelper")

        // Verify clipboard contents
        if let clipboardContent = pasteboard.string(forType: .string) {
            DebugLog.info("Clipboard verification: \(clipboardContent.prefix(50))...", context: "PasteHelper")
        } else {
            DebugLog.info("ERROR: Failed to verify clipboard contents!", context: "PasteHelper")
        }

        // Get the app to paste into
        let targetApp = previousApp ?? NSWorkspace.shared.frontmostApplication
        DebugLog.info("Target app for paste: \(targetApp?.localizedName ?? "unknown")", context: "PasteHelper")

        // Activate the target app first
        if let app = targetApp, app.bundleIdentifier != Bundle.main.bundleIdentifier {
            DebugLog.info("Activating target app: \(app.localizedName ?? "unknown")", context: "PasteHelper")
            app.activate(options: [])

            // Wait for app to become active, then paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                DebugLog.info("Delay complete, simulating paste...", context: "PasteHelper")
                simulatePaste()

                // Restore original clipboard content after a short delay
                // Increased to 200ms to give web apps (Chrome, Firefox) time to process paste
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if let original = originalContent {
                        pasteboard.clearContents()
                        pasteboard.setString(original, forType: .string)
                        DebugLog.info("Restored original clipboard content", context: "PasteHelper")
                    }
                    previousApp = nil // Clear stored app
                }
            }
        } else {
            DebugLog.info("No target app, pasting directly", context: "PasteHelper")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                simulatePaste()

                // Restore original clipboard content after a short delay
                // Increased to 200ms to give web apps (Chrome, Firefox) time to process paste
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if let original = originalContent {
                        pasteboard.clearContents()
                        pasteboard.setString(original, forType: .string)
                        DebugLog.info("Restored original clipboard content", context: "PasteHelper")
                    }
                    previousApp = nil
                }
            }
        }
    }

    private static func simulatePaste() {
        DebugLog.info("simulatePaste started", context: "PasteHelper")

        // Check accessibility permissions
        let trusted = AXIsProcessTrusted()
        DebugLog.info("Accessibility trusted: \(trusted)", context: "PasteHelper")

        if !trusted {
            DebugLog.info("⚠️ WARNING: Accessibility permissions not granted!", context: "PasteHelper")
            DebugLog.info("Paste may not work without accessibility access", context: "PasteHelper")
        }

        // Simulate Cmd+V keypress
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            DebugLog.info("ERROR: Failed to create CGEventSource", context: "PasteHelper")
            return
        }

        DebugLog.info("Creating keyboard events...", context: "PasteHelper")

        // Key codes
        let cmdKeyCode: CGKeyCode = 0x37  // Left Command
        let vKeyCode: CGKeyCode = 0x09    // V key

        // Create Cmd key down event
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: true) else {
            DebugLog.info("ERROR: Failed to create cmdDown event", context: "PasteHelper")
            return
        }
        cmdDown.flags = .maskCommand

        // Create V key down event with Cmd modifier
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            DebugLog.info("ERROR: Failed to create vDown event", context: "PasteHelper")
            return
        }
        vDown.flags = .maskCommand

        // Create V key up event with Cmd modifier
        guard let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            DebugLog.info("ERROR: Failed to create vUp event", context: "PasteHelper")
            return
        }
        vUp.flags = .maskCommand

        // Create Cmd key up event
        guard let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: false) else {
            DebugLog.info("ERROR: Failed to create cmdUp event", context: "PasteHelper")
            return
        }

        DebugLog.info("Events created successfully", context: "PasteHelper")
        DebugLog.info("Posting events to system...", context: "PasteHelper")

        // Post events in sequence with small delays
        let loc = CGEventTapLocation.cghidEventTap

        cmdDown.post(tap: loc)
        DebugLog.info("Posted: Cmd down", context: "PasteHelper")

        usleep(1000) // 1ms delay
        vDown.post(tap: loc)
        DebugLog.info("Posted: V down", context: "PasteHelper")

        usleep(1000) // 1ms delay
        vUp.post(tap: loc)
        DebugLog.info("Posted: V up", context: "PasteHelper")

        usleep(1000) // 1ms delay
        cmdUp.post(tap: loc)
        DebugLog.info("Posted: Cmd up", context: "PasteHelper")

        DebugLog.info("All events posted successfully", context: "PasteHelper")
        DebugLog.info("========================================", context: "PasteHelper")
    }

    // MARK: - Accessibility Helpers

    private static func getFocusedTextElement() -> AXUIElement? {
        // Get the system-wide accessibility element
        let systemWideElement = AXUIElementCreateSystemWide()

        // Get the focused application
        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)

        guard appResult == .success, let appElement = focusedApp else {
            DebugLog.info("Could not get focused application", context: "PasteHelper")
            return nil
        }

        // Get the focused UI element in that application
        var focusedElement: AnyObject?
        let elementResult = AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard elementResult == .success else {
            DebugLog.info("Could not get focused UI element", context: "PasteHelper")
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

        DebugLog.info("Could not get text from element", context: "PasteHelper")
        return nil
    }
}
