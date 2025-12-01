import ApplicationServices
import AVFoundation
import SwiftUI
import WhisperMateShared

// MARK: - Settings Card Component

struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                    .fill(Color.quaternarySystemFill)
            )
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case account = "Account"
    case permissions = "Permissions"
    case audio = "Audio"
    case language = "Language"
    case dictionary = "Dictionary"
    case contextRules = "Context Rules"
    case shortcuts = "Shortcuts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .account: return "person.circle"
        case .permissions: return "lock.shield"
        case .audio: return "waveform"
        case .language: return "globe"
        case .dictionary: return "book.closed"
        case .contextRules: return "text.badge.checkmark"
        case .shortcuts: return "text.word.spacing"
        }
    }

    var description: String {
        switch self {
        case .general: return "Hotkey, overlay, and startup settings"
        case .account: return "Subscription and account management"
        case .permissions: return "Microphone, accessibility, and screen recording"
        case .audio: return "Input device and audio settings"
        case .language: return "Transcription language preferences"
        case .dictionary: return "Custom word replacements and corrections"
        case .contextRules: return "App-specific formatting rules"
        case .shortcuts: return "Voice-triggered text expansions"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var languageManager: LanguageManager
    @ObservedObject var transcriptionProviderManager: TranscriptionProviderManager
    @ObservedObject var llmProviderManager: LLMProviderManager
    @ObservedObject var dictionaryManager: DictionaryManager
    @ObservedObject var contextRulesManager: ContextRulesManager
    @ObservedObject var shortcutManager: ShortcutManager
    @ObservedObject var overlayManager = OverlayWindowManager.shared
    @ObservedObject var launchAtLoginManager = LaunchAtLoginManager.shared
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var screenCaptureManager = ScreenCaptureManager.shared
    @Binding var selectedSection: SettingsSection
    @State private var transcriptionApiKey = ""
    @State private var llmApiKey = ""
    @State private var customEndpoint = ""
    @State private var customModel = ""
    @State private var showingTranscriptionKeySaved = false
    @State private var showingLLMKeySaved = false
    @State private var audioDevices: [AudioDeviceManager.AudioDevice] = []
    @State private var selectedAudioDevice: AudioDeviceManager.AudioDevice?
    @State private var selectedBillingPeriod: BillingPeriod = .monthly
    @State private var isCheckingPayment = false
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
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedSection {
                    case .general:
                        generalSection
                    case .account:
                        accountSection
                    case .permissions:
                        permissionsSection
                    case .audio:
                        audioSection
                    case .language:
                        languageSection
                    case .dictionary:
                        dictionarySection
                    case .contextRules:
                        contextRulesSection
                    case .shortcuts:
                        shortcutsSection
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            loadAudioDevices()
        }
        .onChange(of: selectedAudioDevice) { newValue in
            saveSelectedAudioDevice(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AudioDeviceListChanged"))) { _ in
            loadAudioDevices()
        }
        .onDisappear {
            stopPaymentConfirmationCheck()
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Account Status Card
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    if authManager.isAuthenticated, let user = authManager.currentUser {
                        // Email
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Account")
                                    .dsFont(.body)
                                    .foregroundStyle(Color.dsForeground)
                                Text(user.email)
                                    .dsFont(.label)
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                            Spacer()
                            Button("Sign Out") {
                                Task {
                                    await AuthManager.shared.logout()
                                }
                            }
                            .controlSize(.small)
                        }

                        Divider()

                        // Subscription Status
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Subscription")
                                    .dsFont(.body)
                                    .foregroundStyle(Color.dsForeground)
                                Text(user.subscriptionTier == .pro ? "Pro" : "Free")
                                    .dsFont(.label)
                                    .foregroundStyle(user.subscriptionTier == .pro ? Color.dsSecondary : Color.dsMutedForeground)
                            }
                            Spacer()
                        }

                        // Word Usage (only for Free tier)
                        if user.subscriptionTier == .free {
                            Divider()

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Word Usage")
                                        .dsFont(.body)
                                        .foregroundStyle(Color.dsForeground)
                                    Text("\(user.monthlyWordCount) of 2,000 words this month")
                                        .dsFont(.label)
                                        .foregroundStyle(Color.dsMutedForeground)
                                }
                                Spacer()
                            }
                        }
                    } else {
                        // Not signed in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Account")
                                    .dsFont(.body)
                                    .foregroundStyle(Color.dsForeground)
                                Text("Sign in to track usage and unlock Pro features")
                                    .dsFont(.label)
                                    .foregroundStyle(Color.dsMutedForeground)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Button("Sign In") {
                                authManager.openSignUp()
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }

            // Upgrade Card (only for Free tier or not signed in)
            if !authManager.isAuthenticated || authManager.currentUser?.subscriptionTier == .free {
                SettingsCard {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upgrade to Pro")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            if isCheckingPayment {
                                Text("Checking for payment confirmation...")
                                    .dsFont(.label)
                                    .foregroundStyle(Color.dsMutedForeground)
                            } else {
                                Text("Unlimited transcriptions, priority support")
                                    .dsFont(.label)
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                        }
                        Spacer()
                        if isCheckingPayment {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("Upgrade") {
                                openPaymentLink()
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }

            // Reset Application
            SettingsCard {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset Application")
                            .dsFont(.body)
                            .foregroundStyle(Color.dsForeground)
                        Text("Clear all data and restart onboarding")
                            .dsFont(.label)
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                    Spacer()
                    Button("Reset") {
                        resetApplication()
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private func openPaymentLink() {
        let paymentLinkKey: String
        switch selectedBillingPeriod {
        case .monthly:
            paymentLinkKey = "STRIPE_PAYMENT_LINK_MONTHLY"
        case .annual:
            paymentLinkKey = "STRIPE_PAYMENT_LINK_ANNUAL"
        case .lifetime:
            paymentLinkKey = "STRIPE_PAYMENT_LINK_LIFETIME"
        @unknown default:
            paymentLinkKey = "STRIPE_PAYMENT_LINK_MONTHLY"
        }

        guard let paymentLinkString = SecretsLoader.getValue(for: paymentLinkKey),
              var paymentURL = URL(string: paymentLinkString)
        else {
            DebugLog.error("Invalid payment link", context: "SettingsView")
            return
        }

        // Add user email as query parameter if authenticated
        if let email = authManager.currentUser?.email,
           let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        {
            var components = URLComponents(url: paymentURL, resolvingAgainstBaseURL: false)
            var queryItems = components?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "prefilled_email", value: encodedEmail))
            components?.queryItems = queryItems
            if let urlWithEmail = components?.url {
                paymentURL = urlWithEmail
            }
        }

        #if canImport(AppKit)
            NSWorkspace.shared.open(paymentURL)
        #endif

        // Start checking for payment confirmation
        startPaymentConfirmationCheck()
    }

    private func startPaymentConfirmationCheck() {
        isCheckingPayment = true
        DebugLog.info("Starting payment confirmation check", context: "SettingsView")

        Task {
            // Poll for up to 10 minutes (120 checks every 5 seconds)
            for _ in 0 ..< 120 {
                guard isCheckingPayment else { break }

                // Wait 5 seconds between checks
                try? await Task.sleep(nanoseconds: 5_000_000_000)

                // Refresh user data
                await authManager.refreshUser()

                // Check if subscription status changed to pro
                if authManager.currentUser?.subscriptionTier == .pro {
                    DebugLog.info("✅ Payment confirmed! User is now Pro", context: "SettingsView")
                    await MainActor.run {
                        isCheckingPayment = false
                    }
                    break
                }
            }

            // Stop checking after 10 minutes
            await MainActor.run {
                isCheckingPayment = false
            }
        }
    }

    private func stopPaymentConfirmationCheck() {
        isCheckingPayment = false
    }

    private func resetApplication() {
        DebugLog.info("🔄 Resetting application state", context: "SettingsView")

        Task {
            // 1. Sign out user
            if authManager.isAuthenticated {
                await authManager.logout()
            }

            await MainActor.run {
                // 2. Clear all UserDefaults
                if let bundleID = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundleID)
                    UserDefaults.standard.synchronize()
                }

                // 3. Clear Keychain (API keys)
                KeychainHelper.delete(key: "GroqTranscriptionKey")
                KeychainHelper.delete(key: "GroqLLMKey")
                KeychainHelper.delete(key: "CustomTranscriptionKey")

                // 4. Reset onboarding
                OnboardingManager.shared.resetOnboarding()

                // 5. Close settings window
                dismiss()

                DebugLog.info("✅ Application reset complete", context: "SettingsView")
            }
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Recording Hotkey Settings Group
            SettingsCard {
                VStack(spacing: 0) {
                    // Recording Hotkey
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recording Hotkey")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text("Shortcut to start and stop recording")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        Spacer()
                        HotkeyRecorderView(hotkeyManager: hotkeyManager)
                    }
                    .padding(.vertical, 2)

                    Divider()
                        .padding(.vertical, 6)

                    // Push-to-Talk Toggle
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Push to Talk")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text(hotkeyManager.isPushToTalk ? "Hold to record, release to stop" : "Press to start, press again to stop")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        Spacer()
                        Toggle("", isOn: $hotkeyManager.isPushToTalk)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                    }
                    .padding(.vertical, 2)
                }
            }

            // Overlay Settings Group
            SettingsCard {
                VStack(spacing: 0) {
                    // Show Overlay When Idle
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Overlay When Idle")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text("Display the overlay even when not recording")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
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
                    .padding(.vertical, 2)

                    Divider()
                        .padding(.vertical, 6)

                    // Overlay Position
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Overlay Position")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text("Where the recording indicator appears")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
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
                    .padding(.vertical, 2)
                }
            }

            // Startup & Screen Context Group
            SettingsCard {
                VStack(spacing: 0) {
                    // Launch at Login
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text("Automatically start when you log in")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { launchAtLoginManager.isEnabled },
                            set: { _ in launchAtLoginManager.toggle() }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)

                    Divider()
                        .padding(.vertical, 6)

                    // Screen Context
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include Screen Context")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text("Use screen content to improve transcription")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { screenCaptureManager.includeScreenContext },
                            set: { newValue in
                                if newValue, !screenCaptureManager.hasScreenRecordingPermission {
                                    screenCaptureManager.requestScreenRecordingPermission()
                                }
                                screenCaptureManager.includeScreenContext = newValue
                            }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // All Permissions in one card
            SettingsCard {
                VStack(spacing: 0) {
                    // Microphone Permission
                    HStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(Color.dsMutedForeground)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Microphone")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text("Required to capture your voice for transcription")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        Spacer()
                        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.dsSecondary)
                        } else {
                            Button("Grant Access") {
                                Task {
                                    await AVCaptureDevice.requestAccess(for: .audio)
                                }
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 2)

                    Divider()
                        .padding(.vertical, 6)

                    // Accessibility Permission
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(Color.dsMutedForeground)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text("Needed for global hotkeys and text insertion")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        Spacer()
                        if AXIsProcessTrusted() {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.dsSecondary)
                        } else {
                            Button("Open Settings") {
                                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
                                let _ = AXIsProcessTrustedWithOptions(options)
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 2)

                    Divider()
                        .padding(.vertical, 6)

                    // Screen Recording Permission
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.dashed.badge.record")
                            .foregroundStyle(Color.dsMutedForeground)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Recording")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text("Optional, enables context-aware transcription")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        Spacer()
                        if screenCaptureManager.hasScreenRecordingPermission {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.dsSecondary)
                        } else {
                            Button("Grant Access") {
                                screenCaptureManager.requestScreenRecordingPermission()
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Audio Settings Group
            SettingsCard {
                VStack(spacing: 0) {
                    // Input Device
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Input Device")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text("Select which microphone to use for recording")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        Spacer()
                        Picker("", selection: $selectedAudioDevice) {
                            ForEach(audioDevices) { device in
                                Text(device.localizedName).tag(device as AudioDeviceManager.AudioDevice?)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    .padding(.vertical, 2)

                    Divider()
                        .padding(.vertical, 6)

                    // Mute Other Audio
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mute Other Audio")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text("Pause system audio while recording")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: "muteAudioWhenRecording") as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: "muteAudioWhenRecording") }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Language Section

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transcription Language")
                                .dsFont(.body)
                                .foregroundStyle(Color.dsForeground)
                            Text("Select languages for transcription. Auto-detect works for all languages.")
                                .dsFont(.label)
                                .foregroundStyle(Color.dsMutedForeground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 140)),
                    ], spacing: 8) {
                        ForEach(Language.allCases) { language in
                            Button(action: {
                                languageManager.toggleLanguage(language)
                            }) {
                                HStack(spacing: 8) {
                                    Text(language.flag)
                                        .dsFont(.body)

                                    Text(language.displayName)
                                        .dsFont(.body)
                                        .foregroundStyle(languageManager.isSelected(language) ? .white : Color.dsForeground)
                                        .lineLimit(1)

                                    Spacer()

                                    if languageManager.isSelected(language) {
                                        Image(systemName: "checkmark")
                                            .dsFont(.tinyBold)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: DSCornerRadius.small)
                                        .fill(languageManager.isSelected(language) ? Color.dsPrimary : Color.dsCard)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DSCornerRadius.small)
                                        .stroke(Color.dsBorder, lineWidth: languageManager.isSelected(language) ? 0 : 1)
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

    private var dictionarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DictionaryTabView(manager: dictionaryManager)
        }
    }

    private var contextRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContextRulesTabView(manager: contextRulesManager)
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShortcutsTabView(manager: shortcutManager)
        }
    }

    // MARK: - Helper Functions

    private func loadAudioDevices() {
        // Get all available audio input devices using Core Audio
        audioDevices = AudioDeviceManager.shared.getInputDevices()

        // Select saved device or default
        if selectedAudioDevice == nil {
            if let savedDeviceID = UserDefaults.standard.string(forKey: "selectedAudioDeviceID"),
               let savedDevice = audioDevices.first(where: { $0.uniqueID == savedDeviceID })
            {
                selectedAudioDevice = savedDevice
            } else {
                selectedAudioDevice = AudioDeviceManager.shared.getDefaultInputDevice()
            }
        }
    }

    private func saveSelectedAudioDevice(_ device: AudioDeviceManager.AudioDevice?) {
        if let device = device {
            UserDefaults.standard.set(device.uniqueID, forKey: "selectedAudioDeviceID")
            DebugLog.info("Setting audio device: \(device.localizedName)", context: "SettingsView")

            // Set as system default so AVAudioEngine will use it
            let success = AudioDeviceManager.shared.setDefaultInputDevice(deviceID: device.id)
            if success {
                DebugLog.info("Successfully set default input device", context: "SettingsView")

                // Notify AudioRecorder about the change
                NotificationCenter.default.post(
                    name: NSNotification.Name("AudioInputDeviceChanged"),
                    object: device.uniqueID
                )
            } else {
                DebugLog.info("Failed to set default input device", context: "SettingsView")
            }
        }
    }

    private func setupDeviceNotifications() {
        // Listen for device list changes from Core Audio
        // Using .onReceive in SwiftUI instead of NotificationCenter for proper lifecycle management
    }

    private func removeDeviceNotifications() {
        // Handled by SwiftUI's .onReceive lifecycle
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
                .dsFont(.body)
                .foregroundStyle(rule.isEnabled ? Color.dsForeground : Color.dsMutedForeground)

            Spacer()

            // Delete button (visible on hover) - always present to prevent height changes
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .dsFont(.body)
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
                .fill(Color.dsCard)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.dsBorder),
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
                dictionaryManager: DictionaryManager.shared,
                contextRulesManager: ContextRulesManager.shared,
                shortcutManager: ShortcutManager.shared,
                selectedSection: $selectedSection
            )
        }
    }

    return PreviewWrapper()
}
