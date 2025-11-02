import Foundation
internal import Combine
import AVFoundation
import ApplicationServices
import AppKit
import CoreGraphics

enum OnboardingStep: Int, CaseIterable {
    case microphone = 0
    case accessibility = 1
    case language = 2
    case hotkey = 3
    case prompts = 4

    var title: String {
        switch self {
        case .microphone: return "Enable Microphone"
        case .accessibility: return "Enable Accessibility"
        case .language: return "Select Your Languages"
        case .hotkey: return "Set Your Hotkey"
        case .prompts: return "Configure Text Rules"
        }
    }

    var icon: String {
        switch self {
        case .microphone: return "mic.circle.fill"
        case .accessibility: return "hand.tap.fill"
        case .language: return "globe"
        case .hotkey: return "keyboard.fill"
        case .prompts: return "text.badge.checkmark"
        }
    }

    var explanation: String {
        switch self {
        case .microphone:
            return "Whispermate needs access to your microphone to record your voice for transcription."
        case .accessibility:
            return "Whispermate needs accessibility permissions to automatically paste transcriptions into your apps."
        case .language:
            return "Select the languages you speak. You can choose multiple languages or use auto-detect."
        case .hotkey:
            return "Choose your preferred hotkey to control recording. Press and hold to record, or double-tap to start/stop long recording."
        case .prompts:
            return "Add rules to improve transcription quality. You can enable/disable, add, or delete rules anytime in settings."
        }
    }
}

class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    @Published var showOnboarding: Bool = false
    @Published var currentStep: OnboardingStep = .microphone
    @Published var accessibilityGranted: Bool = false
    @Published var microphoneGranted: Bool = false

    private let onboardingCompletedKey = "has_completed_onboarding"

    private init() {
        accessibilityGranted = AXIsProcessTrusted()
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        // Don't call checkOnboardingStatus() here - let the view call it in onAppear
        // This ensures the onChange modifier is registered before the state changes
    }

    func updateAccessibilityStatus() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func updateMicrophoneStatus() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func checkOnboardingStatus() {
        DebugLog.info("Checking onboarding status", context: "OnboardingManager")

        // Check if user has completed onboarding before
        let hasCompleted = UserDefaults.standard.bool(forKey: onboardingCompletedKey)

        if hasCompleted {
            // Even if completed, check if all permissions are still granted
            let allGranted = checkAllPermissions()
            showOnboarding = !allGranted

            if !allGranted {
                DebugLog.info("Permissions revoked, showing onboarding again", context: "OnboardingManager")
                // Find first non-granted permission
                currentStep = findFirstIncompleteStep()
            } else {
                DebugLog.info("All permissions granted, skipping onboarding", context: "OnboardingManager")
            }
        } else {
            // First time launch - always show onboarding
            DebugLog.info("First launch, showing onboarding", context: "OnboardingManager")
            showOnboarding = true
            currentStep = .microphone
        }
    }

    func checkAllPermissions() -> Bool {
        return isMicrophoneGranted() && isAccessibilityGranted() && isHotkeyConfigured()
    }

    func isMicrophoneGranted() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    func isHotkeyConfigured() -> Bool {
        return UserDefaults.standard.data(forKey: "recordingHotkey") != nil
    }

    func isStepComplete(_ step: OnboardingStep) -> Bool {
        switch step {
        case .microphone: return isMicrophoneGranted()
        case .accessibility: return isAccessibilityGranted()
        case .language: return true // Always allow continuing from language step
        case .hotkey: return isHotkeyConfigured()
        case .prompts: return true // Always allow continuing from prompts step
        }
    }

    func findFirstIncompleteStep() -> OnboardingStep {
        for step in OnboardingStep.allCases {
            if !isStepComplete(step) {
                return step
            }
        }
        return .microphone // Default fallback
    }

    func moveToNextStep() {
        DebugLog.info("Moving to next step from \(currentStep)", context: "OnboardingManager")

        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep) else { return }

        // Move to the next step in sequence
        let nextIndex = currentIndex + 1
        if nextIndex < allSteps.count {
            currentStep = allSteps[nextIndex]
            DebugLog.info("Moving to next step: \(currentStep)", context: "OnboardingManager")
        } else {
            // All steps complete!
            completeOnboarding()
        }
    }

    func completeOnboarding() {
        // Guard against multiple calls
        guard showOnboarding else {
            DebugLog.info("Onboarding already completed, ignoring duplicate call", context: "OnboardingManager")
            return
        }

        DebugLog.info("✅ Onboarding complete!", context: "OnboardingManager")
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
        showOnboarding = false

        // Post notification to close onboarding window and show main window
        NotificationCenter.default.post(name: .onboardingComplete, object: nil)
    }

    func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                DebugLog.info("Microphone permission: \(granted)", context: "OnboardingManager")
                if granted {
                    self?.moveToNextStep()
                }
            }
        }
    }

    func requestAccessibilityPermission() {
        // Use the proper macOS API to trigger the accessibility permission dialog
        DebugLog.info("Triggering accessibility permission request", context: "OnboardingManager")

        // This will show the system dialog asking for accessibility permission
        // and automatically add the app to System Settings > Privacy & Security > Accessibility
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options)

        DebugLog.info("Permission dialog triggered", context: "OnboardingManager")
    }

    func reopenOnboarding() {
        DebugLog.info("Reopening onboarding", context: "OnboardingManager")
        currentStep = .microphone
        showOnboarding = true
    }
}
