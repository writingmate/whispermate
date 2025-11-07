//
//  WhishpermateApp.swift
//  Whishpermate
//
//  Created by Artsiom Vysotski on 10/16/25.
//

import SwiftUI
import WhisperMateShared

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusBarManager = StatusBarManager()
    var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Migrate old prompt rules to new system if needed
        RulesMigrationManager.migrateIfNeeded()

        statusBarManager.setupMenuBar()

        // Disable automatic window restoration for all windows except main
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        // Configure window immediately - no async delay
        configureMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Only show main window on reopen, not settings/history
        if !flag {
            if let window = mainWindow {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure window is always properly configured when app becomes active
        if mainWindow == nil {
            configureMainWindow()
        }
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let dockMenu = NSMenu()

        // Settings menu item
        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        dockMenu.addItem(settingsItem)

        return dockMenu
    }

    @objc private func openSettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .showSettings, object: nil)
    }

    private func configureMainWindow() {
        guard let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) else {
            // Window not ready yet, try again shortly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.configureMainWindow()
            }
            return
        }

        // Only configure once
        guard mainWindow == nil else { return }

        // Minimal configuration - let SwiftUI's .hiddenTitleBar style handle most of it
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.hasShadow = true

        // Use the system's corner radius for Tahoe/Sequoia
        if #available(macOS 13.0, *) {
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.cornerRadius = 12.0
            window.contentView?.layer?.masksToBounds = true
        }

        // Prevent window from being released when closed
        window.isReleasedWhenClosed = false

        // Set window identifier for identification
        window.identifier = WindowIdentifiers.main

        mainWindow = window
        statusBarManager.appWindow = window

        // Set delegate to customize traffic light button behavior
        window.delegate = self

        // Customize traffic light button actions
        customizeTrafficLightButtons(window: window)

        // Hide traffic lights initially (they'll show on hover)
        window.standardWindowButton(.closeButton)?.alphaValue = 0.0
        window.standardWindowButton(.miniaturizeButton)?.alphaValue = 0.0
        window.standardWindowButton(.zoomButton)?.alphaValue = 0.0

        // Center window before hiding it - prevents jump when showing onboarding
        window.center()

        // Hide window on launch - app starts in menu bar only mode
        window.setIsVisible(false)

        DebugLog.info("Main window configured as borderless, centered, with native corner radius and hidden on launch", context: "AppDelegate")
    }

    // MARK: - Traffic Light Customization

    private func customizeTrafficLightButtons(window: NSWindow) {
        // Get traffic light buttons
        guard let closeButton = window.standardWindowButton(.closeButton),
              let miniaturizeButton = window.standardWindowButton(.miniaturizeButton) else {
            DebugLog.info("Could not get traffic light buttons", context: "AppDelegate")
            return
        }

        // Red button: Hide window to menu bar
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)

        // Yellow button: Contract to overlay
        miniaturizeButton.target = self
        miniaturizeButton.action = #selector(yellowButtonClicked)

        // Green button: Keep standard zoom behavior (don't customize)

        DebugLog.info("Traffic light buttons customized", context: "AppDelegate")
    }

    @objc private func closeButtonClicked() {
        DebugLog.info("Red button clicked - hiding window to menu bar", context: "AppDelegate")
        mainWindow?.setIsVisible(false)
    }

    @objc private func yellowButtonClicked() {
        DebugLog.info("Yellow button clicked - contracting to overlay", context: "AppDelegate")
        OverlayWindowManager.shared.contractToOverlay()
    }

    // MARK: - Window Delegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Prevent actual close, just hide instead
        if sender === mainWindow {
            sender.setIsVisible(false)
            return false
        }
        return true
    }
}

@main
struct WhishpermateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Replace default "Preferences" with our Settings
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            // Add custom commands
            CommandGroup(after: .appInfo) {
                Button("History") {
                    NotificationCenter.default.post(name: .showHistory, object: nil)
                }
                .keyboardShortcut("h", modifiers: .command)
            }
        }

        // Settings window
        Window("Settings", id: "settings") {
            SettingsWindowView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .defaultPosition(.center)
        .defaultSize(width: 1050, height: 825)
        .commandsRemoved()

        // History window
        Window("History", id: "history") {
            HistoryWindowView()
        }
        .windowResizability(.contentSize)

        // Onboarding window
        Window("Welcome to Whispermate", id: "onboarding") {
            OnboardingView(
                onboardingManager: OnboardingManager.shared,
                hotkeyManager: HotkeyManager.shared,
                languageManager: LanguageManager(),
                promptRulesManager: PromptRulesManager.shared,
                llmProviderManager: LLMProviderManager()
            )
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .defaultSize(width: 560, height: 520)
        .commandsRemoved()
    }
}
