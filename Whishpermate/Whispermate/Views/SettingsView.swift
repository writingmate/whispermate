import SwiftUI
import AVFoundation
import ApplicationServices

enum SettingsSection: String, CaseIterable, Identifiable {
    case permissions = "Permissions"
    case audio = "Audio"
    case rules = "Text Rules"
    case hotkeys = "Hotkeys"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .permissions: return "lock.shield"
        case .audio: return "waveform"
        case .rules: return "text.badge.checkmark"
        case .hotkeys: return "keyboard"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var languageManager: LanguageManager
    @ObservedObject var transcriptionProviderManager: TranscriptionProviderManager
    @ObservedObject var llmProviderManager: LLMProviderManager
    @ObservedObject var promptRulesManager: PromptRulesManager
    @State private var selectedSection: SettingsSection = .audio
    @State private var transcriptionApiKey = ""
    @State private var llmApiKey = ""
    @State private var customEndpoint = ""
    @State private var customModel = ""
    @State private var showingTranscriptionKeySaved = false
    @State private var showingLLMKeySaved = false
    @State private var newRuleText = ""
    @State private var audioDevices: [AVCaptureDevice] = []
    @State private var selectedAudioDevice: AVCaptureDevice?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 4) {
                // Sidebar padding at top
                Spacer()
                    .frame(height: 16)

                ForEach(SettingsSection.allCases) { section in
                    Button(action: {
                        selectedSection = section
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: section.icon)
                                .font(.system(size: 14))
                                .frame(width: 20)

                            Text(section.rawValue)
                                .font(.system(size: 13))

                            Spacer()
                        }
                        .foregroundStyle(selectedSection == section ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedSection == section ? Color.accentColor : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }

                Spacer()
            }
            .frame(width: 200)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content Area
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(selectedSection.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(nsColor: .textBackgroundColor))

                Divider()

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedSection {
                        case .permissions:
                            permissionsSection
                        case .audio:
                            audioSection
                        case .rules:
                            rulesSection
                        case .hotkeys:
                            hotkeysSection
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(width: 700, height: 550)
        .onAppear {
            loadAudioDevices()
        }
    }

    // MARK: - General Section
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section Header
            Text("General")
                .font(.system(size: 20, weight: .semibold))

            // TRANSCRIPTION PROVIDER
            VStack(alignment: .leading, spacing: 12) {
                Text("Transcription Provider")
                    .font(.system(size: 15, weight: .semibold))

                Text("Choose your speech-to-text service")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(TranscriptionProvider.allCases) { provider in
                        Button(action: {
                            transcriptionProviderManager.setProvider(provider)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(provider.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(transcriptionProviderManager.selectedProvider == provider ? .white : .primary)

                                    Text(provider.description)
                                        .font(.system(size: 11))
                                        .foregroundStyle(transcriptionProviderManager.selectedProvider == provider ? .white.opacity(0.8) : .secondary)
                                }

                                Spacer()

                                if transcriptionProviderManager.selectedProvider == provider {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(transcriptionProviderManager.selectedProvider == provider ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: transcriptionProviderManager.selectedProvider == provider ? 0 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Transcription API Key
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.system(size: 13, weight: .medium))

                    HStack(spacing: 8) {
                        SecureField("Enter \(transcriptionProviderManager.selectedProvider.displayName) API Key", text: $transcriptionApiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))

                        Button("Save") {
                            let keyName = transcriptionProviderManager.selectedProvider.apiKeyName
                            KeychainHelper.save(key: keyName, value: transcriptionApiKey)
                            transcriptionApiKey = ""
                            showingTranscriptionKeySaved = true

                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showingTranscriptionKeySaved = false
                            }
                        }
                        .controlSize(.large)
                        .disabled(transcriptionApiKey.isEmpty)
                    }

                    if showingTranscriptionKeySaved {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("API Key saved")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                        }
                    }

                    let transcriptionProvider = transcriptionProviderManager.selectedProvider
                    let keyName = transcriptionProvider.apiKeyName
                    let bundledKey = SecretsLoader.transcriptionKey(for: transcriptionProvider)

                    if let savedKey = KeychainHelper.get(key: keyName), !savedKey.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text("API Key configured")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    } else if let bundledKey = bundledKey, !bundledKey.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text("Using bundled API key")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // LLM PROVIDER
            VStack(alignment: .leading, spacing: 12) {
                Text("LLM Provider (Post-Processing)")
                    .font(.system(size: 15, weight: .semibold))

                Text("Choose your text correction service")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(LLMProvider.allCases) { provider in
                        Button(action: {
                            llmProviderManager.setProvider(provider)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(provider.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(llmProviderManager.selectedProvider == provider ? .white : .primary)

                                    Text(provider.description)
                                        .font(.system(size: 11))
                                        .foregroundStyle(llmProviderManager.selectedProvider == provider ? .white.opacity(0.8) : .secondary)
                                }

                                Spacer()

                                if llmProviderManager.selectedProvider == provider {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(llmProviderManager.selectedProvider == provider ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: llmProviderManager.selectedProvider == provider ? 0 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // LLM API Key
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.system(size: 13, weight: .medium))

                    HStack(spacing: 8) {
                        SecureField("Enter \(llmProviderManager.selectedProvider.displayName) API Key", text: $llmApiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))

                        Button("Save") {
                            let keyName = llmProviderManager.selectedProvider.apiKeyName
                            KeychainHelper.save(key: keyName, value: llmApiKey)
                            llmApiKey = ""
                            showingLLMKeySaved = true

                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showingLLMKeySaved = false
                            }
                        }
                        .controlSize(.large)
                        .disabled(llmApiKey.isEmpty)
                    }

                    if showingLLMKeySaved {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("API Key saved")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                        }
                    }

                    let llmProvider = llmProviderManager.selectedProvider
                    let keyName = llmProvider.apiKeyName
                    let bundledKey = SecretsLoader.llmKey(for: llmProvider)

                    if let savedKey = KeychainHelper.get(key: keyName), !savedKey.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text("API Key configured")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    } else if let bundledKey = bundledKey, !bundledKey.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text("Using bundled API key")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Permissions Section
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Microphone Permission
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.secondary)
                    Text("Microphone")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Grant Access") {
                            Task {
                                await AVCaptureDevice.requestAccess(for: .audio)
                            }
                        }
                        .controlSize(.small)
                    }
                }
                Text("Required to record audio for transcription")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Accessibility Permission
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.secondary)
                    Text("Accessibility")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    if AXIsProcessTrusted() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Open Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .controlSize(.small)
                    }
                }
                Text("Required to auto-paste transcriptions")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Audio Section
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Audio Input Device
            VStack(alignment: .leading, spacing: 12) {
                Text("Input Device")
                    .font(.system(size: 15, weight: .semibold))

                Text("Select your microphone or audio input device")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Picker("Audio Input", selection: $selectedAudioDevice) {
                    ForEach(audioDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device as AVCaptureDevice?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // Language Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Language")
                    .font(.system(size: 15, weight: .semibold))

                Text("Select languages for transcription. Auto-detect works for all languages.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

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
        }
    }

    // MARK: - Text Rules Section
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Add formatting rules for post-processing")
                .font(.system(size: 13))
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
            } else {
                Text("No rules added yet. Add your first rule above to start customizing text correction.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            }

            // Show combined prompt preview
            if !promptRulesManager.combinedPrompt.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Combined Prompt Preview:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(promptRulesManager.combinedPrompt)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                }
            }
        }
    }

    // MARK: - Hotkeys Section
    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Press a key combination to toggle recording from anywhere")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HotkeyRecorderView(hotkeyManager: hotkeyManager)
                .frame(height: 40)
        }
    }

    // MARK: - Helper Functions
    private func loadAudioDevices() {
        // Get all available audio input devices using discovery session
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )

        // Get all devices from the session
        audioDevices = discoverySession.devices

        // Also try to get any other audio devices not in the standard types
        #if compiler(>=6.0)
        if #available(macOS 14.0, *) {
            // On macOS 14+, we can get more device types
            let extendedSession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInMicrophone, .externalUnknown, .microphone],
                mediaType: .audio,
                position: .unspecified
            )
            audioDevices = extendedSession.devices
        }
        #endif

        // Select default device
        if selectedAudioDevice == nil {
            selectedAudioDevice = AVCaptureDevice.default(for: .audio)
        }
    }
}

#Preview {
    SettingsView(
        hotkeyManager: HotkeyManager(),
        languageManager: LanguageManager(),
        transcriptionProviderManager: TranscriptionProviderManager(),
        llmProviderManager: LLMProviderManager(),
        promptRulesManager: PromptRulesManager()
    )
}
