import Foundation
internal import Combine

class HistoryManager: ObservableObject {
    @Published var recordings: [Recording] = []

    private let maxRecordings = 100
    private let storageKey = "recordings_history"
    private let fileURL: URL

    init() {
        // Get Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("WhisperMate", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        fileURL = appDirectory.appendingPathComponent("history.json")
        loadRecordings()
    }

    func addRecording(_ recording: Recording) {
        // Add to beginning of list (most recent first)
        recordings.insert(recording, at: 0)

        // Keep only the latest 100
        if recordings.count > maxRecordings {
            recordings = Array(recordings.prefix(maxRecordings))
        }

        saveRecordings()
    }

    func deleteRecording(_ recording: Recording) {
        recordings.removeAll { $0.id == recording.id }
        saveRecordings()
    }

    func clearAll() {
        recordings.removeAll()
        saveRecordings()
    }

    private func loadRecordings() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            recordings = try JSONDecoder().decode([Recording].self, from: data)
        } catch {
            DebugLog.info("Failed to load recordings: \(error)", context: "HistoryManager")
        }
    }

    private func saveRecordings() {
        do {
            let data = try JSONEncoder().encode(recordings)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            DebugLog.info("Failed to save recordings: \(error)", context: "HistoryManager")
        }
    }

    // Search functionality
    func filteredRecordings(searchText: String) -> [Recording] {
        if searchText.isEmpty {
            return recordings
        }
        return recordings.filter { recording in
            recording.transcription.localizedCaseInsensitiveContains(searchText)
        }
    }
}
