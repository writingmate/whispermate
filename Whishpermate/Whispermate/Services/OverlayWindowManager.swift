import AppKit
import SwiftUI
internal import Combine

class OverlayWindowManager: ObservableObject {
    private var overlayWindow: NSWindow?
    @Published var isRecording = false
    @Published var isProcessing = false

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
        print("[OverlayWindowManager LOG] updateState - isRecording: \(isRecording), isProcessing: \(isProcessing)")

        DispatchQueue.main.async { [weak self] in
            self?.isRecording = isRecording
            self?.isProcessing = isProcessing

            // Always keep the overlay visible (it just changes size/state)
            if self?.overlayWindow == nil {
                self?.show()
            }
        }
    }

    func showAlways() {
        print("[OverlayWindowManager LOG] showAlways() - initializing overlay")
        show()
    }

    private func createWindow() {
        print("[OverlayWindowManager LOG] Creating overlay window")

        // Get screen dimensions
        guard let screen = NSScreen.main else {
            print("[OverlayWindowManager LOG] ERROR: Could not get main screen")
            return
        }

        let screenFrame = screen.visibleFrame
        let windowWidth: CGFloat = 300
        let windowHeight: CGFloat = 60

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
        window.ignoresMouseEvents = true // Click-through
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // Create SwiftUI view that observes this manager
        let contentView = RecordingOverlayView(manager: self)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        window.contentView = hostingView

        self.overlayWindow = window

        print("[OverlayWindowManager LOG] Window created at position: (\(xPos), \(yPos))")
        print("[OverlayWindowManager LOG] Window level: \(window.level.rawValue)")
    }

    deinit {
        overlayWindow?.close()
    }
}
