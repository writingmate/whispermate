//
//  AuthManager.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let supabaseClient = SupabaseClient.shared

    private init() {
        // Check if already authenticated
        if supabaseClient.isAuthenticated {
            Task {
                await refreshUser()
            }
        }
    }

    // MARK: - Authentication

    func openSignUp() {
        guard let supabaseURL = SecretsLoader.shared.getValue(for: "SUPABASE_URL") else {
            self.error = "Missing Supabase configuration"
            return
        }

        // Open Supabase hosted auth UI for signup
        let authURL = "\(supabaseURL)/auth/v1/authorize?provider=email&redirect_to=whispermate://auth"

        #if canImport(AppKit)
        if let url = URL(string: authURL) {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    func openLogin() {
        guard let supabaseURL = SecretsLoader.shared.getValue(for: "SUPABASE_URL") else {
            self.error = "Missing Supabase configuration"
            return
        }

        // Open Supabase hosted auth UI for login
        let authURL = "\(supabaseURL)/auth/v1/authorize?provider=email&redirect_to=whispermate://auth"

        #if canImport(AppKit)
        if let url = URL(string: authURL) {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    func handleAuthCallback(url: URL) async {
        // Parse the access token from the callback URL
        // Expected format: whispermate://auth?access_token=xxx&refresh_token=yyy
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            await MainActor.run {
                self.error = "Invalid authentication callback"
            }
            return
        }

        guard let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value else {
            await MainActor.run {
                self.error = "No access token in callback"
            }
            return
        }

        // Save the token
        supabaseClient.setAccessToken(accessToken)

        // Fetch user data
        await refreshUser()
    }

    func refreshUser() async {
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }

        do {
            let user = try await supabaseClient.fetchUser()
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isAuthenticated = false
                self.isLoading = false
            }
        }
    }

    func logout() {
        supabaseClient.clearAccessToken()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Usage Tracking

    func updateWordCount(wordsToAdd: Int) async throws -> User {
        let updatedUser = try await supabaseClient.updateUserWordCount(wordsToAdd: wordsToAdd)
        await MainActor.run {
            self.currentUser = updatedUser
        }
        return updatedUser
    }

    func checkCanTranscribe() -> (canTranscribe: Bool, reason: String?) {
        guard isAuthenticated, let user = currentUser else {
            return (false, "Please create an account to start transcribing")
        }

        if user.hasReachedLimit {
            return (false, "You've reached your word limit. Upgrade to Pro for unlimited transcriptions.")
        }

        return (true, nil)
    }
}
