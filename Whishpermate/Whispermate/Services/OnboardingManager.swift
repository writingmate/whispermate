import Foundation
internal import Combine
import AVFoundation
import ApplicationServices
import AppKit
import CoreGraphics

enum OnboardingStep: Int, CaseIterable {
    case microphone = 0
    case accessibility = 1
    case hotkey = 2

    var title: String {
        switch self {
        case .microphone: return "Enable Microphone"
        case .accessibility: return "Enable Accessibility"
        case .hotkey: return "Set Your Hotkey"
        }
    }

    var icon: String {
        switch self {
        case .microphone: return "mic.circle.fill"
        case .accessibility: return "hand.tap.fill"
        case .hotkey: return "keyboard.fill"
        }
    }

    var explanation: String {
        switch self {
        case .microphone:
            return "Whispermate needs access to your microphone to record your voice for transcription."
        case .accessibility:
            return "Whispermate needs accessibility permissions to automatically paste transcriptions into your apps."
        case .hotkey:
            return "Choose a single key (like Fn) to control recording. Press and hold to record, or double-tap to start/stop long recording."
        }
    }
}

class OnboardingManager: ObservableObject {
    @Published var showOnboarding: Bool = false
    @Published var currentStep: OnboardingStep = .microphone
    @Published var accessibilityGranted: Bool = false

    private let onboardingCompletedKey = "has_completed_onboarding"

    init() {
        accessibilityGranted = AXIsProcessTrusted()
        checkOnboardingStatus()
    }

    func updateAccessibilityStatus() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func checkOnboardingStatus() {
        print("[OnboardingManager] Checking onboarding status")

        // Check if user has completed onboarding before
        let hasCompleted = UserDefaults.standard.bool(forKey: onboardingCompletedKey)

        if hasCompleted {
            // Even if completed, check if all permissions are still granted
            let allGranted = checkAllPermissions()
            showOnboarding = !allGranted

            if !allGranted {
                print("[OnboardingManager] Permissions revoked, showing onboarding again")
                // Find first non-granted permission
                currentStep = findFirstIncompleteStep()
            } else {
                print("[OnboardingManager] All permissions granted, skipping onboarding")
            }
        } else {
            // First time launch
            print("[OnboardingManager] First launch, showing onboarding")
            showOnboarding = true
            currentStep = findFirstIncompleteStep()
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
        case .hotkey: return isHotkeyConfigured()
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
        print("[OnboardingManager] Moving to next step from \(currentStep)")

        // Find next incomplete step
        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep) else { return }

        for index in (currentIndex + 1)..<allSteps.count {
            let nextStep = allSteps[index]
            if !isStepComplete(nextStep) {
                currentStep = nextStep
                print("[OnboardingManager] Next incomplete step: \(nextStep)")
                return
            }
        }

        // All steps complete!
        completeOnboarding()
    }

    func completeOnboarding() {
        print("[OnboardingManager] ✅ Onboarding complete!")
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
        showOnboarding = false
    }

    func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                print("[OnboardingManager] Microphone permission: \(granted)")
                if granted {
                    self?.moveToNextStep()
                }
            }
        }
    }

    func requestAccessibilityPermission() {
        // Use the proper macOS API to trigger the accessibility permission dialog
        print("[OnboardingManager] Triggering accessibility permission request")

        // This will show the system dialog asking for accessibility permission
        // and automatically add the app to System Settings > Privacy & Security > Accessibility
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options)

        print("[OnboardingManager] Permission dialog triggered")
    }
}
