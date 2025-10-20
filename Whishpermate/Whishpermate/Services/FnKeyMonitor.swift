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
        print("[FnKeyMonitor] ========================================")
        print("[FnKeyMonitor] STARTING Fn key monitoring")
        print("[FnKeyMonitor] Poll interval: \(pollInterval)s (~\(Int(1.0/pollInterval))Hz)")
        print("[FnKeyMonitor] Fn keyCode: 0x3F (63)")

        // Test if we can read the Fn key state right now
        let currentFnState = CGKeyCode.kVK_Function.isPressed
        print("[FnKeyMonitor] Current Fn key state (at start): \(currentFnState)")
        print("[FnKeyMonitor] CGEventSource test: \(CGEventSource.keyState(.combinedSessionState, key: CGKeyCode.kVK_Function))")
        print("[FnKeyMonitor] ========================================")

        stopMonitoring() // Stop any existing timer

        // Create a timer that fires on the main thread
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkFnKeyState()
        }

        // Ensure timer fires even during UI interactions
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
            print("[FnKeyMonitor] Timer created and added to RunLoop in .common mode")
        } else {
            print("[FnKeyMonitor] ERROR: Failed to create timer!")
        }
    }

    /// Stop monitoring the Fn key
    func stopMonitoring() {
        print("[FnKeyMonitor] Stopping Fn key monitoring")
        timer?.invalidate()
        timer = nil
        previousFnState = false
    }

    private var pollCount = 0

    private func checkFnKeyState() {
        pollCount += 1

        // Poll the current Fn key state using CGEventSource
        let isFnPressed = CGKeyCode.kVK_Function.isPressed

        // Show polling is happening (every 60 polls = ~1 second at 60Hz)
        if pollCount % 60 == 0 {
            print("[FnKeyMonitor] Polling active... (count: \(pollCount), current Fn state: \(isFnPressed))")
        }

        // Detect state transitions
        if isFnPressed && !previousFnState {
            // Fn key was just pressed
            print("[FnKeyMonitor] ⚡️ STATE CHANGE: Fn key PRESSED ⚡️")
            print("[FnKeyMonitor] Calling onFnPressed callback...")
            previousFnState = true
            onFnPressed?()
            print("[FnKeyMonitor] onFnPressed callback completed")
        } else if !isFnPressed && previousFnState {
            // Fn key was just released
            print("[FnKeyMonitor] ⚡️ STATE CHANGE: Fn key RELEASED ⚡️")
            print("[FnKeyMonitor] Calling onFnReleased callback...")
            previousFnState = false
            onFnReleased?()
            print("[FnKeyMonitor] onFnReleased callback completed")
        }
    }

    deinit {
        stopMonitoring()
    }
}
