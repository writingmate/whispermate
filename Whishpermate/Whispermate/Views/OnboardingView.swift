import SwiftUI

struct OnboardingView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var promptRulesManager: PromptRulesManager

    @State private var isCheckingAccessibility = false
    @State private var newRuleText = ""
    @State private var exampleText = "I have two apples and three oranges"
    @State private var processedText = ""
    @State private var isProcessingExample = false

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
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Content area
            ScrollView {
                VStack(spacing: onboardingManager.currentStep == .prompts ? 16 : 24) {
                    // Icon (hidden for prompts step to save space)
                    if onboardingManager.currentStep != .prompts {
                        Image(systemName: onboardingManager.currentStep.icon)
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)
                    }

                    // Title
                    Text(onboardingManager.currentStep.title)
                        .font(.system(size: 24, weight: .semibold))

                    // Explanation
                    Text(onboardingManager.currentStep.explanation)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 48)
                        .fixedSize(horizontal: false, vertical: true)

                    // Step-specific content with conditional spacing
                    if onboardingManager.currentStep == .prompts {
                        Spacer().frame(height: 8)
                    } else {
                        Spacer().frame(height: 16)
                    }

                    stepContent
                }
                .padding(.bottom, 16)
            }
            .frame(maxHeight: .infinity)

            // Bottom action button
            bottomButton
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
        .frame(width: 520, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Defer hotkey registration during onboarding
            hotkeyManager.setDeferRegistration(true)

            // Start polling for accessibility permission if on that step
            if onboardingManager.currentStep == .accessibility {
                startAccessibilityCheck()
            }
        }
        .onChange(of: onboardingManager.currentStep) { newStep in
            if newStep == .accessibility {
                startAccessibilityCheck()
            } else {
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
            Spacer()
                .frame(height: 1)

        case .accessibility:
            if onboardingManager.isAccessibilityGranted() {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Permission granted")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                }
            } else {
                Spacer()
                    .frame(height: 1)
            }

        case .hotkey:
            VStack(spacing: 12) {
                HotkeyRecorderView(hotkeyManager: hotkeyManager)
                    .frame(height: 40)

                if hotkeyManager.currentHotkey != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Hotkey configured")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("Tip: Fn key works best")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

        case .prompts:
            VStack(spacing: 12) {
                // Show current rules
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(promptRulesManager.rules) { rule in
                        HStack(spacing: 8) {
                            Button(action: {
                                promptRulesManager.toggleRule(rule)
                            }) {
                                Image(systemName: rule.isEnabled ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(rule.isEnabled ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.plain)

                            Text(rule.text)
                                .font(.system(size: 12))
                                .foregroundStyle(rule.isEnabled ? .primary : .secondary)
                                .strikethrough(!rule.isEnabled)

                            Spacer()

                            Button(action: {
                                promptRulesManager.removeRule(rule)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }

                    // Add new rule
                    HStack(spacing: 6) {
                        TextField("Add custom rule...", text: $newRuleText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
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
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(newRuleText.isEmpty)
                    }
                }

                // Live preview section with divider
                HStack {
                    VStack { Divider() }
                    Text("See it in action")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                    VStack { Divider() }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        TextField("Try example text...", text: $exampleText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))

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
                                    .font(.system(size: 16))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(exampleText.isEmpty || isProcessingExample)
                    }

                    if !processedText.isEmpty {
                        Text(processedText)
                            .font(.system(size: 11))
                            .foregroundStyle(.primary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: 420)
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        switch onboardingManager.currentStep {
        case .microphone:
            Button(action: {
                onboardingManager.requestMicrophonePermission()
            }) {
                Text("Enable Microphone")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(onboardingManager.isAccessibilityGranted() ? Color.accentColor : Color.orange)
                    )
            }
            .buttonStyle(.plain)

        case .hotkey:
            Button(action: {
                onboardingManager.moveToNextStep()
            }) {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(hotkeyManager.currentHotkey != nil ? Color.accentColor : Color.gray)
                    )
            }
            .buttonStyle(.plain)
            .disabled(hotkeyManager.currentHotkey == nil)

        case .prompts:
            Button(action: {
                onboardingManager.markPromptsAsSeen()
                onboardingManager.completeOnboarding()
            }) {
                Text("Get Started")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Accessibility Checking

    private func startAccessibilityCheck() {
        isCheckingAccessibility = true
        checkAccessibilityPeriodically()
    }

    private func stopAccessibilityCheck() {
        isCheckingAccessibility = false
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

            // Get LLM API key
            let llmProvider = LLMProvider.groq // Default to Groq for demo
            guard let llmApiKey = KeychainHelper.get(key: llmProvider.apiKeyName) ?? SecretsLoader.llmKey(for: llmProvider) else {
                await MainActor.run {
                    processedText = "⚠️ No LLM API key configured. The rules will be applied during actual transcription."
                    isProcessingExample = false
                }
                return
            }

            // Create GroqService instance
            let groqService = GroqService(
                transcriptionApiKey: "", // Not needed for LLM-only
                transcriptionEndpoint: "",
                transcriptionModel: "",
                llmApiKey: llmApiKey,
                llmEndpoint: "https://api.groq.com/openai/v1/chat/completions",
                llmModel: "llama-3.3-70b-versatile"
            )

            // Process text with rules
            let result = try await groqService.fixText(exampleText, rules: enabledRules)

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
