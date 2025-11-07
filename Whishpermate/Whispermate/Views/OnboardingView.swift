import SwiftUI

struct OnboardingView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var languageManager: LanguageManager
    @ObservedObject var promptRulesManager: PromptRulesManager
    @ObservedObject var llmProviderManager: LLMProviderManager

    @State private var isCheckingAccessibility = false
    @State private var isCheckingMicrophone = false
    @State private var newRuleText = ""
    @State private var exampleText = "I have two apples and three oranges"
    @State private var processedText = ""
    @State private var isProcessingExample = false
    @State private var fnKeyMonitor: FnKeyMonitor?
    @State private var showCustomHotkeyPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= onboardingManager.currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 20)

            // Content area
            ScrollView {
                VStack(spacing: 20) {
                    // Icon
                    Image(systemName: onboardingManager.currentStep.icon)
                        .font(.system(size: 64))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 8)

                    // Title
                    Text(onboardingManager.currentStep.title)
                        .font(.system(size: 24, weight: .semibold))

                    // Explanation
                    Text(onboardingManager.currentStep.explanation)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 60)
                        .fixedSize(horizontal: false, vertical: true)

                    stepContent
                        .padding(.top, 4)
                }
                .padding(.bottom, 20)
            }
            .frame(maxHeight: .infinity)
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.92),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Bottom action button
            bottomButton
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
        }
        .frame(width: 560, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Defer hotkey registration during onboarding
            hotkeyManager.setDeferRegistration(true)

            // Start polling for permissions based on current step
            if onboardingManager.currentStep == .microphone {
                startMicrophoneCheck()
            } else if onboardingManager.currentStep == .accessibility {
                startAccessibilityCheck()
            }
        }
        .onChange(of: onboardingManager.currentStep) { newStep in
            if newStep == .microphone {
                startMicrophoneCheck()
                stopAccessibilityCheck()
            } else if newStep == .accessibility {
                stopMicrophoneCheck()
                startAccessibilityCheck()
            } else {
                stopMicrophoneCheck()
                stopAccessibilityCheck()
            }
        }
        .onDisappear {
            // Enable hotkey registration when onboarding completes
            hotkeyManager.setDeferRegistration(false)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch onboardingManager.currentStep {
        case .microphone:
            if onboardingManager.isMicrophoneGranted() {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(nsColor: .systemGreen))
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: true)

                    Text("Permission granted")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(nsColor: .systemGreen))
                }
                .padding(.vertical, 20)
            } else {
                Spacer()
                    .frame(height: 1)
            }

        case .accessibility:
            if onboardingManager.isAccessibilityGranted() {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(nsColor: .systemGreen))
                        .scaleEffect(onboardingManager.accessibilityGranted ? 1.0 : 0.5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: onboardingManager.accessibilityGranted)

                    Text("Permission granted")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(nsColor: .systemGreen))
                }
                .padding(.vertical, 20)
            } else {
                Spacer()
                    .frame(height: 1)
            }

        case .language:
            VStack(spacing: 12) {
                // Language grid
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
                .padding(.horizontal, 40)
            }

        case .hotkey:
            if showCustomHotkeyPicker {
                // Custom hotkey selection view
                VStack(spacing: 16) {
                    Text("Set your preferred hotkey")
                        .font(.system(size: 14, weight: .medium))

                    HotkeyRecorderView(hotkeyManager: hotkeyManager)
                        .frame(maxWidth: 300)

                    Button(action: {
                        showCustomHotkeyPicker = false
                        stopFnKeyMonitoring()
                    }) {
                        Text("Back to Fn key")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
            } else {
                // Default view with Fn key option
                VStack(spacing: 12) {
                    // Fn key option (visual representation)
                    Text("Fn")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(hotkeyManager.currentHotkey?.keyCode == 63 ? Color(nsColor: .systemGreen) : .primary)
                        .frame(width: 100, height: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.quaternarySystemFill)
                                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(hotkeyManager.currentHotkey?.keyCode == 63 ? Color(nsColor: .systemGreen) : Color.clear, lineWidth: 3)
                        )

                    if hotkeyManager.currentHotkey?.keyCode == 63 {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(nsColor: .systemGreen))
                            Text("Fn key detected")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(nsColor: .systemGreen))
                        }
                    } else {
                        Text("Press Fn to use it")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    // Small text link to select custom hotkey
                    Button(action: {
                        showCustomHotkeyPicker = true
                        stopFnKeyMonitoring()
                    }) {
                        Text("Use a different hotkey")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .onAppear {
                    // Start monitoring for Fn key press
                    startFnKeyMonitoring()
                }
                .onDisappear {
                    // Stop monitoring when leaving this step
                    stopFnKeyMonitoring()
                }
            }
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        switch onboardingManager.currentStep {
        case .microphone:
            Button(action: {
                if onboardingManager.isMicrophoneGranted() {
                    onboardingManager.moveToNextStep()
                } else {
                    onboardingManager.requestMicrophonePermission()
                }
            }) {
                Text(onboardingManager.isMicrophoneGranted() ? "Continue" : "Enable Microphone")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)

        case .accessibility:
            Button(action: {
                if onboardingManager.isAccessibilityGranted() {
                    onboardingManager.moveToNextStep()
                } else {
                    onboardingManager.requestAccessibilityPermission()
                }
            }) {
                Text(onboardingManager.isAccessibilityGranted() ? "Continue" : "Open System Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(onboardingManager.isAccessibilityGranted() ? Color.accentColor : Color(nsColor: .systemOrange))
                    )
            }
            .buttonStyle(.plain)

        case .language:
            Button(action: {
                onboardingManager.moveToNextStep()
            }) {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)

        case .hotkey:
            Button(action: {
                onboardingManager.completeOnboarding()
            }) {
                Text("Get Started")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(hotkeyManager.currentHotkey != nil ? Color.accentColor : Color.gray)
                    )
            }
            .buttonStyle(.plain)
            .disabled(hotkeyManager.currentHotkey == nil)
        }
    }

    // MARK: - Permission Checking

    private func startMicrophoneCheck() {
        isCheckingMicrophone = true
        checkMicrophonePeriodically()
    }

    private func stopMicrophoneCheck() {
        isCheckingMicrophone = false
    }

    private func checkMicrophonePeriodically() {
        guard isCheckingMicrophone else { return }

        // Update microphone status (this will trigger view refresh via @Published property)
        onboardingManager.updateMicrophoneStatus()

        // Check if microphone is now granted
        if onboardingManager.isMicrophoneGranted() {
            // Permission granted! Stop checking
            isCheckingMicrophone = false
            return
        }

        // Check again in 0.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkMicrophonePeriodically()
        }
    }

    private func startAccessibilityCheck() {
        isCheckingAccessibility = true
        checkAccessibilityPeriodically()
    }

    private func stopAccessibilityCheck() {
        isCheckingAccessibility = false
    }

    private func startFnKeyMonitoring() {
        DebugLog.info("Starting Fn key monitoring", context: "OnboardingView")
        fnKeyMonitor = FnKeyMonitor()
        fnKeyMonitor?.onFnPressed = { [self] in
            DebugLog.info("Fn key pressed - setting hotkey", context: "OnboardingView")
            hotkeyManager.setHotkey(Hotkey(keyCode: 63, modifiers: .function))
            stopFnKeyMonitoring()
        }
        fnKeyMonitor?.startMonitoring()
    }

    private func stopFnKeyMonitoring() {
        DebugLog.info("Stopping Fn key monitoring", context: "OnboardingView")
        fnKeyMonitor?.stopMonitoring()
        fnKeyMonitor = nil
    }

    private func checkAccessibilityPeriodically() {
        guard isCheckingAccessibility else { return }

        // Update accessibility status (this will trigger view refresh)
        onboardingManager.updateAccessibilityStatus()

        // Check if accessibility is now granted
        if onboardingManager.isAccessibilityGranted() {
            // Permission granted! Stop checking
            isCheckingAccessibility = false
            return
        }

        // Check again in 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAccessibilityPeriodically()
        }
    }

    // MARK: - LLM Preview

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
