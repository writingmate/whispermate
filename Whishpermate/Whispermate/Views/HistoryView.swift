import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var historyManager: HistoryManager
    @State private var searchText = ""
    @State private var showingClearConfirmation = false
    @Environment(\.dismiss) var dismiss

    var onRetry: ((Recording) async throws -> Void)?

    var filteredRecordings: [Recording] {
        historyManager.filteredRecordings(searchText: searchText)
    }

    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            // Header with title and close button (matching Settings style)
            HStack {
                Text("History")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    TextField("Search transcriptions...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                // Recordings List
                if filteredRecordings.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: searchText.isEmpty ? "mic.slash" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text(searchText.isEmpty ? "No recordings yet" : "No results found")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                        if searchText.isEmpty {
                            Text("Start recording to build your history")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredRecordings) { recording in
                                RecordingRow(recording: recording, historyManager: historyManager)

                                if recording.id != filteredRecordings.last?.id {
                                    Divider()
                                        .padding(.horizontal, 24)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Divider()

                // Bottom Actions
                HStack {
                    Button(action: {
                        showingClearConfirmation = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                            Text("Clear All")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(historyManager.recordings.isEmpty)

                    Spacer()
                }
                .padding(.horizontal, max(24, geometry.size.width * 0.06))
                .padding(.vertical, 16)
        }
        }
        .frame(minWidth: 800, maxWidth: 1600, minHeight: 800, maxHeight: 1400)
        .alert("Clear All History?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                historyManager.clearAll()
            }
        } message: {
            Text("This will permanently delete all \(historyManager.recordings.count) recordings. This action cannot be undone.")
        }
    }
}

struct RecordingRow: View {
    let recording: Recording
    let historyManager: HistoryManager

    @State private var isHovering = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Status indicator
            Image(systemName: recording.status == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(recording.status == .success ? .green : .orange)

            // Timestamp
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.formattedDate)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                if let duration = recording.formattedDuration {
                    Text(duration)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if recording.retryCount > 0 {
                    Text("Retried \(recording.retryCount)x")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }
            .frame(minWidth: 120, alignment: .leading)

            // Transcription or Error
            if let transcription = recording.transcription {
                Text(transcription)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else if let errorMessage = recording.errorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Failed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Actions (always rendered, opacity changes on hover)
            HStack(spacing: 8) {
                if recording.status == .success {
                    Button(action: {
                        if let transcription = recording.transcription {
                            copyToClipboard(transcription)
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Copy")
                    .opacity(isHovering ? 1 : 0)
                } else if recording.status == .failed {
                    Button(action: {
                        // TODO: Implement retry from history
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Retry")
                    .opacity(isHovering ? 1 : 0)
                    .disabled(recording.retryCount >= 3)
                }

                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Delete")
                .opacity(isHovering ? 1 : 0)
            }
            .frame(width: 80)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(isHovering ? Color(nsColor: .controlBackgroundColor).opacity(0.5) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
        .alert("Delete Recording?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                historyManager.deleteRecording(recording)
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

#Preview {
    HistoryView(historyManager: HistoryManager.shared)
        .frame(width: 640, height: 540)
}
