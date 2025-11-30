import AppKit
import SwiftUI

struct HoldToRecordButton: View {
    let isRecording: Bool
    let isProcessing: Bool
    let onPressDown: () -> Void
    let onPressUp: () -> Void

    var body: some View {
        HoldButtonView(
            isRecording: isRecording,
            isProcessing: isProcessing,
            onPressDown: onPressDown,
            onPressUp: onPressUp
        )
    }
}

struct HoldButtonView: NSViewRepresentable {
    let isRecording: Bool
    let isProcessing: Bool
    let onPressDown: () -> Void
    let onPressUp: () -> Void

    func makeNSView(context _: Context) -> HoldButton {
        let button = HoldButton()
        button.onPressDown = onPressDown
        button.onPressUp = onPressUp
        return button
    }

    func updateNSView(_ nsView: HoldButton, context _: Context) {
        nsView.isRecording = isRecording
        nsView.isProcessing = isProcessing
        nsView.needsDisplay = true
    }
}

class HoldButton: NSView {
    var onPressDown: (() -> Void)?
    var onPressUp: (() -> Void)?

    var isRecording = false
    var isProcessing = false
    private var isPressed = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Background color - prioritize local press state to prevent flicker
        let backgroundColor: NSColor
        if isProcessing {
            backgroundColor = NSColor.gray
        } else if isPressed || isRecording {
            // Show as pressed/recording regardless of external state during hold
            backgroundColor = NSColor.systemRed
        } else {
            backgroundColor = NSColor.systemBlue
        }

        backgroundColor.setFill()
        bounds.fill()

        // Draw text and icon
        let text: String
        let iconName: String

        if isPressed || isRecording {
            text = "Release to Stop"
            iconName = "stop.circle.fill"
        } else {
            text = "Hold to Record"
            iconName = "mic.circle.fill"
        }

        // Draw icon
        if let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let iconSize: CGFloat = 20
            let iconRect = NSRect(
                x: bounds.midX - 60,
                y: bounds.midY - iconSize / 2,
                width: iconSize,
                height: iconSize
            )
            icon.draw(in: iconRect)
        }

        // Draw text
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        ]
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: bounds.midX - 30,
            y: bounds.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
    }

    override func mouseDown(with _: NSEvent) {
        guard !isProcessing else { return }

        isPressed = true
        needsDisplay = true
        onPressDown?()
    }

    override func mouseUp(with _: NSEvent) {
        guard isPressed else { return }

        isPressed = false
        needsDisplay = true
        onPressUp?()
    }

    override func mouseDragged(with _: NSEvent) {
        // Keep the button pressed state while dragging
        // This prevents flickering if the mouse moves slightly
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeInKeyWindow,
        ]
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
}
