import SwiftUI
import WhisperMateShared

struct RecordingOverlayView: View {
    @ObservedObject var manager: OverlayWindowManager
    @State private var isHovering = false
    @State private var shouldShowExpandedPill = false
    @State private var shouldShowContent = false

    // MARK: - Size Constants (single source of truth)

    // Recording/Processing state
    private let activeStateWidth: CGFloat = 95  // Narrow for 14 bars
    private let activeStateHeight: CGFloat = 24

    // Idle state
    private let idleStateWidth: CGFloat = 21
    private let idleStateHeight: CGFloat = 1

    // Expand button
    private let expandButtonSize: CGFloat = 17

    // Spacing and padding
    private let itemSpacing: CGFloat = 6
    private let activePadding: CGFloat = 15
    private let idlePaddingNormal: CGFloat = 16
    private let idlePaddingHover: CGFloat = 8
    private let edgeMargin: CGFloat = 2

    // MARK: - Computed Properties

    private var horizontalPadding: CGFloat {
        if manager.isRecording || manager.isProcessing { return activePadding }
        return isHovering ? idlePaddingHover : idlePaddingNormal
    }

    private var verticalPadding: CGFloat {
        manager.isRecording || manager.isProcessing ? 4.5 : 3
    }

    private var backgroundColor: Color {
        if manager.isRecording { return .accentColor.opacity(0.9) }
        if manager.isProcessing { return .accentColor }
        return .gray.opacity(0.6)
    }

    private var shouldShowExpandButton: Bool {
        isHovering && !manager.isRecording && !manager.isProcessing
    }

    // MARK: - Body

    var body: some View {
        let _ = print("[RecordingOverlayView] 🎨 body rendering - isRecording: \(manager.isRecording), isProcessing: \(manager.isProcessing), audioLevel: \(manager.audioLevel)")

        return GeometryReader { geometry in
            // Position content absolutely to prevent Spacer from compressing
            ZStack(alignment: manager.position == .top ? .top : .bottom) {
                overlayContent(geometry: geometry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        .onChange(of: manager.isRecording) { newValue in
            if newValue {
                // Only animate if we're coming from idle state
                if !shouldShowExpandedPill {
                    shouldShowExpandedPill = false
                    shouldShowContent = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            shouldShowExpandedPill = true
                        }
                        // Show content after expansion animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            shouldShowContent = true
                        }
                    }
                }
            } else if !manager.isProcessing {
                // Hide content immediately, then collapse
                shouldShowContent = false
                withAnimation(.easeOut(duration: 0.15)) {
                    shouldShowExpandedPill = false
                }
            }
        }
        .onChange(of: manager.isProcessing) { newValue in
            if newValue {
                // Only animate if we're coming from idle state (not from recording)
                if !manager.isRecording && !shouldShowExpandedPill {
                    shouldShowExpandedPill = false
                    shouldShowContent = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            shouldShowExpandedPill = true
                        }
                        // Show content after expansion animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            shouldShowContent = true
                        }
                    }
                } else if manager.isRecording {
                    // Already expanded from recording, just keep expanded and keep showing content
                    shouldShowExpandedPill = true
                    shouldShowContent = true
                }
            } else if !manager.isRecording {
                shouldShowContent = false
                withAnimation(.easeOut(duration: 0.15)) {
                    shouldShowExpandedPill = false
                }
            }
        }
    }

    @ViewBuilder
    private func overlayContent(geometry: GeometryProxy) -> some View {
        // Horizontal layout for top/bottom positions
        HStack(spacing: itemSpacing) {
            contentView

            if shouldShowExpandButton {
                expandButton
                    .padding(.trailing, -5) // Negative padding to compensate for capsule radius
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Capsule()
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        )
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .center) // Center horizontally only
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .padding(manager.position == .top ? .top : .bottom, edgeMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: manager.position == .top ? .top : .bottom) // Position vertically
    }

    // MARK: - Subviews

    @ViewBuilder
    private var contentView: some View {
        let targetWidth = shouldShowExpandedPill ? activeStateWidth : idleStateWidth
        let targetHeight = shouldShowExpandedPill ? activeStateHeight : idleStateHeight

        ZStack {
            // Always render the frame container with animation
            Color.clear
                .frame(width: targetWidth, height: targetHeight)

            // Overlay the actual content only after expansion is complete
            if manager.isRecording && shouldShowContent {
                AudioVisualizationView(audioLevel: manager.audioLevel, color: .white, frequencyBands: manager.frequencyBands)
            } else if manager.isProcessing && shouldShowContent {
                ProgressView()
                    .tint(.white)
                    .controlSize(.small)
                    .brightness(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: shouldShowExpandedPill)
    }
    
    private var expandButton: some View {
        Button(action: {
            manager.expandToFullMode()
        }) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .padding(4)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .frame(width: expandButtonSize, height: expandButtonSize)
        .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    let manager = OverlayWindowManager()
    manager.isRecording = true
    manager.isProcessing = false
    return RecordingOverlayView(manager: manager)
        .frame(width: 400, height: 200)
}
