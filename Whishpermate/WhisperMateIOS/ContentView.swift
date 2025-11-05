import SwiftUI
import WhisperMateShared

struct ContentView: View {
    @StateObject private var historyManager = HistoryManager()
    @StateObject private var promptRulesManager = PromptRulesManager.shared
    @State private var selectedTab: Int = 0
    @State private var showRecordingSheet = false
    @State private var selectedRecording: Recording?
    @State private var showTextRules = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // History Tab
                historyView
                    .tabItem {
                        Label("History", systemImage: "clock.fill")
                    }
                    .tag(0)

                // Placeholder for center button
                Color.clear
                    .tabItem {
                        Text("")
                    }
                    .tag(1)

                // Settings Tab
                settingsView
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(2)
            }
            .onChange(of: selectedTab) { newTab in
                if newTab == 1 {
                    showRecordingSheet = true
                    // Reset to previous tab immediately
                    selectedTab = 0
                }
            }

            // Large center recording button overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showRecordingSheet = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 64, height: 64)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                            Image(systemName: "mic.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showRecordingSheet) {
            RecordingSheetView(historyManager: historyManager, promptRulesManager: promptRulesManager)
        }
    }

    // MARK: - History View

    private var historyView: some View {
        NavigationView {
            List {
                ForEach(historyManager.recordings) { recording in
                    Button(action: {
                        selectedRecording = recording
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recording.transcription)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(recording.formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            historyManager.deleteRecording(recording)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            UIPasteboard.general.string = recording.transcription
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .tint(.blue)

                        if recording.audioFileURL != nil {
                            Button {
                                selectedRecording = recording
                            } label: {
                                Label("Play", systemImage: "play.fill")
                            }
                            .tint(.green)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .sheet(item: $selectedRecording) { recording in
                RecordingSheetView(historyManager: historyManager, promptRulesManager: promptRulesManager, recording: recording)
            }
        }
    }

    // MARK: - Settings View

    private var settingsView: some View {
        NavigationView {
            Form {
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Transcription") {
                    NavigationLink(destination: TextRulesView(promptRulesManager: promptRulesManager)) {
                        Label("Text Rules", systemImage: "text.badge.checkmark")
                    }
                }

                Section("Data") {
                    Button("Clear All History", role: .destructive) {
                        historyManager.clearAll()
                    }
                    .disabled(historyManager.recordings.isEmpty)
                }

                Section {
                    Button("Reset Onboarding", role: .destructive) {
                        OnboardingManager().resetOnboarding()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

}

#Preview {
    ContentView()
}
