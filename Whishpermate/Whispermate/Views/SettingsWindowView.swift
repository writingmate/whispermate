import SwiftUI

struct SettingsWindowView: View {
    @StateObject private var hotkeyManager = HotkeyManager()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var transcriptionProviderManager = TranscriptionProviderManager()
    @StateObject private var llmProviderManager = LLMProviderManager()
    @ObservedObject private var promptRulesManager = PromptRulesManager.shared
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
