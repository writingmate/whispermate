import Foundation

struct Recording: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let transcription: String
    let duration: TimeInterval?

    init(id: UUID = UUID(), timestamp: Date = Date(), transcription: String, duration: TimeInterval? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.transcription = transcription
        self.duration = duration
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var formattedDuration: String? {
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
