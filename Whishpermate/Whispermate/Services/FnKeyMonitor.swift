import Foundation
import CoreGraphics

/// Monitors the Fn key state using polling instead of event monitoring
/// This works globally (even when app is in background) because it uses CGEventSource.keyState
class FnKeyMonitor {
    private var timer: Timer?
    private var previousFnState = false

    var onFnPressed: (() -> Void)?
    var onFnReleased: (() -> Void)?

    /// Start monitoring the Fn key state
    /// - Parameter pollInterval: How often to check the key state (default: 0.016 seconds = ~60Hz)
    func startMonitoring(pollInterval: TimeInterval = 0.016) {
        DebugLog.info("========================================", context: "FnKeyMonitor")
        DebugLog.info("STARTING Fn key monitoring", context: "FnKeyMonitor")
        DebugLog.info("Poll interval: \(pollInterval)s (~\(Int(1.0/pollInterval))Hz)", context: "FnKeyMonitor")
        DebugLog.info("Fn keyCode: 0x3F (63)", context: "FnKeyMonitor")

        // Test if we can read the Fn key state right now
        let currentFnState = CGKeyCode.kVK_Function.isPressed
        DebugLog.info("Current Fn key state (at start): \(currentFnState)", context: "FnKeyMonitor")
        DebugLog.info("CGEventSource test: \(CGEventSource.keyState(.combinedSessionState, key: CGKeyCode.kVK_Function))", context: "FnKeyMonitor")
        DebugLog.info("========================================", context: "FnKeyMonitor")

        stopMonitoring() // Stop any existing timer

        // Create a timer that fires on the main thread
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkFnKeyState()
        }

        // Ensure timer fires even during UI interactions
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
            DebugLog.info("Timer created and added to RunLoop in .common mode", context: "FnKeyMonitor")
        } else {
            DebugLog.info("ERROR: Failed to create timer!", context: "FnKeyMonitor")
        }
    }

    /// Stop monitoring the Fn key
    func stopMonitoring() {
        DebugLog.info("Stopping Fn key monitoring", context: "FnKeyMonitor")
        timer?.invalidate()
        timer = nil
        previousFnState = false
    }

    private var pollCount = 0
    private var consecutiveTrueCount = 0
    private let stuckThreshold = 180 // 3 seconds at 60Hz - reset if stuck

    private func checkFnKeyState() {
        pollCount += 1

        // Poll the current Fn key state using CGEventSource
        let isFnPressed = CGKeyCode.kVK_Function.isPressed

        // Track consecutive true readings - CGEventSource can get stuck reporting true
        if isFnPressed {
            consecutiveTrueCount += 1
        } else {
            consecutiveTrueCount = 0
        }

        // If we've seen true for too long, assume it's stuck and reset
        if consecutiveTrueCount >= stuckThreshold {
            DebugLog.info("⚠️ Fn key appears stuck at 'true' - resetting state", context: "FnKeyMonitor")
            previousFnState = false
            consecutiveTrueCount = 0
            return
        }

        // Show polling is happening (every 60 polls = ~1 second at 60Hz)
        if pollCount % 60 == 0 {
            DebugLog.info("Polling active... (count: \(pollCount), current Fn state: \(isFnPressed))", context: "FnKeyMonitor")
        }

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
