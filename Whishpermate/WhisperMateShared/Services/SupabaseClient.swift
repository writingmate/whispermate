//
//  SupabaseClient.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import Foundation

enum SupabaseError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Supabase URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .missingCredentials:
            return "Missing Supabase credentials"
        }
    }
}

class SupabaseClient {
    static let shared = SupabaseClient()

    private let baseURL: String
    private let anonKey: String
    private var accessToken: String?

    private init() {
        // Load from Secrets.plist or environment
        if let supabaseURL = SecretsLoader.shared.getValue(for: "SUPABASE_URL"),
           let supabaseKey = SecretsLoader.shared.getValue(for: "SUPABASE_ANON_KEY") {
            self.baseURL = supabaseURL
            self.anonKey = supabaseKey
        } else {
            // Fallback to empty strings - will fail at runtime if not configured
            self.baseURL = ""
            self.anonKey = ""
        }

        // Try to load saved token from Keychain
        self.accessToken = KeychainHelper.shared.get(key: "supabase_access_token")
    }

    // MARK: - Authentication

    func setAccessToken(_ token: String) {
        self.accessToken = token
        KeychainHelper.shared.save(key: "supabase_access_token", value: token)
    }

    func clearAccessToken() {
        self.accessToken = nil
        KeychainHelper.shared.delete(key: "supabase_access_token")
    }

    var isAuthenticated: Bool {
        return accessToken != nil
    }

    // MARK: - API Methods

    func fetchUser() async throws -> User {
        guard !baseURL.isEmpty, !anonKey.isEmpty else {
            throw SupabaseError.missingCredentials
        }
        guard let token = accessToken else {
            throw SupabaseError.unauthorized
        }

        let urlString = "\(baseURL)/rest/v1/users"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw SupabaseError.unauthorized
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SupabaseError.apiError(errorMessage)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let users = try decoder.decode([User].self, from: data)

            guard let user = users.first else {
                throw SupabaseError.invalidResponse
            }

            return user
        } catch let error as SupabaseError {
            throw error
        } catch let error as DecodingError {
            throw SupabaseError.decodingError(error)
        } catch {
            throw SupabaseError.networkError(error)
        }
    }

    func updateUserWordCount(wordsToAdd: Int) async throws -> User {
        guard !baseURL.isEmpty, !anonKey.isEmpty else {
            throw SupabaseError.missingCredentials
        }
        guard let token = accessToken else {
            throw SupabaseError.unauthorized
        }

        // First, fetch current user to get their ID
        let currentUser = try await fetchUser()

        let urlString = "\(baseURL)/rest/v1/users?id=eq.\(currentUser.id.uuidString)"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidURL
        }

        let newTotal = currentUser.totalWordsUsed + wordsToAdd

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "total_words_used": newTotal,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw SupabaseError.unauthorized
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SupabaseError.apiError(errorMessage)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let users = try decoder.decode([User].self, from: data)

            guard let user = users.first else {
                throw SupabaseError.invalidResponse
            }

            return user
        } catch let error as SupabaseError {
            throw error
        } catch let error as DecodingError {
            throw SupabaseError.decodingError(error)
        } catch {
            throw SupabaseError.networkError(error)
        }
    }

    func transcribe(audioData: Data, language: String = "en") async throws -> (transcription: String, wordCount: Int, updatedUser: User) {
        guard !baseURL.isEmpty, !anonKey.isEmpty else {
            throw SupabaseError.missingCredentials
        }
        guard let token = accessToken else {
            throw SupabaseError.unauthorized
        }

        // Call Supabase Edge Function for transcription
        let urlString = "\(baseURL)/functions/v1/transcribe"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "audio": audioData.base64EncodedString(),
            "language": language
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw SupabaseError.unauthorized
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SupabaseError.apiError(errorMessage)
            }

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

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let result = try decoder.decode(TranscribeResponse.self, from: data)

            return (result.transcription, result.wordCount, result.user)
        } catch let error as SupabaseError {
            throw error
        } catch let error as DecodingError {
            throw SupabaseError.decodingError(error)
        } catch {
            throw SupabaseError.networkError(error)
        }
    }
}
