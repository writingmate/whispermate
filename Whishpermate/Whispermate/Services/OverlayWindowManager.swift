import AppKit
import SwiftUI
internal import Combine
import AVFoundation

enum OverlayPosition: String, CaseIterable, Codable {
    case top = "Top"
    case bottom = "Bottom"
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

    // MARK: - Published Properties

    @Published var isRecording = false {
        didSet {
            DebugLog.info("isRecording changed: \(oldValue) -> \(isRecording)", context: "OverlayWindowManager")
            if isRecording {
                updateWindowSize()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.stateChangeAnimationDelay) { [weak self] in
                    self?.updateWindowSize()
                }
            }
        }
    }

    @Published var isProcessing = false {
        didSet {
            DebugLog.info("isProcessing changed: \(oldValue) -> \(isProcessing)", context: "OverlayWindowManager")
            if isProcessing {
                updateWindowSize()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.stateChangeAnimationDelay) { [weak self] in
                    self?.updateWindowSize()
                }
            }
        }
    }

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

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.hideIdleState, !self.isRecording, !self.isProcessing {
                    self.hide()
                } else if !self.hideIdleState, !self.isRecording, !self.isProcessing {
                    self.show()
                }
            }
        }
    }

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

    func updateState(isRecording: Bool, isProcessing: Bool) {
        DebugLog.info("updateState called - isRecording: \(isRecording), isProcessing: \(isProcessing)", context: "OverlayWindowManager")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if isRecording || isProcessing {
                if self.overlayWindow == nil {
                    DebugLog.info("updateState - overlay window is nil, creating...", context: "OverlayWindowManager")
                    self.show()
                    DispatchQueue.main.asyncAfter(deadline: .now() + Constants.windowCreationDelay) { [weak self] in
                        DebugLog.info("updateState - setting isRecording: \(isRecording), isProcessing: \(isProcessing)", context: "OverlayWindowManager")
                        self?.isRecording = isRecording
                        self?.isProcessing = isProcessing
                    }
                    return
                }
                self.show()
            } else if self.hideIdleState {
                self.hide()
            } else {
                self.show()
            }

            DebugLog.info("updateState - setting isRecording: \(isRecording), isProcessing: \(isProcessing)", context: "OverlayWindowManager")
            self.isRecording = isRecording
            self.isProcessing = isProcessing
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
        guard let window = overlayWindow, let screen = NSScreen.main else {
            DebugLog.info("Cannot reposition - window or screen not available", context: "OverlayWindowManager")
            return
        }

        let screenFrame = screen.visibleFrame
        let (windowWidth, windowHeight) = getWindowSize()
        let (xPos, yPos) = calculatePosition(for: position, screenFrame: screenFrame, windowWidth: windowWidth, windowHeight: windowHeight)

        let newFrame = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        window.setFrame(newFrame, display: true)

        DebugLog.info("Repositioned to: (\(xPos), \(yPos))", context: "OverlayWindowManager")
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

    private func getWindowSize() -> (width: CGFloat, height: CGFloat) {
        if isRecording || isProcessing {
            let width = Constants.activeStateWidth + (Constants.activePadding * 2)
            let height = Constants.activeStateHeight + (Constants.verticalPaddingActive * 2) + (Constants.edgeMargin * 2)
            return (width, height)
        } else {
            let maxWidth = Constants.idleStateWidth + (Constants.idlePaddingHover * 2) + Constants.itemSpacing + Constants.expandButtonSize
            let width = maxWidth + 10
            let height = max(Constants.idleStateHeight, Constants.expandButtonSize) + (Constants.verticalPaddingIdle * 2) + (Constants.edgeMargin * 2)
            return (width, height)
        }
    }

    private func updateWindowSize() {
        guard let window = overlayWindow, let screen = NSScreen.main else {
            return
        }

        let screenFrame = screen.visibleFrame
        let (windowWidth, windowHeight) = getWindowSize()
        let (xPos, yPos) = calculatePosition(for: position, screenFrame: screenFrame, windowWidth: windowWidth, windowHeight: windowHeight)

        let newFrame = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        window.setFrame(newFrame, display: true, animate: false)

        DebugLog.info("Window resized to: \(windowWidth)×\(windowHeight)", context: "OverlayWindowManager")
    }

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        overlayWindow?.close()
    }
}
