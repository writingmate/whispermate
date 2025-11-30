import SwiftUI
import WhisperMateShared

struct SettingsWindowView: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var transcriptionProviderManager = TranscriptionProviderManager()
    @StateObject private var llmProviderManager = LLMProviderManager()
    @ObservedObject private var dictionaryManager = DictionaryManager.shared
    @ObservedObject private var contextRulesManager = ContextRulesManager.shared
    @ObservedObject private var shortcutManager = ShortcutManager.shared
    @State private var selectedSection: SettingsSection = .general
    @Environment(\.dismiss) var dismiss

    var body: some View {
        SettingsView(
            hotkeyManager: hotkeyManager,
            languageManager: languageManager,
            transcriptionProviderManager: transcriptionProviderManager,
            llmProviderManager: llmProviderManager,
            dictionaryManager: dictionaryManager,
            contextRulesManager: contextRulesManager,
            shortcutManager: shortcutManager,
            selectedSection: $selectedSection
        )
        .navigationTitle(selectedSection.rawValue)
    }
}
