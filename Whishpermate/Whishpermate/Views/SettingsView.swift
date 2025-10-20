import SwiftUI

struct SettingsView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var languageManager: LanguageManager
    @ObservedObject var apiProviderManager: APIProviderManager
    @ObservedObject var promptRulesManager: PromptRulesManager
    @State private var apiKey = ""
    @State private var showingSaveConfirmation = false
    @State private var newRuleText = ""
    @State private var editingRule: PromptRule?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            // Header with refined styling
            HStack {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

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

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // API Provider Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API Provider")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Choose your transcription provider")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 8) {
                            ForEach(APIProvider.allCases) { provider in
                                Button(action: {
                                    apiProviderManager.setProvider(provider)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(provider.displayName)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(apiProviderManager.selectedProvider == provider ? .white : .primary)

                                            Text(provider.description)
                                                .font(.system(size: 11))
                                                .foregroundStyle(apiProviderManager.selectedProvider == provider ? .white.opacity(0.8) : .secondary)
                                        }

                                        Spacer()

                                        if apiProviderManager.selectedProvider == provider {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(apiProviderManager.selectedProvider == provider ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(nsColor: .separatorColor), lineWidth: apiProviderManager.selectedProvider == provider ? 0 : 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, max(24, geometry.size.width * 0.06))
                    .padding(.top, 20)

                    Divider()
                        .padding(.horizontal, max(24, geometry.size.width * 0.06))

                    // API Key Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(apiProviderManager.selectedProvider.displayName) API Key")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Your API key is stored securely in macOS Keychain")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                SecureField("Enter API Key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13))

                                Button("Save") {
                                    let keyName = apiProviderManager.selectedProvider.apiKeyName
                                    KeychainHelper.save(key: keyName, value: apiKey)
                                    apiKey = ""
                                    showingSaveConfirmation = true

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showingSaveConfirmation = false
                                    }
                                }
                                .controlSize(.large)
                                .disabled(apiKey.isEmpty)
                            }

                            if showingSaveConfirmation {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("API Key saved successfully")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.green)
                                }
                            }

                            let keyName = apiProviderManager.selectedProvider.apiKeyName
                            if let savedKey = KeychainHelper.get(key: keyName), !savedKey.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.green)
                                    Text("API Key is configured")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, max(24, geometry.size.width * 0.06))

                    Divider()
                        .padding(.horizontal, max(24, geometry.size.width * 0.06))

                    // Prompt Rules Section (DISABLED - see OpenAIClient.swift for explanation)
                    // The Whisper API prompt parameter is for transcript context, not instructions
                    // Re-enable when implementing proper context-based prompting
                    if false && apiProviderManager.selectedProvider == .openai {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transcription Prompt Rules")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text("Add rules to guide the transcription style and formatting")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            // Add new rule
                            HStack(spacing: 8) {
                                TextField("Add a new rule...", text: $newRuleText)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13))
                                    .onSubmit {
                                        if !newRuleText.isEmpty {
                                            promptRulesManager.addRule(newRuleText)
                                            newRuleText = ""
                                        }
                                    }

                                Button(action: {
                                    if !newRuleText.isEmpty {
                                        promptRulesManager.addRule(newRuleText)
                                        newRuleText = ""
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                }
                                .buttonStyle(.plain)
                                .disabled(newRuleText.isEmpty)
                            }

                            // Rules list
                            if !promptRulesManager.rules.isEmpty {
                                VStack(spacing: 6) {
                                    ForEach(promptRulesManager.rules) { rule in
                                        HStack(spacing: 8) {
                                            // Toggle checkbox
                                            Button(action: {
                                                promptRulesManager.toggleRule(rule)
                                            }) {
                                                Image(systemName: rule.isEnabled ? "checkmark.square.fill" : "square")
                                                    .foregroundStyle(rule.isEnabled ? Color.accentColor : .secondary)
                                            }
                                            .buttonStyle(.plain)

                                            // Rule text
                                            Text(rule.text)
                                                .font(.system(size: 13))
                                                .foregroundStyle(rule.isEnabled ? .primary : .secondary)
                                                .strikethrough(!rule.isEnabled)

                                            Spacer()

                                            // Delete button
                                            Button(action: {
                                                promptRulesManager.removeRule(rule)
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color(nsColor: .controlBackgroundColor))
                                        )
                                    }
                                }
                            }

                            // Show combined prompt preview
                            if !promptRulesManager.combinedPrompt.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Combined Prompt:")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)

                                    Text(promptRulesManager.combinedPrompt)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color(nsColor: .textBackgroundColor))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, max(24, geometry.size.width * 0.06))

                        Divider()
                            .padding(.horizontal, max(24, geometry.size.width * 0.06))
                    }

                    // Language Selection Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transcription Languages")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Select languages for transcription. Auto-detect works for all languages.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        // Language selection grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(Language.allCases) { language in
                                Button(action: {
                                    languageManager.toggleLanguage(language)
                                }) {
                                    HStack(spacing: 8) {
                                        Text(language.flag)
                                            .font(.system(size: 16))

                                        Text(language.displayName)
                                            .font(.system(size: 13))
                                            .foregroundStyle(languageManager.isSelected(language) ? .white : .primary)

                                        Spacer()

                                        if languageManager.isSelected(language) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(languageManager.isSelected(language) ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(nsColor: .separatorColor), lineWidth: languageManager.isSelected(language) ? 0 : 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, max(24, geometry.size.width * 0.06))

                    Divider()
                        .padding(.horizontal, max(24, geometry.size.width * 0.06))

                    // Hotkey Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Global Hotkey")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Press a key combination to toggle recording from anywhere")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 12) {
                            HotkeyRecorderView(hotkeyManager: hotkeyManager)
                                .frame(height: 60)

                            // Manual Fn key setter
                            Button(action: {
                                let fnHotkey = Hotkey(keyCode: 63, modifiers: .function)
                                hotkeyManager.setHotkey(fnHotkey)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "keyboard")
                                        .font(.system(size: 13))
                                    Text("Use Fn Key (Manual)")
                                        .font(.system(size: 13))
                                }
                            }
                            .buttonStyle(.bordered)
                            .help("Click to set Fn as your hotkey. Use this if Fn cannot be detected above.")

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.orange)
                                    Text("Requires Accessibility permissions in System Settings")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }

                                Button("Open Accessibility Settings") {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .font(.system(size: 12))
                                .buttonStyle(.link)
                            }
                        }
                    }
                    .padding(.horizontal, max(24, geometry.size.width * 0.06))
                    .padding(.bottom, 24)
                }
            }
        }
        }
        .frame(minWidth: 400, maxWidth: 800, minHeight: 500, maxHeight: 800)
    }
}

#Preview {
    SettingsView(
        hotkeyManager: HotkeyManager(),
        languageManager: LanguageManager(),
        apiProviderManager: APIProviderManager(),
        promptRulesManager: PromptRulesManager()
    )
}
