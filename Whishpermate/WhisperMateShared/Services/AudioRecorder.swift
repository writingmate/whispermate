import AVFoundation
import Foundation
public import Combine

#if os(iOS)
import UIKit
#endif

public class AudioRecorder: NSObject, ObservableObject {
    @Published public var isRecording = false
    @Published public var audioLevel: Float = 0.0  // Audio level for visualization (0.0 to 1.0)

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var levelTimer: Timer?

    // App Group identifier for sharing data between app and keyboard extension
    public static let appGroupIdentifier = "group.com.whispermate.shared"

    public override init() {
        super.init()
        #if os(iOS)
        configureAudioSession()
        #endif
    }

    #if os(iOS)
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [])
            try session.setActive(true)
            DebugLog.info("Audio session configured for iOS", context: "AudioRecorder")
        } catch {
            DebugLog.info("Failed to configure audio session: \(error)", context: "AudioRecorder")
        }
    }
    #endif

    public func startRecording() {
        DebugLog.info("startRecording called - isRecording before: \(isRecording)", context: "AudioRecorder LOG")

        // Guard against multiple recording sessions
        if audioRecorder?.isRecording == true {
            DebugLog.info("⚠️ Already recording - stopping previous session first", context: "AudioRecorder LOG")
            _ = stopRecording()
        }

        let fileManager = FileManager.default

        // Use App Group container on iOS, temp directory on macOS
        #if os(iOS)
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AudioRecorder.appGroupIdentifier) else {
            DebugLog.info("Failed to get app group container", context: "AudioRecorder LOG")
            return
        }
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        recordingURL = containerURL.appendingPathComponent(fileName)
        #else
        let tempDirectory = fileManager.temporaryDirectory
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        recordingURL = tempDirectory.appendingPathComponent(fileName)
        #endif

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

            DebugLog.info("startRecording success - isRecording after: \(isRecording)", context: "AudioRecorder LOG")
        } catch {
            DebugLog.info("Failed to start recording: \(error)", context: "AudioRecorder LOG")
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

    public func stopRecording() -> URL? {
        DebugLog.info("stopRecording called - isRecording before: \(isRecording)", context: "AudioRecorder LOG")

        // Stop timer
        levelTimer?.invalidate()
        levelTimer = nil

        audioRecorder?.stop()

        #if os(iOS)
        // Deactivate audio session on iOS
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            DebugLog.info("Failed to deactivate audio session: \(error)", context: "AudioRecorder LOG")
        }
        #endif

        // Update UI state on main thread
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }

        DebugLog.info("stopRecording completed, recordingURL: \(String(describing: recordingURL))", context: "AudioRecorder LOG")
        return recordingURL
    }

    deinit {
        DebugLog.info("🗑️ Deinit - cleaning up", context: "AudioRecorder LOG")

        // Stop and clean up recording
        if audioRecorder?.isRecording == true {
            audioRecorder?.stop()
        }
        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder = nil

        DebugLog.info("✅ Cleanup complete", context: "AudioRecorder LOG")
    }
}