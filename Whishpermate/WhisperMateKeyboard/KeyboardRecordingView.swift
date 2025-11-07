import SwiftUI
import WhisperMateShared

struct KeyboardRecordingView: View {
    let isRecording: Bool
    let audioLevel: Float
    let onStopRecording: () -> Void

    var body: some View {
        ZStack {
            // Background
            Color(uiColor: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
                    : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1.0)
            })
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                if isRecording {
                    // Audio visualization during recording
                    AudioVisualizationView(audioLevel: audioLevel, color: .blue)
                        .frame(height: 120)
                        .padding(.horizontal, 40)

                    Spacer()

                    // Stop button
                    Button(action: onStopRecording) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 70, height: 70)
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .padding(.bottom, 30)
                } else {
                    // Large microphone icon when not recording
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 80, height: 80)
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Text("Tap to start recording")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.top, 12)

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        KeyboardRecordingView(isRecording: false, audioLevel: 0.0, onStopRecording: {})
            .frame(height: 250)

        Divider()

        KeyboardRecordingView(isRecording: true, audioLevel: 0.7, onStopRecording: {})
            .frame(height: 250)
    }
}
