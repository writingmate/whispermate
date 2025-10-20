import Foundation

enum GroqAPIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case apiError(String)
}

struct GroqAPIClient {
    private static let baseURL = "https://api.groq.com/openai/v1/audio/transcriptions"
    private static let model = "whisper-large-v3"

    static func transcribe(audioURL: URL, apiKey: String, languageCode: String? = nil) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw GroqAPIError.invalidURL
        }

        print("[GroqAPIClient LOG] Starting transcription with language: \(languageCode ?? "auto-detect")")

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Read audio file data
        let audioData = try Data(contentsOf: audioURL)

        // Build multipart body
        var body = Data()

        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        // Add language parameter if specified
        if let languageCode = languageCode {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(languageCode)\r\n".data(using: .utf8)!)
            print("[GroqAPIClient LOG] Language parameter added: \(languageCode)")
        }

        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Send request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GroqAPIError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GroqAPIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }

            // Parse response
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let text = json?["text"] as? String else {
                throw GroqAPIError.invalidResponse
            }

            return text
        } catch let error as GroqAPIError {
            throw error
        } catch {
            throw GroqAPIError.networkError(error)
        }
    }
}
