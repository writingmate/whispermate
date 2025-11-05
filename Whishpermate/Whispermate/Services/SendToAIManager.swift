import Foundation
import AppKit
import ApplicationServices

class SendToAIManager {
    static let shared = SendToAIManager()

    private init() {}

    /// Send selected text to configured AI URL
    func sendSelectedTextToAI() async {
        DebugLog.info("SendToAI triggered", context: "SendToAIManager")

        // Get selected text
        guard let selectedText = await getSelectedText() else {
            DebugLog.warning("No text selected", context: "SendToAIManager")
            showNotification(title: "No Text Selected", message: "Please select some text first")
            return
        }

        guard !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            DebugLog.warning("Selected text is empty", context: "SendToAIManager")
            return
        }

        DebugLog.info("Got selected text: \(selectedText.prefix(50))...", context: "SendToAIManager")

        // Get configured URL template
        let urlTemplate = UserDefaults.standard.string(forKey: "aiPromptURL") ?? "https://chatgpt.com/?q={prompt}"

        // URL encode the selected text
        guard let encodedPrompt = selectedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            DebugLog.error("Failed to URL encode text", context: "SendToAIManager")
            return
        }

        // Replace {prompt} placeholder with encoded text
        let urlString = urlTemplate.replacingOccurrences(of: "{prompt}", with: encodedPrompt)

        guard let url = URL(string: urlString) else {
            DebugLog.error("Invalid URL: \(urlString)", context: "SendToAIManager")
            showNotification(title: "Invalid URL", message: "Check AI URL configuration in Settings")
            return
        }

        DebugLog.info("Opening URL: \(url.absoluteString)", context: "SendToAIManager")

        // Open URL in default browser
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Text Selection via Accessibility API

    private func getSelectedText() async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // Get the frontmost application
                guard let frontApp = NSWorkspace.shared.frontmostApplication else {
                    DebugLog.warning("No focused app found", context: "SendToAIManager")
                    continuation.resume(returning: nil)
                    return
                }

                let app = AXUIElementCreateApplication(frontApp.processIdentifier)

                // Get focused UI element
                var focusedElement: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedElement)

                guard result == .success, let element = focusedElement else {
                    DebugLog.warning("No focused element found", context: "SendToAIManager")
                    continuation.resume(returning: nil)
                    return
                }

                // Try to get selected text
                var selectedText: CFTypeRef?
                let textResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)

                if textResult == .success, let text = selectedText as? String {
                    continuation.resume(returning: text)
                } else {
                    DebugLog.warning("Could not get selected text, result: \(textResult.rawValue)", context: "SendToAIManager")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Notifications

    private func showNotification(title: String, message: String) {
        DispatchQueue.main.async {
            let notification = NSUserNotification()
            notification.title = title
            notification.informativeText = message
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
}
