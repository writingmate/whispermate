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

    // Keep references to managers
    private let appState = AppState.shared
    private let hotkeyManager = HotkeyManager.shared
    private let onboardingManager = OnboardingManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Migrate old prompt rules to new system if needed
        RulesMigrationManager.migrateIfNeeded()

        statusBarManager.setupMenuBar()

        // Disable automatic window restoration for all windows except main
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        // Configure window immediately - no async delay
        configureMainWindow()

        // Set up hotkey callbacks once at app startup
        // This ensures they persist throughout the app lifecycle
        setupHotkeyCallbacks()

        // Check if onboarding is needed and open window if necessary
        checkAndShowOnboarding()
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
        window.backgroundColor = NSColor.windowBackgroundColor
        window.hasShadow = true
        window.isOpaque = true

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

        // Hide overlay when main window becomes visible (but keep showing if recording)
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            let overlayManager = OverlayWindowManager.shared
            if window.isVisible && !overlayManager.isRecording && !overlayManager.isProcessing {
                DebugLog.info("Main window became key - hiding overlay", context: "AppDelegate")
                overlayManager.hide()
            }
        }

        // Hide traffic lights completely
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

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
        OverlayWindowManager.shared.show()
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

    // MARK: - Onboarding

    private func checkAndShowOnboarding() {
        // Delay slightly to ensure views are loaded and onChange handlers are registered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }

            // Check if onboarding needs to be shown
            self.onboardingManager.checkOnboardingStatus()

            DebugLog.info("Onboarding check complete. showOnboarding = \(self.onboardingManager.showOnboarding)", context: "AppDelegate")

            // The onChange handler in HistoryMasterDetailView will open the window automatically
        }
    }

    // MARK: - Hotkey Setup

    private func setupHotkeyCallbacks() {
        DebugLog.info("========================================", context: "AppDelegate")
        DebugLog.info("Setting up hotkey callbacks", context: "AppDelegate")
        DebugLog.info("========================================", context: "AppDelegate")

        // Hotkey callbacks now just delegate to AppState
        hotkeyManager.onHotkeyPressed = { [weak self] in
            DebugLog.info("🎯 Hotkey pressed", context: "AppDelegate")
            self?.appState.startRecording()
        }

        hotkeyManager.onHotkeyReleased = { [weak self] in
            DebugLog.info("🎯 Hotkey released", context: "AppDelegate")
            self?.appState.stopRecording()
        }

        hotkeyManager.onDoubleTap = { [weak self] in
            DebugLog.info("🎯🎯 Double-tap", context: "AppDelegate")
            self?.appState.toggleContinuousRecording()
        }

        DebugLog.info("Hotkey callbacks configured!", context: "AppDelegate")
    }
}

// MARK: - Window Identifier Modifier
struct WindowIdentifierModifier: ViewModifier {
    let identifier: NSUserInterfaceItemIdentifier

    func body(content: Content) -> some View {
        content.background(WindowAccessor(identifier: identifier))
    }
}

struct WindowAccessor: NSViewRepresentable {
    let identifier: NSUserInterfaceItemIdentifier

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.identifier = identifier
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.identifier = identifier
    }
}

extension View {
    func windowIdentifier(_ identifier: NSUserInterfaceItemIdentifier) -> some View {
        modifier(WindowIdentifierModifier(identifier: identifier))
    }
}

@main
struct WhishpermateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    // MARK: - URL Handling

    private func handleURL(_ url: URL) {
        DebugLog.info("Received URL callback: \(url.absoluteString)", context: "WhispermateApp")

        // Handle authentication callback (whispermate://auth-callback)
        if url.scheme == "whispermate" && (url.host == "auth-callback" || url.host == "auth") {
            Task {
                await authManager.handleAuthCallback(url: url)
            }
        }
        // Handle payment success callback
        else if url.scheme == "whispermate" && url.host == "payment" && url.path == "/success" {
            Task {
                await subscriptionManager.handlePaymentSuccess()
            }
        }
        // Handle payment cancel callback
        else if url.scheme == "whispermate" && url.host == "payment" && url.path == "/cancel" {
            subscriptionManager.handlePaymentCancel()
        }
    }

    var body: some Scene {
        // Use Window instead of WindowGroup to prevent multiple instances
        Window("Whispermate", id: "main") {
            HistoryMasterDetailView()
                .onOpenURL { url in
                    handleURL(url)
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 600)
        .commands {
            // Replace default "Preferences" with our Settings
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            // Remove History command since it's now part of main window
            // Remove File > New Window command since we only want one main window
            CommandGroup(replacing: .newItem) { }
        }

        // Settings window
        Window("Settings", id: "settings") {
            SettingsWindowView()
                .windowIdentifier(WindowIdentifiers.settings)
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .defaultPosition(.center)
        .defaultSize(width: 1050, height: 825)
        .commandsRemoved()

        // Onboarding window
        Window("Welcome to Whispermate", id: "onboarding") {
            OnboardingView(
                onboardingManager: OnboardingManager.shared,
                hotkeyManager: HotkeyManager.shared,
                languageManager: LanguageManager(),
                promptRulesManager: PromptRulesManager.shared,
                llmProviderManager: LLMProviderManager()
            )
            .windowIdentifier(WindowIdentifiers.onboarding)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .defaultSize(width: 560, height: 520)
        .commandsRemoved()
    }
}
