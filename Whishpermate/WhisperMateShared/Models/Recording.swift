import Foundation

public struct Recording: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let transcription: String
    public let duration: TimeInterval?
    public let audioFileURL: URL?

    public init(id: UUID = UUID(), timestamp: Date = Date(), transcription: String, duration: TimeInterval? = nil, audioFileURL: URL? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.transcription = transcription
        self.duration = duration
        self.audioFileURL = audioFileURL
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    public var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}