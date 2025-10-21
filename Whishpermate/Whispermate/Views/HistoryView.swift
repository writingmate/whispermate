import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var historyManager: HistoryManager
    @State private var searchText = ""
    @State private var showingClearConfirmation = false
    @Environment(\.dismiss) var dismiss

    var filteredRecordings: [Recording] {
        historyManager.filteredRecordings(searchText: searchText)
    }

    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            // Header with refined styling
            HStack {
                Text("Recording History")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(historyManager.recordings.count) / 100")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .separatorColor).opacity(0.5))
                    )

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, max(24, geometry.size.width * 0.06))
            .padding(.vertical, 20)

            Divider()

            // Search Bar with refined design
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)

                TextField("Search transcriptions...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .padding(.horizontal, max(24, geometry.size.width * 0.06))
            .padding(.vertical, 16)

            // Recordings List
            if filteredRecordings.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: searchText.isEmpty ? "mic.slash" : "magnifyingglass")
                        .font(.system(size: 56))
                        .foregroundStyle(.quaternary)
                        .symbolRenderingMode(.hierarchical)
                    Text(searchText.isEmpty ? "No recordings yet" : "No results found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                    if searchText.isEmpty {
                        Text("Start recording to build your history")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredRecordings) { recording in
                            RecordingRow(recording: recording, historyManager: historyManager, windowWidth: geometry.size.width)
                        }
                    }
                    .padding(.horizontal, max(24, geometry.size.width * 0.06))
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
        .frame(minWidth: 400, maxWidth: 800, minHeight: 400, maxHeight: 700)
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
    let windowWidth: CGFloat

    @State private var isHovering = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(alignment: .top, spacing: max(12, windowWidth * 0.02)) {
            // Timestamp
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.formattedDate)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                if let duration = recording.formattedDuration {
                    Text(duration)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minWidth: 100, maxWidth: 140, alignment: .leading)

            // Transcription
            Text(recording.transcription)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .lineLimit(3)

            // Actions (shown on hover)
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: {
                        copyToClipboard(recording.transcription)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Copy")

                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
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
    HistoryView(historyManager: HistoryManager())
        .frame(width: 640, height: 540)
}
