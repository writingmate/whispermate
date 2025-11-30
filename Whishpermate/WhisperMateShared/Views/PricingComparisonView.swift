//
//  PricingComparisonView.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import SwiftUI

public struct PricingComparisonView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedProPlan: PricingPlan
    @State private var isProcessingUpgrade = false

    private let plans = PricingPlan.allPlans()
    private let freePlan: PricingPlan
    private let proPlans: [PricingPlan]

    public init() {
        freePlan = PricingPlan.freePlan
        proPlans = PricingPlan.proPlans
        _selectedProPlan = State(initialValue: proPlans.first(where: { $0.isPopular }) ?? proPlans[0])
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Choose Your Plan")
                    .dsFont(.h3)
                    .foregroundStyle(Color.dsForeground)

                Text("Start with free credits, upgrade anytime for unlimited transcriptions")
                    .dsFont(.caption)
                    .foregroundStyle(Color.dsMutedForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            // Plans Comparison
            HStack(alignment: .top, spacing: 20) {
                // Free Plan Card
                PlanCard(
                    plan: freePlan,
                    isSelected: false,
                    action: {
                        selectFreePlan()
                    }
                )

                // Pro Plan Card
                VStack(spacing: 16) {
                    // Pro Plan Billing Options
                    HStack(spacing: 12) {
                        ForEach(proPlans) { plan in
                            BillingOptionButton(
                                plan: plan,
                                isSelected: selectedProPlan.id == plan.id,
                                action: {
                                    selectedProPlan = plan
                                }
                            )
                        }
                    }

                    // Pro Plan Card
                    PlanCard(
                        plan: selectedProPlan,
                        isSelected: true,
                        action: {
                            upgradeToPro()
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBackground)
    }

    private func selectFreePlan() {
        // Open sign up with free account
        authManager.openSignUp()
    }

    private func upgradeToPro() {
        guard let paymentLink = selectedProPlan.paymentLink,
              let url = URL(string: paymentLink)
        else {
            print("No payment link configured for \(selectedProPlan.id)")
            return
        }

        #if canImport(AppKit)
            NSWorkspace.shared.open(url)
        #endif
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: PricingPlan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plan.name)
                        .dsFont(.h5)
                        .foregroundStyle(Color.dsForeground)

                    if plan.isPopular {
                        Text("POPULAR")
                            .dsFont(.microBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.dsPrimary)
                            .cornerRadius(4)
                    }

                    Spacer()
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(plan.price)
                        .dsFont(.h2)
                        .foregroundStyle(Color.dsForeground)

                    if let billingPeriod = plan.billingPeriod {
                        Text(billingPeriod.subtitle)
                            .dsFont(.caption)
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                }

                if let savingsText = plan.billingPeriod?.savingsText {
                    Text(savingsText)
                        .dsFont(.smallMedium)
                        .foregroundStyle(Color.dsSecondary)
                }
            }

            Divider()

            // Word Limit
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(Color.dsPrimary)
                Text(plan.wordLimit)
                    .dsFont(.captionMedium)
                    .foregroundStyle(Color.dsForeground)
            }

            // Features
            VStack(alignment: .leading, spacing: 12) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.dsPrimary)
                            .dsFont(.caption)

                        Text(feature)
                            .dsFont(.label)
                            .foregroundStyle(Color.dsForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer()

            // Action Button
            Button(action: action) {
                Text(plan.id == "free" ? "Start Free" : "Upgrade to Pro")
                    .dsFont(.captionSemibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSelected ? Color.dsPrimary : Color.dsMutedForeground)
                    .cornerRadius(DSCornerRadius.small)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 280)
        .frame(minHeight: 480)
        .background(Color.dsCard)
        .cornerRadius(DSCornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .stroke(isSelected ? Color.dsPrimary : Color.dsBorder, lineWidth: isSelected ? 2 : 1)
        )
        .dsShadow(.medium)
    }
}

// MARK: - Billing Option Button

private struct BillingOptionButton: View {
    let plan: PricingPlan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let savingsText = plan.billingPeriod?.savingsText {
                    Text(savingsText)
                        .dsFont(.microBold)
                        .foregroundColor(isSelected ? .white : Color.dsPrimary)
                } else {
                    Text(" ")
                        .dsFont(.micro)
                }

                Text(plan.billingPeriod?.displayName ?? "")
                    .dsFont(.label)
                    .foregroundStyle(isSelected ? .white : Color.dsForeground)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minWidth: 85)
            .background(isSelected ? Color.dsPrimary : Color.dsCard)
            .cornerRadius(DSCornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.small)
                    .stroke(isSelected ? Color.clear : Color.dsBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct PricingComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        PricingComparisonView()
            .frame(width: 700, height: 600)
    }
}
