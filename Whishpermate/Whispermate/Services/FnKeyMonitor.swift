import AppKit
import CoreGraphics
import Foundation

/// Monitors the Fn key state using NSEvent.flagsChanged
/// This works globally (even when app is in background)
class FnKeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var previousFnState = false
    private var suppressUntil: Date?

    private enum Constants {
        static let suppressionDuration: TimeInterval = 0.5
    }

    var onFnPressed: (() -> Void)?
    var onFnReleased: (() -> Void)?

    /// Temporarily suppress Fn key detection (e.g., after simulated paste to avoid spurious events)
    func suppressTemporarily() {
        suppressUntil = Date().addingTimeInterval(Constants.suppressionDuration)
        DebugLog.info("Suppressing Fn detection for \(Constants.suppressionDuration)s", context: "FnKeyMonitor")
    }

    /// Start monitoring the Fn key state
    func startMonitoring(pollInterval _: TimeInterval = 0.016) {
        DebugLog.info("========================================", context: "FnKeyMonitor")
        DebugLog.info("STARTING Fn key monitoring", context: "FnKeyMonitor")
        DebugLog.info("Using NSEvent.flagsChanged monitoring", context: "FnKeyMonitor")
        DebugLog.info("========================================", context: "FnKeyMonitor")

        stopMonitoring() // Stop any existing monitors

        // Monitor global flags changed events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // Monitor local flags changed events
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        DebugLog.info("Fn key monitors registered", context: "FnKeyMonitor")
    }

    /// Stop monitoring the Fn key
    func stopMonitoring() {
        DebugLog.info("Stopping Fn key monitoring", context: "FnKeyMonitor")

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        previousFnState = false
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let isFnPressed = event.modifierFlags.contains(.function)
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Log all events for debugging
        DebugLog.info("handleFlagsChanged: keyCode=\(keyCode), isFnPressed=\(isFnPressed), modifiers=\(modifiers.rawValue)", context: "FnKeyMonitor")

        // Check if suppression is active (e.g., right after a paste operation)
        if let suppressUntil = suppressUntil, Date() < suppressUntil {
            DebugLog.info("Fn detection suppressed (until \(suppressUntil)), ignoring event", context: "FnKeyMonitor")
            return
        }

        // Only respond to actual Fn key events (keyCode 63 or 179/globe key)
        // AND only if no other modifiers are pressed (to filter out synthetic events from paste)
        let isFnKeyCode = keyCode == 63 || keyCode == 179
        let hasOtherModifiers = modifiers.contains(.command) || modifiers.contains(.option) ||
                                modifiers.contains(.control) || modifiers.contains(.shift)

        guard isFnKeyCode && !hasOtherModifiers else {
            // Not a pure Fn key event, ignore
            return
        }

        DebugLog.info("Pure Fn key event detected, previousFnState=\(previousFnState)", context: "FnKeyMonitor")

        // Detect state transitions
        if isFnPressed, !previousFnState {
            // Fn key was just pressed
            DebugLog.info("⚡️ STATE CHANGE: Fn key PRESSED ⚡️", context: "FnKeyMonitor")
            DebugLog.info("Calling onFnPressed callback...", context: "FnKeyMonitor")
            previousFnState = true
            onFnPressed?()
            DebugLog.info("onFnPressed callback completed", context: "FnKeyMonitor")
        } else if !isFnPressed, previousFnState {
            // Fn key was just released
            DebugLog.info("⚡️ STATE CHANGE: Fn key RELEASED ⚡️", context: "FnKeyMonitor")
            DebugLog.info("Calling onFnReleased callback...", context: "FnKeyMonitor")
            previousFnState = false
            onFnReleased?()
            DebugLog.info("onFnReleased callback completed", context: "FnKeyMonitor")
        }
    }

    deinit {
        stopMonitoring()
    }
}
