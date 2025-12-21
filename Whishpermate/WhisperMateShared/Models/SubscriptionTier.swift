//
//  SubscriptionTier.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import Foundation

// MARK: - Usage Limits

public enum UsageLimits {
    public static let freeMonthlyWordLimit = 2000
}

// MARK: - Subscription Tier

public enum SubscriptionTier: String, Codable {
    case free
    case pro

    public var displayName: String {
        switch self {
        case .free:
            return "Free Trial"
        case .pro:
            return "Pro"
        }
    }

    public var wordLimit: Int {
        switch self {
        case .free:
            return UsageLimits.freeMonthlyWordLimit
        case .pro:
            return Int.max // Unlimited
        }
    }

    public var price: String {
        switch self {
        case .free:
            return "$0"
        case .pro:
            return "$9.99/month"
        }
    }

    public var features: [String] {
        switch self {
        case .free:
            return [
                "\(UsageLimits.freeMonthlyWordLimit.formatted()) words/month",
                "Full transcription features",
                "Local storage",
            ]
        case .pro:
            return [
                "Unlimited transcriptions",
                "Included API access",
                "Priority support",
                "Cloud sync (coming soon)",
            ]
        }
    }
}
