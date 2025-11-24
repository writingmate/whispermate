//
//  AuthManager.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import Foundation
import Combine
import Supabase
#if canImport(AppKit)
import AppKit
#endif

public class AuthManager: ObservableObject {
    public static let shared = AuthManager()

    @Published public var currentUser: User?
    @Published public var isAuthenticated: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var error: String?

    private let supabase = SupabaseManager.shared

    private init() {
        // Check if already authenticated
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    private func checkSession() async {
        do {
            _ = try await supabase.client.auth.session
            // User is authenticated, fetch user data
            await refreshUser()
        } catch {
            // No active session
            await MainActor.run {
                self.isAuthenticated = false
            }
        }
    }

    // MARK: - Web-Based Authentication

    public func openSignUp() {
        guard let authWebURL = SecretsLoader.getValue(for: "AUTH_WEB_URL") else {
            self.error = "Missing auth web URL configuration"
            return
        }

        // Open hosted auth web page for signup/login
        // User will authenticate in browser, then redirect back to app
        let redirectURL = "whispermate://auth-callback"
        let authURL = "\(authWebURL)?redirect_to=\(redirectURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURL)"

        #if canImport(AppKit)
        if let url = URL(string: authURL) {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    public func openLogin() {
        openSignUp() // Hosted auth page handles both login and signup
    }

    public func handleAuthCallback(url: URL) async {
        print("🔐 [AuthManager] Handling auth callback: \(url.absoluteString)")

        // The Supabase SDK will handle the URL callback
        do {
            // Extract the session from the URL callback
            let session = try await supabase.client.auth.session(from: url)
            print("✅ [AuthManager] Session established for user: \(session.user.id)")

            // Session established, now fetch user data
            await refreshUser()
        } catch {
            print("❌ [AuthManager] Auth callback failed: \(error.localizedDescription)")
            await MainActor.run {
                self.error = "Authentication failed: \(error.localizedDescription)"
            }
        }
    }

    public func refreshUser() async {
        print("👤 [AuthManager] Fetching user data...")
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }

        do {
            let user = try await supabase.fetchUser()
            print("✅ [AuthManager] User fetched: \(user.email), tier: \(user.subscriptionTier), words: \(user.totalWordsUsed)")
            await MainActor.run {
                self.objectWillChange.send()
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false

                // Notify app that auth state changed
                NotificationCenter.default.post(name: NSNotification.Name("UserAuthenticationChanged"), object: nil)
            }
            print("✅ [AuthManager] Auth state updated - isAuthenticated: true")
        } catch {
            print("❌ [AuthManager] Failed to fetch user: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isAuthenticated = false
                self.isLoading = false
            }
        }
    }

    public func logout() async {
        do {
            try await supabase.client.auth.signOut()
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        } catch {
            await MainActor.run {
                self.error = "Logout failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Usage Tracking

    public func updateWordCount(wordsToAdd: Int) async throws -> User {
        let updatedUser = try await supabase.updateUserWordCount(wordsToAdd: wordsToAdd)
        await MainActor.run {
            self.currentUser = updatedUser
        }
        return updatedUser
    }

    public func checkCanTranscribe() -> (canTranscribe: Bool, reason: String?) {
        guard isAuthenticated, let user = currentUser else {
            return (false, "Please create an account to start transcribing")
        }

        if user.hasReachedLimit {
            return (false, "You've reached your word limit. Upgrade to Pro for unlimited transcriptions.")
        }

        return (true, nil)
    }
}
