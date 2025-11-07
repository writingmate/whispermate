import AVFoundation
import Foundation
internal import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0  // Audio level for visualization (0.0 to 1.0)
    @Published var frequencyBands: [Float] = Array(repeating: 0.0, count: 14)  // Frequency spectrum data

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private let volumeManager = AudioVolumeManager()
    private let frequencyAnalyzer = FrequencyAnalyzer()

    override init() {
        super.init()
        // Microphone permission is now handled by OnboardingManager
    }

    func startRecording() {
        DebugLog.info("startRecording called - isRecording before: \(isRecording)", context: "AudioRecorder LOG")

        // Guard against multiple recording sessions
        if audioEngine?.isRunning == true {
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

        // Setup audio engine
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let bus = 0

        let inputFormat = inputNode.outputFormat(forBus: bus)

        // Create audio file for recording
        do {
            audioFile = try AVAudioFile(forWriting: recordingURL!, settings: inputFormat.settings)

            // Install tap on input node for real-time frequency analysis
            // Use larger buffer for better frequency resolution
            inputNode.installTap(onBus: bus, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self else { return }

                // Write to file
                do {
                    try self.audioFile?.write(from: buffer)
                } catch {
                    DebugLog.info("Error writing audio buffer: \(error)", context: "AudioRecorder LOG")
                }

                // Analyze frequencies
                let bands = self.frequencyAnalyzer.analyze(buffer: buffer)

                // Calculate overall audio level from bands (weighted toward mid-range for voice)
                // Voice frequencies are typically 85-255 Hz (fundamental) and 2-4 kHz (formants)
                // Weight middle bands more heavily
                var weightedLevel: Float = 0.0
                for (index, magnitude) in bands.enumerated() {
                    let normalizedPosition = Float(index) / Float(bands.count)
                    // Peak weighting at 30-60% range (voice frequencies)
                    let weight = 1.0 - abs(normalizedPosition - 0.45) * 2.0
                    weightedLevel += magnitude * max(weight, 0.3)
                }
                let level = weightedLevel / Float(bands.count)

                DispatchQueue.main.async {
                    self.frequencyBands = bands
                    self.audioLevel = min(level, 1.0)
                }
            }

            // Start the engine
            try engine.start()
            audioEngine = engine

            // Update UI state on main thread
            DispatchQueue.main.async {
                self.isRecording = true
            }

            DebugLog.info("startRecording success - isRecording after: \(isRecording)", context: "AudioRecorder LOG")
        } catch {
            DebugLog.info("Failed to start recording: \(error)", context: "AudioRecorder LOG")
        }
    }

    func stopRecording() -> URL? {
        DebugLog.info("stopRecording called - isRecording before: \(isRecording)", context: "AudioRecorder LOG")

        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        audioFile = nil

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
        if audioEngine?.isRunning == true {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        audioFile = nil

        // Restore volume as a safety measure
        volumeManager.restoreVolume()

        DebugLog.info("✅ Cleanup complete", context: "AudioRecorder LOG")
    }
}
