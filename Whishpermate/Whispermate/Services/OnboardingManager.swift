import Foundation
internal import Combine
import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import WhisperMateShared

enum OnboardingStep: Int, CaseIterable {
    case microphone = 0
    case accessibility = 1
    case screenRecording = 2
    case language = 3
    case hotkey = 4

    var title: String {
        switch self {
        case .microphone: return "Enable Microphone"
        case .accessibility: return "Enable Accessibility"
        case .screenRecording: return "Enable Screen Recording"
        case .language: return "Select Your Languages"
        case .hotkey: return "Set Your Hotkey"
        }
    }

    var icon: String {
        switch self {
        case .microphone: return "mic.circle.fill"
        case .accessibility: return "hand.tap.fill"
        case .screenRecording: return "rectangle.dashed.badge.record"
        case .language: return "globe"
        case .hotkey: return "keyboard.fill"
        }
    }

    var explanation: String {
        switch self {
        case .microphone:
            return "AIDictation needs access to your microphone to record your voice for transcription."
        case .accessibility:
            return "AIDictation needs accessibility permissions to automatically paste transcriptions into your apps."
        case .screenRecording:
            return "Optional: Enable screen recording to capture context from your screen for smarter transcriptions."
        case .language:
            return "Select the languages you speak. You can choose multiple languages or use auto-detect."
        case .hotkey:
            return "Choose your preferred hotkey to control recording. Press and hold to record, or double-tap to start/stop long recording."
        }
    }

    var isOptional: Bool {
        switch self {
        case .screenRecording: return true
        default: return false
        }
    }
}

/// Manages the onboarding flow and permission states
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    // MARK: - Published Properties

    @Published var showOnboarding: Bool = false
    @Published var currentStep: OnboardingStep = .microphone
    @Published var accessibilityGranted: Bool = false
    @Published var microphoneGranted: Bool = false
    @Published var screenRecordingGranted: Bool = false

    // MARK: - Private Properties

    private enum Keys {
        static let onboardingCompleted = "has_completed_onboarding"
        static let hotkeyKeycode = "hotkey_keycode"
        static let hotkeyModifiers = "hotkey_modifiers"
    }

    // MARK: - Initialization

    private init() {
        accessibilityGranted = AXIsProcessTrusted()
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    // MARK: - Public API

    func updateAccessibilityStatus() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func updateMicrophoneStatus() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func updateScreenRecordingStatus() {
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    func checkOnboardingStatus() {
        DebugLog.info("Checking onboarding status", context: "OnboardingManager")

        // Check if user has completed onboarding before
        let hasCompleted = UserDefaults.standard.bool(forKey: Keys.onboardingCompleted)

        if !hasCompleted {
            // First time launch - ALWAYS show onboarding, regardless of permission status
            DebugLog.info("First launch detected - showing mandatory onboarding", context: "OnboardingManager")
            showOnboarding = true
            currentStep = .microphone
        } else {
            // User has completed onboarding before
            // Check if all permissions are still granted
            let allGranted = checkAllPermissions()
            showOnboarding = !allGranted

            if !allGranted {
                DebugLog.info("Permissions revoked, showing onboarding again", context: "OnboardingManager")
                // Find first non-granted permission
                currentStep = findFirstIncompleteStep()
            } else {
                DebugLog.info("All permissions granted, skipping onboarding", context: "OnboardingManager")
            }
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

    func isScreenRecordingGranted() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    func isHotkeyConfigured() -> Bool {
        // Check the same keys that HotkeyManager uses
        return UserDefaults.standard.value(forKey: Keys.hotkeyKeycode) != nil &&
            UserDefaults.standard.value(forKey: Keys.hotkeyModifiers) != nil
    }

    func isStepComplete(_ step: OnboardingStep) -> Bool {
        switch step {
        case .microphone: return isMicrophoneGranted()
        case .accessibility: return isAccessibilityGranted()
        case .screenRecording: return true // Optional step - always allow continuing
        case .language: return true // Always allow continuing from language step
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
        UserDefaults.standard.set(true, forKey: Keys.onboardingCompleted)
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
        DebugLog.info("Triggering accessibility permission request", context: "OnboardingManager")
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
        DebugLog.info("Permission dialog triggered", context: "OnboardingManager")
    }

    func requestScreenRecordingPermission() {
        DebugLog.info("Triggering screen recording permission request", context: "OnboardingManager")
        // This will trigger the system permission dialog for screen recording
        CGRequestScreenCaptureAccess()
        DebugLog.info("Screen recording permission dialog triggered", context: "OnboardingManager")
    }

    func reopenOnboarding() {
        DebugLog.info("Reopening onboarding", context: "OnboardingManager")
        currentStep = .microphone
        showOnboarding = true
    }

    func resetOnboarding() {
        DebugLog.info("Resetting onboarding status", context: "OnboardingManager")
        UserDefaults.standard.removeObject(forKey: Keys.onboardingCompleted)
        currentStep = .microphone
        showOnboarding = true
    }
}
