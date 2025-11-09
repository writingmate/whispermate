import AVFoundation
import Foundation
internal import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0  // Audio level for visualization (0.0 to 1.0)
    @Published var frequencyBands: [Float] = Array(repeating: 0.0, count: 14)  // Frequency spectrum data

    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var recordingURL: URL?
    private var levelTimer: Timer?
    private let volumeManager = AudioVolumeManager()
    private let frequencyAnalyzer = FrequencyAnalyzer()

    override init() {
        super.init()
        // Microphone permission is now handled by OnboardingManager
    }

    func startRecording() {
        DebugLog.info("startRecording called - isRecording before: \(isRecording)", context: "AudioRecorder LOG")

        // Guard against multiple recording sessions
        if audioRecorder?.isRecording == true {
            DebugLog.info("⚠️ Already recording - stopping previous session first", context: "AudioRecorder LOG")
            _ = stopRecording()
        }

        // Lower system volume to duck other audio (if enabled in settings)
        let shouldMuteAudio = UserDefaults.standard.object(forKey: "muteAudioWhenRecording") as? Bool ?? true
        if shouldMuteAudio {
            volumeManager.lowerVolume()
        }

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
            // Start AVAudioRecorder for actual recording
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            // Start AVAudioEngine for frequency analysis
            startFrequencyAnalysis()

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

    private func startFrequencyAnalysis() {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let bus = 0
        let inputFormat = inputNode.outputFormat(forBus: bus)

        // Install tap for frequency analysis only (not for recording)
        inputNode.installTap(onBus: bus, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Analyze frequencies
            let bands = self.frequencyAnalyzer.analyze(buffer: buffer)

            DispatchQueue.main.async {
                self.frequencyBands = bands
            }
        }

        do {
            try engine.start()
            audioEngine = engine
        } catch {
            DebugLog.info("Failed to start frequency analysis: \(error)", context: "AudioRecorder LOG")
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
        DebugLog.info("stopRecording called - isRecording before: \(isRecording)", context: "AudioRecorder LOG")

        // Stop timer
        levelTimer?.invalidate()
        levelTimer = nil

        // Stop audio recorder
        audioRecorder?.stop()

        // Stop frequency analysis engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        // Restore system volume (if it was lowered)
        let shouldMuteAudio = UserDefaults.standard.object(forKey: "muteAudioWhenRecording") as? Bool ?? true
        if shouldMuteAudio {
            volumeManager.restoreVolume()
        }

        // Update UI state on main thread
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
            self.frequencyBands = Array(repeating: 0.0, count: 14)
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

        // Stop frequency analysis
        if audioEngine?.isRunning == true {
            audioEngine?.inputNode.removeTap(onBus: 0)
            audioEngine?.stop()
        }
        audioEngine = nil

        // Restore volume as a safety measure
        volumeManager.restoreVolume()

        DebugLog.info("✅ Cleanup complete", context: "AudioRecorder LOG")
    }
}
