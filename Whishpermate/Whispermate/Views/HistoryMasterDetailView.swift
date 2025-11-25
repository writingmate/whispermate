import SwiftUI
import AppKit

enum AIApp: String, CaseIterable, Identifiable {
    case writingmate = "Writingmate"
    case claude = "Claude"
    case chatgpt = "ChatGPT"
    case perplexity = "Perplexity"
    case whatsapp = "WhatsApp"
    case email = "Email"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .writingmate: return "square.and.pencil"
        case .claude: return "sparkles"
        case .chatgpt: return "bubble.left.and.bubble.right"
        case .perplexity: return "magnifyingglass.circle"
        case .whatsapp: return "message.fill"
        case .email: return "envelope"
        case .custom: return "gearshape"
        }
    }

    var urlTemplate: String {
        switch self {
        case .writingmate: return "https://writingmate.ai/new?q={prompt}"
        case .chatgpt: return "https://chatgpt.com/?q={prompt}"
        case .perplexity: return "https://www.perplexity.ai/?q={prompt}"
        case .claude: return "https://claude.ai/new?q={prompt}"
        case .whatsapp: return "whatsapp://send?text={prompt}"
        case .email: return "mailto:?body={prompt}"
        case .custom: return "" // Will be loaded from UserDefaults
        }
    }
}

/// Master-detail view that combines history list with recording interface
struct HistoryMasterDetailView: View {
    @ObservedObject private var historyManager = HistoryManager.shared
    @ObservedObject private var onboardingManager = OnboardingManager.shared
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedRecording: Recording?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: History List
            HistorySidebarView(
                historyManager: historyManager,
                selectedRecording: $selectedRecording
            )
            .navigationTitle("History")
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
            }
        } detail: {
            if let recording = selectedRecording {
                RecordingDetailView(
                    recording: recording,
                    historyManager: historyManager,
                    columnVisibility: columnVisibility,
                    onDelete: { recordingToDelete in
                        // Find index before deletion
                        guard let index = historyManager.recordings.firstIndex(where: { $0.id == recordingToDelete.id }) else {
                            return
                        }

                        // Determine next selection before deleting
                        let nextSelection: Recording?
                        if index < historyManager.recordings.count - 1 {
                            // Select next recording
                            nextSelection = historyManager.recordings[index + 1]
                        } else if index > 0 {
                            // Select previous recording
                            nextSelection = historyManager.recordings[index - 1]
                        } else {
                            // No recordings left
                            nextSelection = nil
                        }

                        // Delete the recording
                        historyManager.deleteRecording(recordingToDelete)

                        // Update selection
                        selectedRecording = nextSelection
                    }
                )
                .id(recording.id)
            } else {
                // Empty state when no recording is selected
                VStack(spacing: 12) {
                    Image(systemName: "mic.circle")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)
                    Text("Select a recording")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Press Fn to start recording")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .navigationTitle("")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        EmptyView()
                    }
                }
                .toolbarBackground(.hidden, for: .automatic)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: .recordingCompleted)) { notification in
            // Switch to detail view when recording is completed
            if let recording = notification.object as? Recording {
                selectedRecording = recording
                columnVisibility = .all
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHistory)) { _ in
            // Show sidebar when history is requested from menu
            columnVisibility = .all
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            openWindow(id: "settings")
        }
        .onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in
            onboardingManager.reopenOnboarding()
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingComplete)) { _ in
            // Close onboarding window
            if let window = NSApplication.shared.windows.first(where: { $0.identifier == WindowIdentifiers.onboarding }) {
                window.close()
            }

            // Show and center main window
            if let mainWindow = NSApplication.shared.windows.first(where: { $0.identifier == WindowIdentifiers.main }) {
                mainWindow.center()
                mainWindow.setIsVisible(true)
                mainWindow.makeKeyAndOrderFront(nil)
            }
        }
        .onChange(of: onboardingManager.showOnboarding) { newValue in
            if newValue {
                // Hide main window before opening onboarding
                if let mainWindow = NSApplication.shared.windows.first(where: { $0.identifier == WindowIdentifiers.main }) {
                    mainWindow.setIsVisible(false)
                }

                // Open onboarding window
                openWindow(id: "onboarding")
            }
        }
    }
}

/// Sidebar showing list of all recordings
struct HistorySidebarView: View {
    @ObservedObject var historyManager: HistoryManager
    @Binding var selectedRecording: Recording?
    @State private var searchText = ""

    var filteredRecordings: [Recording] {
        historyManager.filteredRecordings(searchText: searchText)
    }

    var body: some View {
        Group {
            if filteredRecordings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: searchText.isEmpty ? "mic.slash" : "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "No Recordings" : "No Results")
                        .font(.headline)
                    Text(searchText.isEmpty ? "Your recordings will appear here" : "Try a different search")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredRecordings, selection: $selectedRecording) { recording in
                    HistorySidebarRow(recording: recording)
                        .tag(recording)
                        .contextMenu {
                            Button {
                                copyTranscription(recording)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .disabled(recording.transcription == nil)

                            Button {
                                retryTranscription(recording)
                            } label: {
                                Label("Re-transcribe", systemImage: "arrow.clockwise")
                            }

                            Button {
                                revealInFinder(recording)
                            } label: {
                                Label("Reveal in Finder", systemImage: "folder")
                            }

                            Divider()

                            Button(role: .destructive) {
                                deleteRecording(recording)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.sidebar)
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search recordings")
    }

    private func copyTranscription(_ recording: Recording) {
        guard let transcription = recording.transcription else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcription, forType: .string)
    }

    private func retryTranscription(_ recording: Recording) {
        // TODO: Implement retry logic
        // This would need to re-transcribe the audio file from recording.audioFileURL
    }

    private func revealInFinder(_ recording: Recording) {
        let fileURL = recording.audioFileURL
        // Check if file exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: "")
        }
    }

    private func deleteRecording(_ recording: Recording) {
        // If this recording is selected, select the next one
        if selectedRecording?.id == recording.id {
            if let index = historyManager.recordings.firstIndex(where: { $0.id == recording.id }) {
                if index < historyManager.recordings.count - 1 {
                    selectedRecording = historyManager.recordings[index + 1]
                } else if index > 0 {
                    selectedRecording = historyManager.recordings[index - 1]
                } else {
                    selectedRecording = nil
                }
            }
        }
        historyManager.deleteRecording(recording)
    }
}

/// Compact row in sidebar
struct HistorySidebarRow: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main content
            if let transcription = recording.transcription {
                Text(transcription)
                    .font(.body)
                    .lineLimit(3)
            } else {
                Label("Failed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                if let errorMessage = recording.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            // Metadata
            HStack(spacing: 4) {
                Text(recording.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let duration = recording.formattedDuration {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .badge(recording.status == .success ? nil : "!")
    }
}

/// Detail view showing a selected recording
struct RecordingDetailView: View {
    let recording: Recording
    @ObservedObject var historyManager: HistoryManager
    let columnVisibility: NavigationSplitViewVisibility
    let onDelete: (Recording) -> Void
    @State private var showCopiedNotification = false

    // Compute dynamic padding based on sidebar visibility
    private var leadingPadding: CGFloat {
        // When sidebar is hidden (.detailOnly), toggle button appears in detail view - need more padding
        // When sidebar is visible (.all or .doubleColumn), toggle button is in sidebar - use less padding
        columnVisibility == .detailOnly ? 80 : 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scrollable content (title moved to toolbar)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Transcription or error
                    if let transcription = recording.transcription {
                        Text(transcription)
                            .textSelection(.enabled)
                            .font(.body)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transcription Failed")
                                .font(.headline)
                                .foregroundStyle(.orange)

                            if let errorMessage = recording.errorMessage {
                                Text(errorMessage)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            // Bottom hint
            HStack {
                Spacer()
                Text("Press Fn to start a new recording")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(recording.formattedDate)
        .toolbar {

            // All action buttons grouped together
            ToolbarItemGroup(placement: .automatic) {
                // Status indicator for failed recordings
                if recording.status == .failed {
                    Label("Failed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                // Copy button
                Button(action: copyTranscription) {
                    Label("Copy", systemImage: showCopiedNotification ? "checkmark" : "doc.on.doc")
                }
                .foregroundStyle(showCopiedNotification ? .green : .secondary)
                .disabled(recording.transcription == nil)
                .keyboardShortcut("c", modifiers: .command)

                // Share menu
                Menu {
                    ForEach(AIApp.allCases) { app in
                        Button(action: { sendToAI(app: app) }) {
                            Label(app.rawValue, systemImage: app.icon)
                        }
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(recording.transcription == nil)

                // Retry button (failed recordings only)
                if recording.status == .failed {
                    Button(action: retryTranscription) {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .disabled(recording.retryCount >= 3)
                }

                // Delete button - last item
                Button(action: deleteRecording) {
                    Label("Delete", systemImage: "trash")
                }
                .foregroundStyle(.red)
                .keyboardShortcut(.delete, modifiers: [])
            }
        }
        .onDeleteCommand(perform: deleteRecording)
    }

    private func copyTranscription() {
        guard let transcription = recording.transcription else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcription, forType: .string)

        showCopiedNotification = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedNotification = false
        }
    }

    private func retryTranscription() {
        // TODO: Implement retry logic
        // This would need to re-transcribe the audio file from recording.audioFileURL
    }

    private func deleteRecording() {
        onDelete(recording)
    }

    private func sendToAI(app: AIApp) {
        guard let transcription = recording.transcription else { return }

        // Get URL template
        var urlTemplate = app.urlTemplate
        if app == .custom {
            // Load custom URL from UserDefaults
            urlTemplate = UserDefaults.standard.string(forKey: "aiPromptURL") ?? "https://chatgpt.com/?q={prompt}"
        }

        // URL encode the transcription
        guard let encodedPrompt = transcription.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }

        // Replace {prompt} placeholder with encoded text
        let urlString = urlTemplate.replacingOccurrences(of: "{prompt}", with: encodedPrompt)

        guard let url = URL(string: urlString) else {
            return
        }

        // Open URL in default browser or app
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    HistoryMasterDetailView()
        .frame(width: 900, height: 600)
}
