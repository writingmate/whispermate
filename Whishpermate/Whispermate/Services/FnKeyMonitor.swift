import Foundation
import CoreGraphics
import AppKit

/// Monitors the Fn key state using NSEvent.flagsChanged
/// This works globally (even when app is in background)
class FnKeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var previousFnState = false

    var onFnPressed: (() -> Void)?
    var onFnReleased: (() -> Void)?

    /// Start monitoring the Fn key state
    func startMonitoring(pollInterval: TimeInterval = 0.016) {
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

        // Detect state transitions
        if isFnPressed && !previousFnState {
            // Fn key was just pressed
            DebugLog.info("⚡️ STATE CHANGE: Fn key PRESSED ⚡️", context: "FnKeyMonitor")
            DebugLog.info("Calling onFnPressed callback...", context: "FnKeyMonitor")
            previousFnState = true
            onFnPressed?()
            DebugLog.info("onFnPressed callback completed", context: "FnKeyMonitor")
        } else if !isFnPressed && previousFnState {
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
