import AppKit
import ApplicationServices

struct AppContext {
    let appName: String
    let windowTitle: String?

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

        // Try to get the window title using Accessibility API
        let windowTitle = getActiveWindowTitle()

        DebugLog.info("App context: \(appName), Window: \(windowTitle ?? "none")", context: "AppContextHelper")

        return AppContext(appName: appName, windowTitle: windowTitle)
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
