import SwiftUI

struct RecordingOverlayView: View {
    @ObservedObject var manager: OverlayWindowManager
    @State private var pulseAnimation = false
    @State private var isHovering = false

    var body: some View {
        let _ = print("[RecordingOverlayView] 🎨 body rendering - isRecording: \(manager.isRecording), isProcessing: \(manager.isProcessing), audioLevel: \(manager.audioLevel)")

        return VStack(spacing: 0) {
            Spacer()

            HStack {
                Spacer()

                // Overlay indicator with smooth expand/collapse
                HStack(spacing: 8) {
                    // Icon/indicator
                    if manager.isRecording {
                        // Show waveform visualization when recording
                        AudioVisualizationView(audioLevel: manager.audioLevel, color: .white)
                            .frame(width: 160, height: 24)
                            .transition(.scale.combined(with: .opacity))
                    } else if manager.isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Color.white)
                                .controlSize(.small)
                                .brightness(2)
                            Text("Transcribing...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 160, height: 24)
                        .transition(.opacity)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Expand button (shown on hover)
                    if isHovering {
                        Button(action: {
                            manager.expandToFullMode()
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(6)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, (manager.isRecording || manager.isProcessing) ? 20 : 12)
                .padding(.vertical, (manager.isRecording || manager.isProcessing) ? 12 : 8)
                .background(
                    Capsule()
                        .fill(manager.isRecording ? Color.accentColor.opacity(0.9) : (manager.isProcessing ? Color.accentColor : Color.gray.opacity(0.6)))
                        .shadow(color: .black.opacity(manager.isRecording || manager.isProcessing ? 0.3 : 0.2), radius: manager.isRecording || manager.isProcessing ? 10 : 5, x: 0, y: 5)
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: manager.isRecording)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: manager.isProcessing)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovering)

                Spacer()
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

#Preview {
    let manager = OverlayWindowManager()
    manager.isRecording = true
    manager.isProcessing = false
    return RecordingOverlayView(manager: manager)
        .frame(width: 400, height: 200)
}
