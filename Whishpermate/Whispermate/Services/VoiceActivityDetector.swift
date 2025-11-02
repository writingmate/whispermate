import Foundation
import AVFoundation

/// Voice Activity Detection service using Silero VAD CoreML model
/// Analyzes completed audio files to determine if they contain speech
class VoiceActivityDetector {
    private static var shared: VoiceActivityAnalyzer?

    /// Get or create shared analyzer instance
    static func getAnalyzer() -> VoiceActivityAnalyzer {
        if shared == nil {
            shared = VoiceActivityAnalyzer()
        }
        return shared!
    }

    /// Check if an audio file contains speech
    /// - Parameters:
    ///   - audioURL: URL to the audio file
    ///   - settings: VAD settings (optional)
    /// - Returns: True if speech detected, false if only silence/noise
    static func hasSpeech(in audioURL: URL, settings: VADSettingsManager? = nil) async throws -> Bool {
        let analyzer = getAnalyzer()
        let threshold = settings?.sensitivityThreshold ?? 0.3
        let minSpeechRatio: Float = 0.1

        return try await analyzer.containsSpeech(
            in: audioURL,
            threshold: threshold,
            minSpeechRatio: minSpeechRatio
        )
    }
}
