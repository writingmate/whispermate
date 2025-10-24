import AVFoundation
import Foundation
internal import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0  // Audio level for visualization (0.0 to 1.0)

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var levelTimer: Timer?
    private let volumeManager = AudioVolumeManager()

    override init() {
        super.init()
        // Microphone permission is now handled by OnboardingManager
    }

    func startRecording() {
        print("[AudioRecorder LOG] startRecording called - isRecording before: \(isRecording)")

        // Guard against multiple recording sessions
        if audioRecorder?.isRecording == true {
            print("[AudioRecorder LOG] ⚠️ Already recording - stopping previous session first")
            _ = stopRecording()
        }

        // Lower system volume for better recording quality
        volumeManager.lowerVolume()

        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        recordingURL = tempDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.isMeteringEnabled = true  // Enable metering for visualization
            audioRecorder?.record()

            // Start timer to update audio levels
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()

                // Get average power (-160 to 0 dB) and normalize to 0.0-1.0
                let averagePower = recorder.averagePower(forChannel: 0)
                let normalizedLevel = self.normalizeAudioLevel(averagePower)

                DispatchQueue.main.async {
                    self.audioLevel = normalizedLevel
                }
            }

            // Update UI state on main thread
            DispatchQueue.main.async {
                self.isRecording = true
            }

            print("[AudioRecorder LOG] startRecording success - isRecording after: \(isRecording)")
        } catch {
            print("[AudioRecorder LOG] Failed to start recording: \(error)")
        }
    }

    private func normalizeAudioLevel(_ power: Float) -> Float {
        // Convert dB (-160 to 0) to normalized 0.0-1.0 scale
        // Using -60dB as minimum threshold for increased sensitivity
        let minDb: Float = -60.0
        let maxDb: Float = 0.0

        let clampedPower = max(minDb, min(maxDb, power))
        let normalized = (clampedPower - minDb) / (maxDb - minDb)

        // Apply additional boost for better visualization
        let boosted = min(normalized * 1.5, 1.0)

        return max(0.0, min(1.0, boosted))
    }

    func stopRecording() -> URL? {
        print("[AudioRecorder LOG] stopRecording called - isRecording before: \(isRecording)")

        // Stop timer
        levelTimer?.invalidate()
        levelTimer = nil

        audioRecorder?.stop()

        // Restore system volume
        volumeManager.restoreVolume()

        // Update UI state on main thread
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }

        print("[AudioRecorder LOG] stopRecording completed, recordingURL: \(String(describing: recordingURL))")
        return recordingURL
    }

    deinit {
        print("[AudioRecorder LOG] 🗑️ Deinit - cleaning up")

        // Stop and clean up recording
        if audioRecorder?.isRecording == true {
            audioRecorder?.stop()
        }
        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder = nil

        // Restore volume as a safety measure
        volumeManager.restoreVolume()

        print("[AudioRecorder LOG] ✅ Cleanup complete")
    }
}
