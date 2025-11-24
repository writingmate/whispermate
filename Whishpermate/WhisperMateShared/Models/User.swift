//
//  User.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import Foundation

public struct User: Codable, Identifiable {
    public let id: UUID
    public let email: String
    public var totalWordsUsed: Int
    public var subscriptionTier: SubscriptionTier
    public let createdAt: Date
    public var updatedAt: Date

    public var wordsRemaining: Int {
        let limit = subscriptionTier.wordLimit
        if limit == Int.max {
            return Int.max // Unlimited
        }
        return max(0, limit - totalWordsUsed)
    }

    public var hasReachedLimit: Bool {
        subscriptionTier.wordLimit != Int.max && totalWordsUsed >= subscriptionTier.wordLimit
    }

    public var usagePercentage: Double {
        guard subscriptionTier.wordLimit != Int.max else {
            return 0.0
        }
        return Double(totalWordsUsed) / Double(subscriptionTier.wordLimit)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case totalWordsUsed = "total_words_used"
        case subscriptionTier = "subscription_tier"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Subscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let stripeCustomerId: String?
    let stripeSubscriptionId: String?
    let status: String
    let currentPeriodEnd: Date?
    let createdAt: Date
    var updatedAt: Date

    var isActive: Bool {
        status == "active"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case stripeCustomerId = "stripe_customer_id"
        case stripeSubscriptionId = "stripe_subscription_id"
        case status
        case currentPeriodEnd = "current_period_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
