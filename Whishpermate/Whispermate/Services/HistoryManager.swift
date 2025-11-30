import Foundation
internal import Combine

/// Manages recording history persistence and audio file storage
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    // MARK: - Published Properties

    @Published var recordings: [Recording] = []

    // MARK: - Private Properties

    private enum Constants {
        static let maxRecordings = 100
        static let appDirectoryName = "WhisperMate"
        static let recordingsDirectoryName = "Recordings"
        static let historyFileName = "history.json"
    }

    private let fileURL: URL
    private let audioDirectory: URL

    // MARK: - Initialization

    private init() {
        // Get Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent(Constants.appDirectoryName, isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        // Create audio storage directory
        audioDirectory = appDirectory.appendingPathComponent(Constants.recordingsDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)

        fileURL = appDirectory.appendingPathComponent(Constants.historyFileName)
        loadRecordings()
    }

    // MARK: - Public API

    func addRecording(_ recording: Recording) {
        // Add to beginning of list (most recent first)
        recordings.insert(recording, at: 0)

        // Keep only the latest recordings
        if recordings.count > Constants.maxRecordings {
            let removed = recordings.suffix(from: Constants.maxRecordings)
            // Delete audio files for removed recordings
            for oldRecording in removed {
                deleteAudioFile(at: oldRecording.audioFileURL)
            }
            recordings = Array(recordings.prefix(Constants.maxRecordings))
        }

        saveRecordings()
    }

    func updateRecording(_ recording: Recording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
            saveRecordings()
        }
    }

    func deleteRecording(_ recording: Recording) {
        recordings.removeAll { $0.id == recording.id }
        deleteAudioFile(at: recording.audioFileURL)
        saveRecordings()
    }

    func clearAll() {
        // Delete all audio files
        for recording in recordings {
            deleteAudioFile(at: recording.audioFileURL)
        }
        recordings.removeAll()
        saveRecordings()
    }

    /// Copy audio file from temporary location to persistent storage
    func copyAudioToPersistentStorage(from sourceURL: URL) -> URL? {
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let destinationURL = audioDirectory.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            DebugLog.info("Copied audio file to persistent storage: \(destinationURL.path)", context: "HistoryManager")
            return destinationURL
        } catch {
            DebugLog.error("Failed to copy audio file: \(error)", context: "HistoryManager")
            return nil
        }
    }

    // MARK: - Search

    func filteredRecordings(searchText: String) -> [Recording] {
        if searchText.isEmpty {
            return recordings
        }
        return recordings.filter { recording in
            recording.transcription?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    var failedRecordings: [Recording] {
        return recordings.filter { $0.isFailed }
    }

    var successfulRecordings: [Recording] {
        return recordings.filter { $0.isSuccessful }
    }

    // MARK: - Private Methods

    private func deleteAudioFile(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                DebugLog.info("Deleted audio file: \(url.path)", context: "HistoryManager")
            }
        } catch {
            DebugLog.error("Failed to delete audio file: \(error)", context: "HistoryManager")
        }
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
}
