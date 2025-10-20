import Foundation

enum OpenAIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case apiError(String)
}

struct OpenAIClient {
    private static let baseURL = "https://api.openai.com/v1/audio/transcriptions"

    enum Model: String {
        case whisper1 = "whisper-1"
        case gpt4oTranscribe = "gpt-4o-transcribe"
        case gpt4oMiniTranscribe = "gpt-4o-mini-transcribe"
    }

    // Default to gpt-4o-transcribe (latest and best model)
    private static let defaultModel = Model.gpt4oTranscribe

    static func transcribe(audioURL: URL, apiKey: String, languageCode: String? = nil, prompt: String? = nil) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }

        print("[OpenAIClient LOG] ========================================")
        print("[OpenAIClient LOG] Starting transcription")
        print("[OpenAIClient LOG] Language: \(languageCode ?? "auto-detect")")
        print("[OpenAIClient LOG] Prompt: \(prompt ?? "none")")

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Read audio file data
        let audioData = try Data(contentsOf: audioURL)
        print("[OpenAIClient LOG] Audio file size: \(audioData.count) bytes")

        // Build multipart body
        var body = Data()

        // Add file parameter (required)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model parameter (required)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(defaultModel.rawValue)\r\n".data(using: .utf8)!)

        // Add language parameter (optional)
        if let languageCode = languageCode {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(languageCode)\r\n".data(using: .utf8)!)
            print("[OpenAIClient LOG] Added language: \(languageCode)")
        }

        // Add prompt parameter (optional)
        if let prompt = prompt, !prompt.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(prompt)\r\n".data(using: .utf8)!)
            print("[OpenAIClient LOG] Added prompt: \(prompt)")
        }

        // Add response_format parameter (optional, default is json)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("text\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Send request
        do {
            print("[OpenAIClient LOG] Sending request to OpenAI...")
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }

            print("[OpenAIClient LOG] Received response with status: \(httpResponse.statusCode)")

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("[OpenAIClient LOG] Error response: \(errorMessage)")
                throw OpenAIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }

            // Parse response (text format)
            guard let text = String(data: data, encoding: .utf8) else {
                throw OpenAIError.invalidResponse
            }

            print("[OpenAIClient LOG] Transcription successful")
            print("[OpenAIClient LOG] ========================================")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as OpenAIError {
            throw error
        } catch {
            print("[OpenAIClient LOG] Network error: \(error)")
            throw OpenAIError.networkError(error)
        }
    }
}
