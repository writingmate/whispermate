import SwiftUI

struct RecordingOverlayView: View {
    @ObservedObject var manager: OverlayWindowManager
    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack {
                Spacer()

                // Overlay indicator with smooth expand/collapse
                HStack(spacing: 12) {
                    // Icon/indicator (always visible)
                    if manager.isRecording {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                    .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                                    .opacity(pulseAnimation ? 0 : 1)
                            )
                            .onAppear {
                                withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                                    pulseAnimation = true
                                }
                            }
                            .onDisappear {
                                pulseAnimation = false
                            }
                    } else if manager.isProcessing {
                        Image(systemName: "waveform")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse, options: .repeating, value: manager.isProcessing)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    // Text (only when recording or processing)
                    if manager.isRecording {
                        Text("Recording...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else if manager.isProcessing {
                        Text("Transcribing...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, manager.isRecording || manager.isProcessing ? 20 : 12)
                .padding(.vertical, manager.isRecording || manager.isProcessing ? 12 : 8)
                .background(
                    Capsule()
                        .fill(manager.isRecording ? Color.red : (manager.isProcessing ? Color.blue : Color.gray.opacity(0.6)))
                        .shadow(color: .black.opacity(manager.isRecording || manager.isProcessing ? 0.3 : 0.2), radius: manager.isRecording || manager.isProcessing ? 10 : 5, x: 0, y: 5)
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: manager.isRecording)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: manager.isProcessing)

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
