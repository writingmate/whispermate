import SwiftUI
import AVFoundation
import ApplicationServices

// MARK: - Settings Card Component
struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.quaternarySystemFill)
            )
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case permissions = "Permissions"
    case audio = "Audio"
    case rules = "Text Rules"
    case hotkeys = "Hotkeys"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
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
    @ObservedObject var overlayManager = OverlayWindowManager.shared
    @Binding var selectedSection: SettingsSection
    @State private var transcriptionApiKey = ""
    @State private var llmApiKey = ""
    @State private var customEndpoint = ""
    @State private var customModel = ""
    @State private var showingTranscriptionKeySaved = false
    @State private var showingLLMKeySaved = false
    @State private var newRuleText = ""
    @State private var audioDevices: [AVCaptureDevice] = []
    @State private var selectedAudioDevice: AVCaptureDevice?
    @State private var exampleText = "I have two apples and three oranges"
    @State private var processedText = ""
    @State private var isProcessingExample = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
            .listStyle(.sidebar)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedSection {
                    case .general:
                        generalSection
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
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            loadAudioDevices()
        }
    }

    // MARK: - General Section
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // SHOW OVERLAY WHEN IDLE
            SettingsCard {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Overlay When Idle")
                            .font(.system(size: 13))
                        Text("When disabled, overlay only appears during recording or processing")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { !overlayManager.hideIdleState },
                        set: { overlayManager.hideIdleState = !$0 }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                }
            }

            // OVERLAY POSITION
            SettingsCard {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Overlay Position")
                            .font(.system(size: 13))
                        Text("Choose where the overlay indicator appears on your screen")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Picker("", selection: $overlayManager.position) {
                        ForEach(OverlayPosition.allCases, id: \.self) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
        }
    }

    // MARK: - Permissions Section
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Microphone Permission
            SettingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.secondary)
                        Text("Microphone")
                            .font(.system(size: 13))
                        Spacer()
                        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(nsColor: .systemGreen))
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
            }

            // Accessibility Permission
            SettingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.secondary)
                        Text("Accessibility")
                            .font(.system(size: 13))
                        Spacer()
                        if AXIsProcessTrusted() {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(nsColor: .systemGreen))
                        } else {
                            Button("Open Settings") {
                                // Trigger the accessibility permission dialog
                                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
                                let _ = AXIsProcessTrustedWithOptions(options)
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
    }

    // MARK: - Audio Section
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Audio Input Device
            SettingsCard {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Input Device")
                            .font(.system(size: 13))
                        Text("Select your microphone or audio input device")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Picker("", selection: $selectedAudioDevice) {
                        ForEach(audioDevices, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device as AVCaptureDevice?)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }

            // Language Selection
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Language")
                                .font(.system(size: 13))
                            Text("Select languages for transcription. Auto-detect works for all languages.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 140))
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
                                        .lineLimit(1)

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
    }

    // MARK: - Text Rules Section
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Rules table
            RulesTable(
                promptRulesManager: promptRulesManager,
                newRuleText: $newRuleText
            )

            // Live preview section with divider
            HStack {
                VStack { Divider() }
                Text("See it in action")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                VStack { Divider() }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Try example text...", text: $exampleText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Button(action: {
                        Task {
                            await processExample()
                        }
                    }) {
                        if isProcessingExample {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 18))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(exampleText.isEmpty || isProcessingExample)
                }

                if !processedText.isEmpty {
                    Text(processedText)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                }
            }
        }
    }

    // MARK: - Hotkeys Section
    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recording Hotkey")
                            .font(.system(size: 13))
                        Text("Press a key combination to toggle recording from anywhere")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    HotkeyRecorderView(hotkeyManager: hotkeyManager)
                        .frame(width: 200, height: 28)
                }
            }
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

    private func processExample() async {
        guard !exampleText.isEmpty else { return }

        isProcessingExample = true
        processedText = ""

        do {
            // Get enabled rules
            let enabledRules = promptRulesManager.rules.filter { $0.isEnabled }.map { $0.text }

            // Get LLM provider settings
            let llmProvider = llmProviderManager.selectedProvider
            guard let llmApiKey = KeychainHelper.get(key: llmProvider.apiKeyName) ?? SecretsLoader.llmKey(for: llmProvider) else {
                await MainActor.run {
                    processedText = "⚠️ No LLM API key configured. The rules will be applied during actual transcription."
                    isProcessingExample = false
                }
                return
            }

            // Create OpenAI client for LLM processing using configured provider
            let clientConfig = OpenAIClient.Configuration(
                chatCompletionEndpoint: llmProviderManager.effectiveEndpoint,
                chatCompletionModel: llmProviderManager.effectiveModel,
                apiKey: llmApiKey
            )

            let openAIClient = OpenAIClient(config: clientConfig)

            // Process text with rules
            let result = try await openAIClient.applyFormattingRules(transcription: exampleText, rules: enabledRules)

            await MainActor.run {
                processedText = result
                isProcessingExample = false
            }
        } catch {
            await MainActor.run {
                processedText = "Error: \(error.localizedDescription)"
                isProcessingExample = false
            }
        }
    }
}

// MARK: - Rule Row Component
struct RuleRow: View {
    let rule: PromptRule
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Rule text
            Text(rule.text)
                .font(.system(size: 13))
                .foregroundStyle(rule.isEnabled ? .primary : .secondary)

            Spacer()

            // Delete button (visible on hover) - always present to prevent height changes
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(width: 16, height: 16)
            .opacity(isHovering ? 1 : 0)

            // Toggle switch
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedSection: SettingsSection = .general

        var body: some View {
            SettingsView(
                hotkeyManager: HotkeyManager.shared,
                languageManager: LanguageManager(),
                transcriptionProviderManager: TranscriptionProviderManager(),
                llmProviderManager: LLMProviderManager(),
                promptRulesManager: PromptRulesManager.shared,
                selectedSection: $selectedSection
            )
        }
    }

    return PreviewWrapper()
}
