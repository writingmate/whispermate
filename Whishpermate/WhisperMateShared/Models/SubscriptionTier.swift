//
//  SubscriptionTier.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import Foundation

enum SubscriptionTier: String, Codable {
    case free
    case pro

    var displayName: String {
        switch self {
        case .free:
            return "Free Trial"
        case .pro:
            return "Pro"
        }
    }

    var wordLimit: Int {
        switch self {
        case .free:
            return 2000 // One-time lifetime limit
        case .pro:
            return Int.max // Unlimited
        }
    }

    var price: String {
        switch self {
        case .free:
            return "$0"
        case .pro:
            return "$9.99/month"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "2,000 words total",
                "Full transcription features",
                "Local storage"
            ]
        case .pro:
            return [
                "Unlimited transcriptions",
                "Included API access",
                "Priority support",
                "Cloud sync (coming soon)"
            ]
        }
    }
}
