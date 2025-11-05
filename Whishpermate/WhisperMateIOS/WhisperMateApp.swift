import SwiftUI
import Combine

@main
struct WhisperMateApp: App {
    @StateObject private var onboardingManager = OnboardingManager()

    var body: some Scene {
        WindowGroup {
            if onboardingManager.hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(onboardingManager: onboardingManager)
            }
        }
    }
}

// MARK: - Onboarding Manager

class OnboardingManager: ObservableObject {
    @Published var hasCompletedOnboarding: Bool

    private let onboardingKey = "has_completed_onboarding"

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: onboardingKey)
    }
}
