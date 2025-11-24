//
//  AccountStatusView.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import SwiftUI
import WhisperMateShared

struct AccountStatusView: View {
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var showingUpgradeSheet = false

    var body: some View {
        VStack(spacing: 16) {
            if authManager.isAuthenticated, let user = authManager.currentUser {
                // Account info
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Account")
                                .font(.headline)
                            Text(user.email)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Subscription badge
                        Text(user.subscriptionTier.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(user.subscriptionTier == .pro ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Divider()

                    // Usage stats
                    if user.subscriptionTier == .free {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Usage")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(user.totalWordsUsed) / \(user.subscriptionTier.wordLimit) words")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            ProgressView(value: user.usagePercentage)
                                .tint(user.usagePercentage >= 0.9 ? .red : .blue)

                            if user.hasReachedLimit {
                                Text("You've reached your word limit")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else if user.usagePercentage >= 0.9 {
                                Text("You're approaching your limit")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("\(user.wordsRemaining) words remaining")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Unlimited transcriptions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Actions
                    HStack(spacing: 12) {
                        if user.subscriptionTier == .free {
                            Button(action: {
                                showingUpgradeSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "crown.fill")
                                    Text("Upgrade to Pro")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Button("Sign Out") {
                            Task {
                                await authManager.logout()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                .cornerRadius(8)

            } else {
                // Not signed in
                VStack(spacing: 12) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Not Signed In")
                        .font(.headline)

                    Text("Create an account to start transcribing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        authManager.openSignUp()
                    }) {
                        Text("Create Account")
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingUpgradeSheet) {
            UpgradeModalView()
        }
    }
}

#Preview {
    AccountStatusView()
        .frame(width: 500)
        .padding()
}
