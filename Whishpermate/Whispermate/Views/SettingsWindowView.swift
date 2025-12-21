import SwiftUI
import WhisperMateShared

struct SettingsWindowView: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @StateObject private var transcriptionProviderManager = TranscriptionProviderManager()
    @ObservedObject private var llmProviderManager = LLMProviderManager.shared
    @ObservedObject private var dictionaryManager = DictionaryManager.shared
    @ObservedObject private var contextRulesManager = ContextRulesManager.shared
    @ObservedObject private var shortcutManager = ShortcutManager.shared
    @ObservedObject private var onboardingManager = OnboardingManager.shared
    @State private var selectedSection: SettingsSection = .general
    @Environment(\.dismiss) var dismiss
    @Environment(\.openWindow) private var openWindow

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
        .onReceive(NotificationCenter.default.publisher(for: .openAccountSettings)) { _ in
            // Navigate to Account section and show window
            selectedSection = .account
            showMainSettingsWindow()
        }
    }
}
