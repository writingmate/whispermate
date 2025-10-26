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
    @State private var fnKeyMonitor: FnKeyMonitor?

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
                    // Icon (hidden for prompts step to save space)
                    if onboardingManager.currentStep != .prompts {
                        Image(systemName: onboardingManager.currentStep.icon)
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)
                            .padding(.top, 8)
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
                        .padding(.horizontal, 60)
                        .fixedSize(horizontal: false, vertical: true)

                    stepContent
                        .padding(.top, 4)
                }
                .padding(.bottom, 20)
            }
            .frame(maxHeight: .infinity)

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

            // Center the onboarding window on screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Find the sheet window - it's a titled window that's not the main borderless window
                let windows = NSApplication.shared.windows
                print("[OnboardingView] Found \(windows.count) windows")

                for (index, window) in windows.enumerated() {
                    print("[OnboardingView] Window \(index): visible=\(window.isVisible), level=\(window.level.rawValue), styleMask=\(window.styleMask.rawValue), title=\(window.title)")
                }

                if let sheetWindow = windows.first(where: { $0.isVisible && $0.styleMask.contains(.titled) }) {
                    print("[OnboardingView] Found sheet window: \(sheetWindow.title)")
                    if let screen = NSScreen.main {
                        let screenFrame = screen.visibleFrame
                        let windowFrame = sheetWindow.frame
                        let x = screenFrame.midX - windowFrame.width / 2
                        let y = screenFrame.midY - windowFrame.height / 2
                        print("[OnboardingView] Centering window at x=\(x), y=\(y)")
                        sheetWindow.setFrameOrigin(NSPoint(x: x, y: y))
                    }
                } else {
                    print("[OnboardingView] ⚠️ Could not find sheet window to center")
                }
            }

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
                // Fn key button (square)
                Text("Fn")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(hotkeyManager.currentHotkey?.keyCode == 63 ? .green : .primary)
                    .frame(width: 100, height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(hotkeyManager.currentHotkey?.keyCode == 63 ? Color.green : Color.clear, lineWidth: 3)
                    )

                if hotkeyManager.currentHotkey?.keyCode == 63 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Fn key detected")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("Press Fn")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                // Start monitoring for Fn key press
                startFnKeyMonitoring()
            }
            .onDisappear {
                // Stop monitoring when leaving this step
                stopFnKeyMonitoring()
            }

        case .prompts:
            VStack(spacing: 16) {
                // Show current rules
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(promptRulesManager.rules) { rule in
                        HStack(spacing: 10) {
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }

                    // Add new rule
                    HStack(spacing: 8) {
                        TextField("Add custom rule...", text: $newRuleText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
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
                                .font(.system(size: 18))
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
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
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

    private func startFnKeyMonitoring() {
        print("[OnboardingView] Starting Fn key monitoring")
        fnKeyMonitor = FnKeyMonitor()
        fnKeyMonitor?.onFnPressed = { [self] in
            print("[OnboardingView] Fn key pressed - setting hotkey")
            hotkeyManager.setHotkey(Hotkey(keyCode: 63, modifiers: .function))
            stopFnKeyMonitoring()
        }
        fnKeyMonitor?.startMonitoring()
    }

    private func stopFnKeyMonitoring() {
        print("[OnboardingView] Stopping Fn key monitoring")
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
