import AppKit
import SwiftUI
internal import Combine
import AVFoundation

enum OverlayPosition: String, CaseIterable, Codable {
    case top = "Top"
    case bottom = "Bottom"
}

/// Custom NSWindow that doesn't become key or main, preventing app activation on click
private class NonActivatingWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Manages the floating overlay window that shows recording state and audio visualization
class OverlayWindowManager: ObservableObject {
    static let shared = OverlayWindowManager()

    // MARK: - Keys

    private enum Keys {
        static let overlayPosition = "overlayPosition"
        static let hideIdleState = "hideIdleState"
    }

    // MARK: - Constants

    private enum Constants {
        static let stateChangeAnimationDelay: TimeInterval = 0.2
        static let positionPreviewDuration: TimeInterval = 2.0
        static let windowCreationDelay: TimeInterval = 0.05
        static let activeStateWidth: CGFloat = 95
        static let activeStateHeight: CGFloat = 24
        static let activePadding: CGFloat = 15
        static let idleStateWidth: CGFloat = 21
        static let idleStateHeight: CGFloat = 1
        static let idlePaddingHover: CGFloat = 8
        static let expandButtonSize: CGFloat = 17
        static let itemSpacing: CGFloat = 6
        static let edgeMargin: CGFloat = 2
        static let verticalPaddingActive: CGFloat = 4.5
        static let verticalPaddingIdle: CGFloat = 3
        static let frequencyBandCount: Int = 14
    }

    // MARK: - Published Properties (derived from overlayState for view compatibility)

    @Published var isRecording = false
    @Published var isProcessing = false

    @Published var audioLevel: Float = 0.0 {
        didSet {
            if Int(oldValue * 10) != Int(audioLevel * 10) {
                DebugLog.info("audioLevel changed: \(oldValue) -> \(audioLevel)", context: "OverlayWindowManager")
            }
        }
    }

    @Published var frequencyBands: [Float] = Array(repeating: 0.0, count: Constants.frequencyBandCount)
    @Published var isOverlayMode = true {
        didSet {
            DebugLog.info("isOverlayMode changed: \(oldValue) -> \(isOverlayMode)", context: "OverlayWindowManager")
        }
    }

    @Published var position: OverlayPosition = {
        if let savedRawValue = UserDefaults.standard.string(forKey: Keys.overlayPosition),
           let savedPosition = OverlayPosition(rawValue: savedRawValue)
        {
            return savedPosition
        }
        return .bottom
    }() {
        didSet {
            UserDefaults.standard.set(position.rawValue, forKey: Keys.overlayPosition)

            DispatchQueue.main.async { [weak self] in
                self?.repositionWindow()

                self?.showAlways()
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.positionPreviewDuration) { [weak self] in
                    if !(self?.isRecording ?? false), !(self?.isProcessing ?? false) {
                        self?.hide()
                    }
                }
            }
        }
    }

    @Published var hideIdleState: Bool = UserDefaults.standard.bool(forKey: Keys.hideIdleState) {
        didSet {
            UserDefaults.standard.set(hideIdleState, forKey: Keys.hideIdleState)

            // When hideIdleState changes and we're in idle state, update visibility
            if overlayState == .idle {
                transition(to: hideIdleState ? .hidden : .idle)
            }
        }
    }

    /// Is currently in command mode (recording voice instruction)
    @Published var isCommandMode: Bool = false

    // MARK: - Overlay State (single source of truth)

    enum OverlayState: Equatable {
        case hidden
        case idle
        case recording(isCommandMode: Bool)
        case processing(isCommandMode: Bool)
    }

    @Published private(set) var overlayState: OverlayState = .idle

    // MARK: - Private Properties

    private var overlayWindow: NSWindow?
    private var screenChangeObserver: Any?
    private var audioLevelCancellable: AnyCancellable?
    private var frequencyBandsCancellable: AnyCancellable?

    // MARK: - Initialization

    private init() {
        setupScreenChangeObserver()
        setupAudioObservers()
    }

    // MARK: - Public API

    func show() {
        DebugLog.info("show() called", context: "OverlayWindowManager")
        if overlayWindow == nil {
            createWindow()
        }
        overlayWindow?.orderFrontRegardless()
        DebugLog.info("Window ordered front", context: "OverlayWindowManager")
    }

    func hide() {
        DebugLog.info("hide() called", context: "OverlayWindowManager")
        overlayWindow?.orderOut(nil)
    }

    // MARK: - State Transitions (single entry point for all state changes)

    /// Transition to a new overlay state - single source of truth for state changes
    func transition(to newState: OverlayState) {
        DebugLog.info("transition: \(overlayState) -> \(newState)", context: "OverlayWindowManager")

        // Ensure we're on main thread for UI updates
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.transition(to: newState)
            }
            return
        }

        guard newState != overlayState else {
            DebugLog.info("transition: no-op, already in state \(newState)", context: "OverlayWindowManager")
            return
        }

        let previousState = overlayState
        overlayState = newState

        // Update derived properties for backward compatibility with views
        switch newState {
        case .hidden:
            isRecording = false
            isProcessing = false
            isCommandMode = false
            overlayWindow?.orderOut(nil)
            DebugLog.info("transition: window hidden", context: "OverlayWindowManager")

        case .idle:
            isRecording = false
            isProcessing = false
            isCommandMode = false
            ensureWindowExists()
            overlayWindow?.orderFrontRegardless()
            // If coming from active state, keep window large for collapse animation
            // View will call onCollapseAnimationComplete() when done
            let comingFromActive = previousState == .recording(isCommandMode: true) ||
                previousState == .recording(isCommandMode: false) ||
                previousState == .processing(isCommandMode: true) ||
                previousState == .processing(isCommandMode: false)
            if !comingFromActive {
                updateWindowSizeForState(newState, animated: false)
            }

        case let .recording(commandMode):
            isRecording = true
            isProcessing = false
            isCommandMode = commandMode
            ensureWindowExists()
            overlayWindow?.orderFrontRegardless()
            updateWindowSizeForState(newState, animated: true)

        case let .processing(commandMode):
            isRecording = false
            isProcessing = true
            isCommandMode = commandMode
            ensureWindowExists()
            overlayWindow?.orderFrontRegardless()
            updateWindowSizeForState(newState, animated: true)
        }
    }

    private func ensureWindowExists() {
        if overlayWindow == nil {
            createWindow()
        }
    }

    private func updateWindowSizeForState(_ state: OverlayState, animated: Bool) {
        guard let window = overlayWindow, let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let isActive = state == .recording(isCommandMode: true) ||
            state == .recording(isCommandMode: false) ||
            state == .processing(isCommandMode: true) ||
            state == .processing(isCommandMode: false)

        let (windowWidth, windowHeight): (CGFloat, CGFloat)
        if isActive {
            windowWidth = Constants.activeStateWidth + (Constants.activePadding * 2)
            windowHeight = Constants.activeStateHeight + (Constants.verticalPaddingActive * 2) + (Constants.edgeMargin * 2)
        } else {
            let maxWidth = Constants.idleStateWidth + (Constants.idlePaddingHover * 2) + Constants.itemSpacing + Constants.expandButtonSize
            windowWidth = maxWidth + 10
            windowHeight = max(Constants.idleStateHeight, Constants.expandButtonSize) + (Constants.verticalPaddingIdle * 2) + (Constants.edgeMargin * 2)
        }

        let (xPos, yPos) = calculatePosition(for: position, screenFrame: screenFrame, windowWidth: windowWidth, windowHeight: windowHeight)
        let newFrame = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)

        if animated {
            window.setFrame(newFrame, display: true, animate: false)
        } else {
            window.setFrame(newFrame, display: true)
        }
    }

    // MARK: - Legacy API (for backward compatibility during migration)

    func updateState(isRecording: Bool, isProcessing: Bool) {
        DebugLog.info("updateState called - isRecording: \(isRecording), isProcessing: \(isProcessing)", context: "OverlayWindowManager")

        if isRecording {
            transition(to: .recording(isCommandMode: isCommandMode))
        } else if isProcessing {
            transition(to: .processing(isCommandMode: isCommandMode))
        } else if hideIdleState {
            transition(to: .hidden)
        } else {
            transition(to: .idle)
        }
    }

    func showAlways() {
        DebugLog.info("showAlways() - initializing overlay", context: "OverlayWindowManager")
        show()
    }

    func expandToFullMode() {
        DebugLog.info("expandToFullMode() - bringing app to foreground", context: "OverlayWindowManager")
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func contractToOverlay() {
        DebugLog.info("contractToOverlay() - sending app to background", context: "OverlayWindowManager")
        if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
            window.orderOut(nil)
        }
        NSApp.hide(nil)
    }

    /// Called by the view when collapse animation completes
    func onCollapseAnimationComplete() {
        guard overlayState == .idle else { return }
        DebugLog.info("onCollapseAnimationComplete", context: "OverlayWindowManager")
        updateWindowSizeForState(.idle, animated: false)
        if hideIdleState {
            overlayWindow?.orderOut(nil)
        }
    }

    // MARK: - Private Methods

    private func setupAudioObservers() {
        // Only set up audio observers if microphone permission is already granted
        // This prevents triggering the permission dialog on app launch
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            return
        }

        // Observe AudioRecorder's audio level and frequency bands
        let audioRecorder = AudioRecorder.shared

        audioLevelCancellable = audioRecorder.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }

        frequencyBandsCancellable = audioRecorder.$frequencyBands
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bands in
                self?.frequencyBands = bands
            }
    }

    /// Call this after microphone permission is granted to set up audio observers
    func initializeAudioObservers() {
        guard audioLevelCancellable == nil else { return }
        setupAudioObservers()
    }

    private func createWindow() {
        DebugLog.info("Creating overlay window", context: "OverlayWindowManager")

        guard let screen = NSScreen.main else {
            DebugLog.info("ERROR: Could not get main screen", context: "OverlayWindowManager")
            return
        }

        let screenFrame = screen.visibleFrame
        // Use idle size for initial window creation
        let maxWidth = Constants.idleStateWidth + (Constants.idlePaddingHover * 2) + Constants.itemSpacing + Constants.expandButtonSize
        let windowWidth = maxWidth + 10
        let windowHeight = max(Constants.idleStateHeight, Constants.expandButtonSize) + (Constants.verticalPaddingIdle * 2) + (Constants.edgeMargin * 2)

        // Calculate position based on selected position
        let (xPos, yPos) = calculatePosition(for: position, screenFrame: screenFrame, windowWidth: windowWidth, windowHeight: windowHeight)

        let windowFrame = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)

        // Create window using custom non-activating window class
        let window = NonActivatingWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window to float on top
        window.level = NSWindow.Level.floating // Float above most windows
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.ignoresMouseEvents = false // Allow mouse events for hover and clicks
        window.collectionBehavior = [NSWindow.CollectionBehavior.canJoinAllSpaces, NSWindow.CollectionBehavior.stationary, NSWindow.CollectionBehavior.ignoresCycle]

        // Prevent clicking from activating the app or bringing other windows forward
        window.hidesOnDeactivate = false

        // Create SwiftUI view that observes this manager
        let contentView = RecordingOverlayView(manager: self)
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = window.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]

        window.contentView = hosting
        overlayWindow = window

        DebugLog.info("Created hosting view with manager observation", context: "OverlayWindowManager")
        DebugLog.info("Window created at position: (\(xPos), \(yPos)), level: \(window.level.rawValue)", context: "OverlayWindowManager")
    }

    private func setupScreenChangeObserver() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DebugLog.info("Screen configuration changed, repositioning overlay", context: "OverlayWindowManager")
            self?.repositionWindow()
        }
    }

    private func repositionWindow() {
        guard overlayWindow != nil else {
            DebugLog.info("Cannot reposition - window not available", context: "OverlayWindowManager")
            return
        }
        updateWindowSizeForState(overlayState, animated: false)
    }

    private func calculatePosition(for position: OverlayPosition, screenFrame: NSRect, windowWidth: CGFloat, windowHeight: CGFloat) -> (x: CGFloat, y: CGFloat) {
        let padding: CGFloat = 0 // Distance from edge

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

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        overlayWindow?.close()
    }
}
