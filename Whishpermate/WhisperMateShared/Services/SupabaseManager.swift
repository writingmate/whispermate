//
//  SupabaseManager.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import Foundation
import Supabase

public class SupabaseManager {
    public static let shared = SupabaseManager()

    public let client: SupabaseClient

    private init() {
        guard let supabaseURL = SecretsLoader.getValue(for: "SUPABASE_URL"),
              let supabaseKey = SecretsLoader.getValue(for: "SUPABASE_ANON_KEY"),
              let url = URL(string: supabaseURL)
        else {
            fatalError("Missing Supabase credentials in Secrets.plist")
        }

        // Configure client with implicit flow for web-based auth
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init(
                    flowType: .implicit,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    // MARK: - User Management

    public func fetchUser() async throws -> User {
        // Get current session
        let session = try await client.auth.session

        // Fetch user data from database
        let response: [User] = try await client
            .from("profiles")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
            .value

        guard let user = response.first else {
            throw NSError(domain: "SupabaseManager", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "User not found in database",
            ])
        }

        return user
    }

    public func updateUserWordCount(wordsToAdd: Int) async throws -> User {
        // First, fetch current user
        let currentUser = try await fetchUser()
        let newTotal = currentUser.monthlyWordCount + wordsToAdd

        // Create update payload
        struct UserUpdate: Encodable {
            let monthly_word_count: Int
            let updated_at: String
        }

        let updatePayload = UserUpdate(
            monthly_word_count: newTotal,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        // Update in database
        let response: [User] = try await client
            .from("profiles")
            .update(updatePayload)
            .eq("user_id", value: currentUser.userId.uuidString)
            .select()
            .execute()
            .value

        guard let updatedUser = response.first else {
            throw NSError(domain: "SupabaseManager", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to update user word count",
            ])
        }

        return updatedUser
    }

    /// Reset monthly word count and set new reset date (for monthly limit reset)
    public func resetMonthlyWordCount() async throws -> User {
        let currentUser = try await fetchUser()

        // Calculate next month start
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        let startOfMonth = calendar.date(from: components)!
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!

        struct ResetPayload: Encodable {
            let monthly_word_count: Int
            let word_count_reset_at: String
            let updated_at: String
        }

        let formatter = ISO8601DateFormatter()
        let resetPayload = ResetPayload(
            monthly_word_count: 0,
            word_count_reset_at: formatter.string(from: nextMonthStart),
            updated_at: formatter.string(from: Date())
        )

        let response: [User] = try await client
            .from("profiles")
            .update(resetPayload)
            .eq("user_id", value: currentUser.userId.uuidString)
            .select()
            .execute()
            .value

        guard let updatedUser = response.first else {
            throw NSError(domain: "SupabaseManager", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to reset word count",
            ])
        }

        DebugLog.info("Monthly word count reset for user \(updatedUser.email)", context: "SupabaseManager")
        return updatedUser
    }

    // MARK: - Transcription

    public func transcribe(audioData: Data, language: String = "en") async throws -> (transcription: String, wordCount: Int, updatedUser: User) {
        // Create request payload
        struct TranscribeRequest: Encodable {
            let audio: String
            let language: String
        }

        let requestBody = TranscribeRequest(
            audio: audioData.base64EncodedString(),
            language: language
        )

        let response: TranscribeResponse = try await client.functions
            .invoke("transcribe", options: FunctionInvokeOptions(
                body: requestBody
            ))

        return (response.transcription, response.wordCount, response.user)
    }
}

// MARK: - Response Models

struct TranscribeResponse: Codable {
    let transcription: String
    let wordCount: Int
    let user: User

    enum CodingKeys: String, CodingKey {
        case transcription
        case wordCount = "word_count"
        case user
    }
}
