import SwiftUI
import AppKit

// MARK: - Window Identifiers
struct WindowIdentifiers {
    static let main = NSUserInterfaceItemIdentifier("main-window")
    static let settings = NSUserInterfaceItemIdentifier("settings-window")
    static let history = NSUserInterfaceItemIdentifier("history-window")
}

// MARK: - Notification Names
extension NSNotification.Name {
    static let showHistory = NSNotification.Name("ShowHistory")
    static let showSettings = NSNotification.Name("ShowSettings")
    static let showOnboarding = NSNotification.Name("ShowOnboarding")
    static let onboardingComplete = NSNotification.Name("OnboardingComplete")
}

class StatusBarManager {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    weak var appWindow: NSWindow?

    func setupMenuBar() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else {
            DebugLog.info("Failed to create status bar button", context: "StatusBarManager")
            return
        }

        // Use app icon for menu bar
        if let appIcon = NSImage(named: "AppIcon"),
           let icon = appIcon.copy() as? NSImage {
            icon.size = NSSize(width: 18, height: 18)
            button.image = icon
        } else {
            // Fallback to SF Symbol
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "WhisperMate")?.withSymbolConfiguration(config)
        }

        // Create menu
        menu = NSMenu()

        // Show/Hide Window
        let showHideItem = NSMenuItem(
            title: "Show WhisperMate",
            action: #selector(toggleWindow),
            keyEquivalent: ""
        )
        showHideItem.target = self
        menu?.addItem(showHideItem)

        menu?.addItem(NSMenuItem.separator())

        // History
        let historyItem = NSMenuItem(
            title: "History",
            action: #selector(showHistory),
            keyEquivalent: "h"
        )
        historyItem.target = self
        menu?.addItem(historyItem)

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu?.addItem(settingsItem)

        menu?.addItem(NSMenuItem.separator())

        // Onboarding
        let onboardingItem = NSMenuItem(
            title: "Show Onboarding",
            action: #selector(showOnboarding),
            keyEquivalent: ""
        )
        onboardingItem.target = self
        menu?.addItem(onboardingItem)

        menu?.addItem(NSMenuItem.separator())

        // Check for Updates
        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu?.addItem(updateItem)

        menu?.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit WhisperMate",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu?.addItem(quitItem)

        statusItem?.menu = menu

        DebugLog.info("Menu bar icon created successfully", context: "StatusBarManager")
    }

    @objc private func toggleWindow() {
        // Use stored window reference if available, otherwise fall back to first window
        let window = appWindow ?? NSApplication.shared.windows.first(where: { $0.level == .normal })

        if let window = window {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                NSApplication.shared.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        } else {
            DebugLog.info("Warning: Could not find app window to toggle", context: "StatusBarManager")
        }
    }

    @objc private func showHistory() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let window = appWindow ?? NSApplication.shared.windows.first(where: { $0.level == .normal })
        window?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .showHistory, object: nil)
    }

    @objc private func showSettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .showSettings, object: nil)
    }

    @objc private func showOnboarding() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .showOnboarding, object: nil)
    }

    @objc private func checkForUpdates() {
        Task { @MainActor in
            await UpdateChecker.shared.checkForUpdates(showAlertIfNoUpdate: true)
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    deinit {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}
