import AppKit
import ApplicationServices

struct AppContext {
    let appName: String
    let bundleId: String?
    let windowTitle: String?
    let url: String?  // Extracted URL from window title for browsers

    var description: String {
        if let title = windowTitle, !title.isEmpty {
            return "\(appName) - \(title)"
        }
        return appName
    }
}

class AppContextHelper {
    /// Get the currently active application and its window title
    static func getCurrentAppContext() -> AppContext? {
        let workspace = NSWorkspace.shared

        // Get the frontmost application
        guard let activeApp = workspace.frontmostApplication,
              let appName = activeApp.localizedName else {
            DebugLog.info("Could not get frontmost application", context: "AppContextHelper")
            return nil
        }

        // Get the bundle identifier
        let bundleId = activeApp.bundleIdentifier

        // Try to get the window title using Accessibility API
        let windowTitle = getActiveWindowTitle()

        // Try to extract URL from window title or accessibility API
        let url = extractURL(from: windowTitle, bundleId: bundleId)

        DebugLog.info("App context: \(appName) (\(bundleId ?? "unknown")), Window: \(windowTitle ?? "none"), URL: \(url ?? "none")", context: "AppContextHelper")

        return AppContext(appName: appName, bundleId: bundleId, windowTitle: windowTitle, url: url)
    }

    /// Extract URL from window title or try to get it from accessibility API
    private static func extractURL(from windowTitle: String?, bundleId: String?) -> String? {
        // Known browser bundle IDs
        let browserBundleIds = [
            "com.apple.Safari",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "com.operasoftware.Opera"
        ]

        // Only try to extract URL for browsers
        guard let bundleId = bundleId, browserBundleIds.contains(bundleId) else {
            DebugLog.info("Not a browser, skipping URL extraction for bundle: \(bundleId ?? "unknown")", context: "AppContextHelper")
            return nil
        }

        DebugLog.info("Browser detected: \(bundleId), attempting URL extraction", context: "AppContextHelper")

        // Try to extract from window title
        if let title = windowTitle {
            DebugLog.info("Window title: \(title)", context: "AppContextHelper")

            // First try: Look for explicit URL patterns in the title
            // Common patterns: "Page Title - https://example.com" or "https://example.com - Page Title"
            let urlPattern = #"https?://([a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,})"#
            if let regex = try? NSRegularExpression(pattern: urlPattern, options: []),
               let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)),
               let range = Range(match.range(at: 1), in: title) {
                let domain = String(title[range])
                DebugLog.info("Extracted URL from title: \(domain)", context: "AppContextHelper")
                return domain
            }

            // Second try: Detect common sites from title keywords
            let commonSites = [
                ("Gmail", "mail.google.com"),
                ("LinkedIn", "linkedin.com"),
                ("Facebook", "facebook.com"),
                ("Twitter", "twitter.com"),
                ("X ", "x.com"),  // Space to avoid matching in words
                ("Instagram", "instagram.com"),
                ("YouTube", "youtube.com"),
                ("GitHub", "github.com"),
                ("Stack Overflow", "stackoverflow.com"),
                ("Reddit", "reddit.com"),
                ("Medium", "medium.com"),
                ("Notion", "notion.so"),
                ("Slack", "slack.com"),
                ("Discord", "discord.com"),
                ("ChatGPT", "chat.openai.com"),
                ("Google Docs", "docs.google.com"),
                ("Google Sheets", "sheets.google.com"),
                ("Google Drive", "drive.google.com")
            ]

            for (keyword, domain) in commonSites {
                if title.contains(keyword) {
                    DebugLog.info("Detected \(keyword) in title, using domain: \(domain)", context: "AppContextHelper")
                    return domain
                }
            }

            DebugLog.info("No URL pattern or known site found in title", context: "AppContextHelper")
        }

        // Try to get URL from accessibility API
        DebugLog.info("Trying to get URL from Accessibility API", context: "AppContextHelper")
        if let urlFromAX = getActiveWindowURL() {
            DebugLog.info("Got URL from Accessibility API: \(urlFromAX)", context: "AppContextHelper")
            return urlFromAX
        }

        DebugLog.info("No URL found", context: "AppContextHelper")
        return nil
    }

    /// Try to get the URL from the active window using Accessibility API
    private static func getActiveWindowURL() -> String? {
        // Check if we have accessibility permissions
        guard AXIsProcessTrusted() else {
            return nil
        }

        // Get the system-wide accessibility element
        let systemWideElement = AXUIElementCreateSystemWide()

        // Get the focused application
        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )

        guard appResult == .success, let appElement = focusedApp as! AXUIElement? else {
            return nil
        }

        // Try to get the focused UI element (address bar, etc.)
        var focusedElement: AnyObject?
        let elementResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard elementResult == .success, let element = focusedElement as! AXUIElement? else {
            return nil
        }

        // Try to get the URL attribute (some browsers expose this)
        var url: AnyObject?
        let urlResult = AXUIElementCopyAttributeValue(
            element,
            "AXURL" as CFString,
            &url
        )

        if urlResult == .success, let urlString = url as? String, let urlObj = URL(string: urlString) {
            return urlObj.host
        }

        return nil
    }

    /// Get the title of the active window using Accessibility API
    private static func getActiveWindowTitle() -> String? {
        // Check if we have accessibility permissions
        guard AXIsProcessTrusted() else {
            DebugLog.info("No accessibility permissions - cannot get window title", context: "AppContextHelper")
            return nil
        }

        // Get the system-wide accessibility element
        let systemWideElement = AXUIElementCreateSystemWide()

        // Get the focused application
        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )

        guard appResult == .success, let appElement = focusedApp as! AXUIElement? else {
            DebugLog.info("Could not get focused application element", context: "AppContextHelper")
            return nil
        }

        // Get the focused window
        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard windowResult == .success, let windowElement = focusedWindow as! AXUIElement? else {
            DebugLog.info("Could not get focused window element", context: "AppContextHelper")
            return nil
        }

        // Get the window title
        var title: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(
            windowElement,
            kAXTitleAttribute as CFString,
            &title
        )

        guard titleResult == .success, let windowTitle = title as? String else {
            DebugLog.info("Could not get window title", context: "AppContextHelper")
            return nil
        }

        return windowTitle
    }
}
