import SwiftUI

struct RecordingOverlayView: View {
    @ObservedObject var manager: OverlayWindowManager
    @State private var isHovering = false

    // MARK: - Computed Properties

    private var horizontalPadding: CGFloat {
        if manager.isRecording || manager.isProcessing { return 15 }
        return isHovering ? 8 : 16
    }

    private var verticalPadding: CGFloat {
        manager.isRecording || manager.isProcessing ? 9 : 6
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
            VStack(spacing: 0) {
                Spacer()

                HStack {
                    Spacer()

                    // Overlay indicator with smooth expand/collapse
                    HStack(spacing: 6) {
                        contentView(availableWidth: geometry.size.width)

                        if shouldShowExpandButton {
                            expandButton
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                    .background(
                        Capsule()
                            .fill(backgroundColor)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    )
                    .onHover { isHovering = $0 }
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: manager.isRecording)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: manager.isProcessing)
                    .animation(.easeInOut(duration: 0.2), value: isHovering)

                    Spacer()
                }
                .padding(.bottom, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func contentView(availableWidth: CGFloat) -> some View {
        // Use 75% of available width for content, accounting for padding
        let contentWidth = max(40, availableWidth * 0.75)

        if manager.isRecording {
            AudioVisualizationView(audioLevel: manager.audioLevel, color: .white)
                .frame(width: contentWidth, height: 24)
                .transition(.scale.combined(with: .opacity))
        } else if manager.isProcessing {
            ProgressView()
                .tint(.white)
                .controlSize(.small)
                .brightness(2)
                .frame(width: contentWidth, height: 24)
                .transition(.opacity)
        } else {
            Image(systemName: "mic.fill")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.7))
                .transition(.scale.combined(with: .opacity))
        }
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
