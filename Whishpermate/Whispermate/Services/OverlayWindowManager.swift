import AppKit
import SwiftUI
internal import Combine

enum OverlayPosition: String, CaseIterable, Codable {
    case top = "Top"
    case bottom = "Bottom"
}

class OverlayWindowManager: ObservableObject {
    static let shared = OverlayWindowManager()

    private var overlayWindow: NSWindow?
    private var screenChangeObserver: Any?

    @Published var isRecording = false {
        didSet {
            print("[OverlayWindowManager LOG] ⚡️ isRecording changed: \(oldValue) -> \(isRecording)")
            if isRecording {
                // Expand immediately when starting
                updateWindowSize()
            } else {
                // Delay contraction to let pill animation finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.updateWindowSize()
                }
            }
        }
    }
    @Published var isProcessing = false {
        didSet {
            print("[OverlayWindowManager LOG] ⚡️ isProcessing changed: \(oldValue) -> \(isProcessing)")
            if isProcessing {
                // Expand immediately when starting
                updateWindowSize()
            } else {
                // Delay contraction to let pill animation finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.updateWindowSize()
                }
            }
        }
    }
    @Published var audioLevel: Float = 0.0 {
        didSet {
            if Int(oldValue * 10) != Int(audioLevel * 10) {  // Only log significant changes
                print("[OverlayWindowManager LOG] ⚡️ audioLevel changed: \(oldValue) -> \(audioLevel)")
            }
        }
    }
    @Published var frequencyBands: [Float] = Array(repeating: 0.0, count: 14)
    @Published var isOverlayMode = true {  // Start in overlay mode by default
        didSet {
            print("[OverlayWindowManager LOG] ⚡️ isOverlayMode changed: \(oldValue) -> \(isOverlayMode)")
        }
    }

    @Published var position: OverlayPosition = {
        if let savedRawValue = UserDefaults.standard.string(forKey: "overlayPosition"),
           let savedPosition = OverlayPosition(rawValue: savedRawValue) {
            return savedPosition
        }
        return .bottom
    }() {
        didSet {
            UserDefaults.standard.set(position.rawValue, forKey: "overlayPosition")

            // Defer state changes to avoid publishing during view updates
            DispatchQueue.main.async { [weak self] in
                self?.repositionWindow()

                // Briefly show overlay so user can see the new position
                self?.showAlways()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    // Hide after 2 seconds if not recording/processing
                    if !(self?.isRecording ?? false) && !(self?.isProcessing ?? false) {
                        self?.hide()
                    }
                }
            }
        }
    }

    @Published var hideIdleState: Bool = {
        return UserDefaults.standard.bool(forKey: "hideIdleState")
    }() {
        didSet {
            UserDefaults.standard.set(hideIdleState, forKey: "hideIdleState")

            // Defer state changes to avoid publishing during view updates
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Update overlay visibility based on new setting
                if self.hideIdleState && !self.isRecording && !self.isProcessing {
                    self.hide()
                } else if !self.hideIdleState && !self.isRecording && !self.isProcessing {
                    self.show()
                }
            }
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

            // Show overlay when recording/processing, respect hideIdleState when idle
            if isRecording || isProcessing {
                // Always show when actively recording/processing
                if self.overlayWindow == nil {
                    print("[OverlayWindowManager LOG] updateState - overlay window is nil, showing...")
                }
                self.show()
            } else if self.hideIdleState {
                // Hide when idle if hideIdleState is enabled
                self.hide()
            } else {
                // Show idle state
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

        // Calculate position based on selected position
        let (xPos, yPos) = calculatePosition(for: position, screenFrame: screenFrame, windowWidth: windowWidth, windowHeight: windowHeight)

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

        // Calculate position based on selected position
        let (xPos, yPos) = calculatePosition(for: position, screenFrame: screenFrame, windowWidth: windowWidth, windowHeight: windowHeight)

        let newFrame = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        window.setFrame(newFrame, display: true)

        print("[OverlayWindowManager LOG] ✅ Repositioned to: (\(xPos), \(yPos))")
    }

    private func calculatePosition(for position: OverlayPosition, screenFrame: NSRect, windowWidth: CGFloat, windowHeight: CGFloat) -> (x: CGFloat, y: CGFloat) {
        let padding: CGFloat = 0  // Distance from edge

        switch position {
        case .bottom:
            let x = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
            let y = screenFrame.origin.y + padding
            return (x, y)
        case .top:
            let x = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
            let y = screenFrame.origin.y + screenFrame.height - windowHeight - padding
            return (x, y)
        }
    }

    private func getWindowSize() -> (width: CGFloat, height: CGFloat) {
        // Window size constants that match RecordingOverlayView
        let activeStateWidth: CGFloat = 95  // Narrow for 14 bars
        let activeStateHeight: CGFloat = 24
        let activePadding: CGFloat = 15

        let idleStateWidth: CGFloat = 21
        let idleStateHeight: CGFloat = 1
        let idlePaddingHover: CGFloat = 8
        let expandButtonSize: CGFloat = 17
        let itemSpacing: CGFloat = 6

        let edgeMargin: CGFloat = 2  // Bottom/top margin
        let verticalPaddingActive: CGFloat = 4.5
        let verticalPaddingIdle: CGFloat = 3

        if isRecording || isProcessing {
            // Active state: content + padding
            let width = activeStateWidth + (activePadding * 2)
            let height = activeStateHeight + (verticalPaddingActive * 2) + (edgeMargin * 2)
            return (width, height)
        } else {
            // Idle state: need room for hover animation (button appears)
            // Hover: idleWidth + hoverPadding*2 + spacing + buttonSize
            let maxWidth = idleStateWidth + (idlePaddingHover * 2) + itemSpacing + expandButtonSize
            let width = maxWidth + 10  // Extra room for smooth animation
            let height = max(idleStateHeight, expandButtonSize) + (verticalPaddingIdle * 2) + (edgeMargin * 2)
            return (width, height)
        }
    }

    private func updateWindowSize() {
        guard let window = overlayWindow, let screen = NSScreen.main else {
            return
        }

        let screenFrame = screen.visibleFrame
        let (windowWidth, windowHeight) = getWindowSize()

        // Calculate position based on selected position
        let (xPos, yPos) = calculatePosition(for: position, screenFrame: screenFrame, windowWidth: windowWidth, windowHeight: windowHeight)

        let newFrame = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)

        // Resize window instantly (no animation) to prevent clipping the SwiftUI content animation
        window.setFrame(newFrame, display: true, animate: false)

        print("[OverlayWindowManager LOG] 📐 Window resized instantly to: \(windowWidth)×\(windowHeight)")
    }

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        overlayWindow?.close()
    }
}
