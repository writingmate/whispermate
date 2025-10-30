import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var transcriptionProviderManager = TranscriptionProviderManager()
    @StateObject private var llmProviderManager = LLMProviderManager()
    @ObservedObject private var promptRulesManager = PromptRulesManager.shared
    @State private var selectedSection: SettingsSection = .general
    @Environment(\.dismiss) var dismiss

    var body: some View {
        SettingsView(
            hotkeyManager: hotkeyManager,
            languageManager: languageManager,
            transcriptionProviderManager: transcriptionProviderManager,
            llmProviderManager: llmProviderManager,
            promptRulesManager: promptRulesManager,
            selectedSection: $selectedSection
        )
        .navigationTitle(selectedSection.rawValue)
        .onAppear {
            // Set window identifier for identification
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Settings" }) {
                window.identifier = WindowIdentifiers.settings
            }
        }
    }
}
