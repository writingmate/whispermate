import AVFoundation
import Foundation
internal import Combine

class AudioRecorder: NSObject, ObservableObject {
    // Shared instance to prevent multiple instances when view is recreated
    static let shared = AudioRecorder()

    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0  // Audio level for visualization (0.0 to 1.0)
    @Published var frequencyBands: [Float] = Array(repeating: 0.0, count: 14)  // Frequency spectrum data

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private let volumeManager = AudioVolumeManager()
    private let frequencyAnalyzer = FrequencyAnalyzer()

    private override init() {
        super.init()
        // Microphone permission is now handled by OnboardingManager

        // Listen for audio input device changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioDeviceChanged),
            name: NSNotification.Name("AudioInputDeviceChanged"),
            object: nil
        )
    }

    @objc private func handleAudioDeviceChanged(_ notification: Notification) {
        DebugLog.info("Audio input device changed, will use new device on next recording", context: "AudioRecorder LOG")
        // If currently recording, we could optionally restart here
        // For now, the new device will be used on the next recording
    }

    func startRecording() {
        DebugLog.info("startRecording called - isRecording before: \(isRecording)", context: "AudioRecorder LOG")

        // Clean up any previous engine instance
        if let existingEngine = audioEngine {
            if existingEngine.isRunning {
                DebugLog.info("⚠️ Stopping previous recording session", context: "AudioRecorder LOG")
                existingEngine.stop()
            }
            existingEngine.inputNode.removeTap(onBus: 0)
            audioEngine = nil
        }

        // Lower system volume to duck other audio (if enabled in settings)
        let shouldMuteAudio = UserDefaults.standard.object(forKey: "muteAudioWhenRecording") as? Bool ?? true
        if shouldMuteAudio {
            volumeManager.lowerVolume()
        }

        // Prepare recording file
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let newRecordingURL = tempDirectory.appendingPathComponent(fileName)

        // Delete any existing file at this path
        if fileManager.fileExists(atPath: newRecordingURL.path) {
            try? fileManager.removeItem(at: newRecordingURL)
        }

        recordingURL = newRecordingURL

        do {
            // Create AVAudioEngine
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let bus = 0
            let inputFormat = inputNode.outputFormat(forBus: bus)

            // Create output format for M4A file (AAC, 44.1kHz, mono)
            guard let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 44100.0,
                channels: 1,
                interleaved: false
            ) else {
                DebugLog.info("❌ Failed to create output format", context: "AudioRecorder LOG")
                return
            }

            // Create audio file for writing
            audioFile = try AVAudioFile(
                forWriting: newRecordingURL,
                settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
            )

            // Install tap for both recording and frequency analysis
            inputNode.installTap(onBus: bus, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self else { return }

                // Write buffer to file
                do {
                    // Convert to output format if needed
                    if let converter = AVAudioConverter(from: inputFormat, to: outputFormat) {
                        let convertedBuffer = AVAudioPCMBuffer(
                            pcmFormat: outputFormat,
                            frameCapacity: AVAudioFrameCount(outputFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(inputFormat.sampleRate)
                        )!

                        var error: NSError?
                        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                            outStatus.pointee = .haveData
                            return buffer
                        }

                        if error == nil {
                            try self.audioFile?.write(from: convertedBuffer)
                        }
                    } else {
                        // Same format, write directly
                        try self.audioFile?.write(from: buffer)
                    }
                } catch {
                    DebugLog.info("❌ Failed to write audio buffer: \(error)", context: "AudioRecorder LOG")
                }

                // Analyze frequencies
                let bands = self.frequencyAnalyzer.analyze(buffer: buffer)

                // Calculate audio level from buffer
                let level = self.calculateAudioLevel(from: buffer)

                DispatchQueue.main.async {
                    self.frequencyBands = bands
                    self.audioLevel = level
                }
            }

            // Start the engine
            try engine.start()
            audioEngine = engine

            // Update UI state synchronously so ContentView can check it immediately
            // Ensure we're on main thread for @Published property updates
            if Thread.isMainThread {
                self.isRecording = true
            } else {
                DispatchQueue.main.sync {
                    self.isRecording = true
                }
            }

            DebugLog.info("✅ Recording started successfully with AVAudioEngine", context: "AudioRecorder LOG")
        } catch {
            DebugLog.info("❌ Failed to start recording: \(error) (\(error.localizedDescription))", context: "AudioRecorder LOG")
        }
    }

    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }

        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }

        // Calculate RMS (Root Mean Square)
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))

        // Convert to dB
        let avgPower = 20 * log10(rms)

        // Normalize (-60dB to 0dB → 0.0 to 1.0)
        let minDb: Float = -60.0
        let maxDb: Float = 0.0
        let clampedPower = max(minDb, min(maxDb, avgPower))
        let normalized = (clampedPower - minDb) / (maxDb - minDb)

        // Apply boost for better visualization
        let boosted = min(normalized * 1.5, 1.0)

        return max(0.0, min(1.0, boosted))
    }

    func stopRecording() -> URL? {
        DebugLog.info("stopRecording called - isRecording before: \(isRecording)", context: "AudioRecorder LOG")

        // Stop engine and remove tap
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
                DebugLog.info("Stopped audio engine", context: "AudioRecorder LOG")
            }

            engine.inputNode.removeTap(onBus: 0)
            DebugLog.info("Removed audio tap", context: "AudioRecorder LOG")
        }
        audioEngine = nil

        // Close audio file
        audioFile = nil

        // Restore system volume
        let shouldMuteAudio = UserDefaults.standard.object(forKey: "muteAudioWhenRecording") as? Bool ?? true
        if shouldMuteAudio {
            volumeManager.restoreVolume()
        }

        // Update UI state synchronously so ContentView can check it immediately
        // Ensure we're on main thread for @Published property updates
        if Thread.isMainThread {
            self.isRecording = false
            self.audioLevel = 0.0
            self.frequencyBands = Array(repeating: 0.0, count: 14)
        } else {
            DispatchQueue.main.sync {
                self.isRecording = false
                self.audioLevel = 0.0
                self.frequencyBands = Array(repeating: 0.0, count: 14)
            }
        }

        let url = recordingURL
        DebugLog.info("stopRecording completed, recordingURL: \(String(describing: url))", context: "AudioRecorder LOG")

        // Clear recordingURL for next session
        recordingURL = nil

        return url
    }

    deinit {
        DebugLog.info("🗑️ Deinit - cleaning up", context: "AudioRecorder LOG")

        // Remove notification observers
        NotificationCenter.default.removeObserver(self)

        // Stop engine and clean up
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        audioFile = nil

        // Restore volume as a safety measure
        volumeManager.restoreVolume()

        DebugLog.info("✅ Cleanup complete", context: "AudioRecorder LOG")
    }
}
