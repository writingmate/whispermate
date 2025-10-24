import SwiftUI

struct OnboardingView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject var hotkeyManager: HotkeyManager

    @State private var isCheckingAccessibility = false

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
            VStack(spacing: 24) {
                // Icon
                Image(systemName: onboardingManager.currentStep.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)

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

                Spacer().frame(height: 16)

                // Step-specific content
                stepContent
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
                Text("✓ Permission granted!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.green)
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
                    Text("Tip: Fn key works best. For F-keys, enable them in System Settings → Keyboard")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
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
                onboardingManager.completeOnboarding()
            }) {
                Text("Get Started")
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
}
