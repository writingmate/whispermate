//
//  UpgradeModalView.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import SwiftUI
import WhisperMateShared

struct UpgradeModalView: View {
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow.gradient)
                .padding(.top, 20)

            // Title
            Text("Upgrade to Pro")
                .font(.title)
                .fontWeight(.bold)

            // Message
            if let user = authManager.currentUser {
                Text(subscriptionManager.getUpgradeMessage(for: user))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Usage stats
                VStack(spacing: 8) {
                    HStack {
                        Text("Words used:")
                        Spacer()
                        Text("\(user.totalWordsUsed) / \(user.subscriptionTier.wordLimit)")
                            .fontWeight(.semibold)
                    }

                    ProgressView(value: user.usagePercentage)
                        .tint(user.hasReachedLimit ? .red : .blue)
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            // Features list
            VStack(alignment: .leading, spacing: 12) {
                Text("Pro Features:")
                    .font(.headline)
                    .padding(.bottom, 4)

                ForEach(SubscriptionTier.pro.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(feature)
                            .font(.body)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.windowBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            // Price
            Text(SubscriptionTier.pro.price)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            // Buttons
            VStack(spacing: 12) {
                Button(action: {
                    subscriptionManager.openUpgrade()
                }) {
                    Text("Upgrade Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button("Maybe Later") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .frame(width: 480)
        .padding()
    }
}

#Preview {
    UpgradeModalView()
}
