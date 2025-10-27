import AppKit
import SwiftUI
internal import Combine

class OverlayWindowManager: ObservableObject {
    private var overlayWindow: NSWindow?
    private var screenChangeObserver: Any?

    @Published var isRecording = false {
        didSet {
            print("[OverlayWindowManager LOG] ⚡️ isRecording changed: \(oldValue) -> \(isRecording)")
            updateWindowSize()
        }
    }
    @Published var isProcessing = false {
        didSet {
            print("[OverlayWindowManager LOG] ⚡️ isProcessing changed: \(oldValue) -> \(isProcessing)")
            updateWindowSize()
        }
    }
    @Published var audioLevel: Float = 0.0 {
        didSet {
            if Int(oldValue * 10) != Int(audioLevel * 10) {  // Only log significant changes
                print("[OverlayWindowManager LOG] ⚡️ audioLevel changed: \(oldValue) -> \(audioLevel)")
            }
        }
    }
    @Published var isOverlayMode = true {  // Start in overlay mode by default
        didSet {
            print("[OverlayWindowManager LOG] ⚡️ isOverlayMode changed: \(oldValue) -> \(isOverlayMode)")
        }
    }

    init() {
        setupScreenChangeObserver()
    }

    func show() {
        print("[OverlayWindowManager LOG] show() called")

        if overlayWindow == nil {
            createWindow()
        }

        overlayWindow?.orderFrontRegardless()
        print("[OverlayWindowManager LOG] Window ordered front")
    }

    func hide() {
        print("[OverlayWindowManager LOG] hide() called")
        overlayWindow?.orderOut(nil)
    }

    func updateState(isRecording: Bool, isProcessing: Bool) {
        print("[OverlayWindowManager LOG] updateState called - isRecording: \(isRecording), isProcessing: \(isProcessing)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("[OverlayWindowManager LOG] updateState main thread - setting isRecording: \(isRecording), isProcessing: \(isProcessing)")
            self.isRecording = isRecording
            self.isProcessing = isProcessing

            // Always keep the overlay visible (it just changes size/state)
            if self.overlayWindow == nil {
                print("[OverlayWindowManager LOG] updateState - overlay window is nil, showing...")
                self.show()
            }
        }
    }

    func showAlways() {
        print("[OverlayWindowManager LOG] showAlways() - initializing overlay")
        show()
    }

    func expandToFullMode() {
        print("[OverlayWindowManager LOG] expandToFullMode() - bringing app to foreground")

        // Bring app to foreground - this will trigger didBecomeActive notification
        // which will handle the mode switch
        NSApp.activate(ignoringOtherApps: true)

        // Show main window
        if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func contractToOverlay() {
        print("[OverlayWindowManager LOG] contractToOverlay() - sending app to background")

        // Hide main window which effectively sends app to background
        if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
            window.orderOut(nil)
        }

        // Hide the app (send to background) - this will trigger didResignActive notification
        // which will handle the mode switch
        NSApp.hide(nil)
    }

    private func createWindow() {
        print("[OverlayWindowManager LOG] Creating overlay window")

        // Get screen dimensions
        guard let screen = NSScreen.main else {
            print("[OverlayWindowManager LOG] ERROR: Could not get main screen")
            return
        }

        let screenFrame = screen.visibleFrame
        let (windowWidth, windowHeight) = getWindowSize()

        // Position at bottom center (very close to bottom)
        let xPos = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        let yPos = screenFrame.origin.y + 0 // 0 points from bottom - at the very edge!

        let windowFrame = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)

        // Create window
        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window to float on top
        window.level = .floating // Float above most windows
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false // Allow mouse events for hover and clicks
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // Create SwiftUI view that observes this manager
        let contentView = RecordingOverlayView(manager: self)
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = window.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]

        window.contentView = hosting
        self.overlayWindow = window

        print("[OverlayWindowManager LOG] ✅ Created hosting view with manager observation")

        print("[OverlayWindowManager LOG] Window created at position: (\(xPos), \(yPos))")
        print("[OverlayWindowManager LOG] Window level: \(window.level.rawValue)")
    }

    private func setupScreenChangeObserver() {
        // Observe screen configuration changes (resolution, display arrangement, etc.)
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[OverlayWindowManager LOG] 🖥️ Screen configuration changed, repositioning overlay")
            self?.repositionWindow()
        }
    }

    private func repositionWindow() {
        guard let window = overlayWindow, let screen = NSScreen.main else {
            print("[OverlayWindowManager LOG] Cannot reposition - window or screen not available")
            return
        }

        let screenFrame = screen.visibleFrame
        let (windowWidth, windowHeight) = getWindowSize()

        // Position at bottom center
        let xPos = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        let yPos = screenFrame.origin.y + 0

        let newFrame = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        window.setFrame(newFrame, display: true)

        print("[OverlayWindowManager LOG] ✅ Repositioned to: (\(xPos), \(yPos))")
    }

    private func getWindowSize() -> (width: CGFloat, height: CGFloat) {
        // Large size for recording/processing states
        if isRecording || isProcessing {
            return (210, 52)
        }
        // Small size for idle state
        return (70, 42)
    }

    private func updateWindowSize() {
        guard let window = overlayWindow, let screen = NSScreen.main else {
            return
        }

        let screenFrame = screen.visibleFrame
        let (windowWidth, windowHeight) = getWindowSize()

        // Keep centered at bottom
        let xPos = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        let yPos = screenFrame.origin.y + 0

        let newFrame = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)

        // Animate window resize with spring timing (synchronized with SwiftUI content animations)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 1.0, 0.89, 1.0) // Spring curve
            context.allowsImplicitAnimation = true
            window.animator().setFrame(newFrame, display: true)
        }, completionHandler: nil)

        print("[OverlayWindowManager LOG] 📐 Window animating resize to: \(windowWidth)×\(windowHeight)")
    }

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        overlayWindow?.close()
    }
}
