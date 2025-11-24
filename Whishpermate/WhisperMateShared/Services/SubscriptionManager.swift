//
//  SubscriptionManager.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var showUpgradeModal: Bool = false

    private let authManager = AuthManager.shared

    private init() {}

    // MARK: - Subscription

    func openUpgrade() {
        guard let stripePaymentLink = SecretsLoader.shared.getValue(for: "STRIPE_PAYMENT_LINK") else {
            print("Missing Stripe payment link configuration")
            return
        }

        // Add user email to pre-fill Stripe checkout if available
        var urlString = stripePaymentLink
        if let user = authManager.currentUser {
            // URL encode the email
            if let encodedEmail = user.email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?prefilled_email=\(encodedEmail)"
            }
        }

        #if canImport(AppKit)
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    func handlePaymentSuccess() async {
        // Refresh user data to get updated subscription tier
        await authManager.refreshUser()

        // Hide upgrade modal if shown
        await MainActor.run {
            self.showUpgradeModal = false
        }
    }

    func handlePaymentCancel() {
        // User cancelled payment, just close modal
        showUpgradeModal = false
    }

    // MARK: - Usage Helpers

    func getUsageStatus() -> (used: Int, limit: Int, percentage: Double, isPro: Bool) {
        guard let user = authManager.currentUser else {
            return (0, 2000, 0.0, false)
        }

        let isPro = user.subscriptionTier == .pro
        let limit = user.subscriptionTier.wordLimit
        let used = user.totalWordsUsed
        let percentage = isPro ? 0.0 : user.usagePercentage

        return (used, limit, percentage, isPro)
    }

    func shouldShowUpgradePrompt(for wordCount: Int) -> Bool {
        guard let user = authManager.currentUser else {
            return false
        }

        // Don't show for pro users
        if user.subscriptionTier == .pro {
            return false
        }

        // Show if they're approaching limit (90%) or over
        let newTotal = user.totalWordsUsed + wordCount
        let limit = user.subscriptionTier.wordLimit
        let percentage = Double(newTotal) / Double(limit)

        return percentage >= 0.9
    }

    func getUpgradeMessage(for user: User) -> String {
        let remaining = user.wordsRemaining
        if remaining <= 0 {
            return "You've used all 2,000 free words. Upgrade to Pro for unlimited transcriptions!"
        } else if remaining < 200 {
            return "Only \(remaining) words left in your free trial. Upgrade now for unlimited access!"
        } else {
            return "Upgrade to Pro for unlimited transcriptions and included API access."
        }
    }
}
