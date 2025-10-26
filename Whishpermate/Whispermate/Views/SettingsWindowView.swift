import SwiftUI

struct SettingsWindowView: View {
    @StateObject private var hotkeyManager = HotkeyManager()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var transcriptionProviderManager = TranscriptionProviderManager()
    @StateObject private var llmProviderManager = LLMProviderManager()
    @StateObject private var promptRulesManager = PromptRulesManager()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        SettingsView(
            hotkeyManager: hotkeyManager,
            languageManager: languageManager,
            transcriptionProviderManager: transcriptionProviderManager,
            llmProviderManager: llmProviderManager,
            promptRulesManager: promptRulesManager
        )
    }
}
