//
//  WhishpermateApp.swift
//  Whishpermate
//
//  Created by Artsiom Vysotski on 10/16/25.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarManager = StatusBarManager()
    var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarManager.setupMenuBar()

        // Configure window immediately - no async delay
        configureMainWindow()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure window is always properly configured when app becomes active
        if mainWindow == nil {
            configureMainWindow()
        }
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

        // Configure window to be completely borderless
        window.styleMask = [.borderless, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.hasShadow = true  // Explicitly enable shadow
        window.invalidateShadow()  // Force shadow recalculation

        // Prevent window from being released when closed
        window.isReleasedWhenClosed = false

        mainWindow = window
        statusBarManager.appWindow = window
        DebugLog.info("Main window configured as borderless with shadow", context: "AppDelegate")
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

        // History window
        Window("History", id: "history") {
            HistoryWindowView()
        }
        .windowResizability(.contentSize)
    }
}
