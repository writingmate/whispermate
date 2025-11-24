import Foundation

enum TranscriptionStatus: String, Codable {
    case success
    case failed
    case retrying
}

struct Recording: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let audioFileURL: URL
    var transcription: String?
    var status: TranscriptionStatus
    var errorMessage: String?
    var retryCount: Int
    let duration: TimeInterval?
    var wordCount: Int?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        audioFileURL: URL,
        transcription: String? = nil,
        status: TranscriptionStatus = .success,
        errorMessage: String? = nil,
        retryCount: Int = 0,
        duration: TimeInterval? = nil,
        wordCount: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.audioFileURL = audioFileURL
        self.transcription = transcription
        self.status = status
        self.errorMessage = errorMessage
        self.retryCount = retryCount
        self.duration = duration
        self.wordCount = wordCount
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

    var isSuccessful: Bool {
        return status == .success
    }

    var isFailed: Bool {
        return status == .failed
    }
}
