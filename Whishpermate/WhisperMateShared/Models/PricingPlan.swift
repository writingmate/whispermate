//
//  PricingPlan.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import Foundation

public enum BillingPeriod: String, Codable {
    case monthly
    case annual
    case lifetime

    public var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .lifetime: return "Lifetime"
        }
    }

    public var subtitle: String {
        switch self {
        case .monthly: return "per month"
        case .annual: return "per year"
        case .lifetime: return "one-time payment"
        }
    }

    public var savingsText: String? {
        switch self {
        case .monthly: return nil
        case .annual: return "Save 20%"
        case .lifetime: return "Best Value"
        }
    }
}

public struct PricingPlan: Identifiable {
    public let id: String
    public let name: String
    public let price: String
    public let billingPeriod: BillingPeriod?
    public let wordLimit: String
    public let features: [String]
    public let isPopular: Bool
    public let paymentLink: String?

    public init(
        id: String,
        name: String,
        price: String,
        billingPeriod: BillingPeriod?,
        wordLimit: String,
        features: [String],
        isPopular: Bool = false,
        paymentLink: String? = nil
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.billingPeriod = billingPeriod
        self.wordLimit = wordLimit
        self.features = features
        self.isPopular = isPopular
        self.paymentLink = paymentLink
    }

    // Static pricing plans
    public static func allPlans() -> [PricingPlan] {
        return [
            // Free Plan
            PricingPlan(
                id: "free",
                name: "Free",
                price: "$0",
                billingPeriod: nil,
                wordLimit: "2,000 words lifetime",
                features: [
                    "2,000 words total",
                    "Basic transcription",
                    "AI formatting",
                    "Export to clipboard"
                ],
                isPopular: false,
                paymentLink: nil
            ),

            // Pro Monthly
            PricingPlan(
                id: "pro-monthly",
                name: "Pro",
                price: "$9.99",
                billingPeriod: .monthly,
                wordLimit: "Unlimited words",
                features: [
                    "Unlimited transcriptions",
                    "Priority processing",
                    "Advanced AI features",
                    "Export anywhere",
                    "Premium support"
                ],
                isPopular: false,
                paymentLink: SecretsLoader.getValue(for: "STRIPE_PAYMENT_LINK_MONTHLY")
            ),

            // Pro Annual
            PricingPlan(
                id: "pro-annual",
                name: "Pro",
                price: "$95.99",
                billingPeriod: .annual,
                wordLimit: "Unlimited words",
                features: [
                    "Unlimited transcriptions",
                    "Priority processing",
                    "Advanced AI features",
                    "Export anywhere",
                    "Premium support"
                ],
                isPopular: true,
                paymentLink: SecretsLoader.getValue(for: "STRIPE_PAYMENT_LINK_ANNUAL")
            ),

            // Pro Lifetime
            PricingPlan(
                id: "pro-lifetime",
                name: "Pro",
                price: "$299",
                billingPeriod: .lifetime,
                wordLimit: "Unlimited words",
                features: [
                    "Unlimited transcriptions",
                    "Priority processing",
                    "Advanced AI features",
                    "Export anywhere",
                    "Premium support",
                    "All future updates"
                ],
                isPopular: false,
                paymentLink: SecretsLoader.getValue(for: "STRIPE_PAYMENT_LINK_LIFETIME")
            )
        ]
    }

    public static var freePlan: PricingPlan {
        allPlans().first { $0.id == "free" }!
    }

    public static var proPlans: [PricingPlan] {
        allPlans().filter { $0.id.starts(with: "pro-") }
    }
}
