//
//  WhishpermateApp.swift
//  Whishpermate
//
//  Created by Artsiom Vysotski on 10/16/25.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarManager = StatusBarManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarManager.setupMenuBar()

        // Set window reference after a brief delay to ensure window is created
        DispatchQueue.main.async { [weak self] in
            if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
                // Configure window to be completely borderless
                window.styleMask = [.borderless, .fullSizeContentView]
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = true
                window.hasShadow = true  // Enable native macOS window shadow
                window.backgroundColor = .clear  // Transparent background to show shadow

                self?.statusBarManager.appWindow = window
                print("[AppDelegate] Set status bar manager window reference and configured as borderless")
            }
        }
    }
}

@main
struct WhishpermateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
    }
}
