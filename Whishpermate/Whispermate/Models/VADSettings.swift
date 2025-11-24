import Foundation
internal import Combine

/// Voice Activity Detection settings manager
/// VAD is always enabled with hardcoded settings
class VADSettingsManager: ObservableObject {
    // Shared singleton instance
    static let shared = VADSettingsManager()

    private init() {}

    // VAD is always enabled
    var vadEnabled: Bool { true }

    // Hardcoded sensitivity threshold
    var sensitivityThreshold: Float { 0.3 }
}
