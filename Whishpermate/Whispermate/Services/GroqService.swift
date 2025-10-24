import Foundation

class GroqService {
    private let transcriptionApiKey: String
    private let transcriptionEndpoint: String
    private let transcriptionModel: String
    private let llmApiKey: String?
    private let llmEndpoint: String
    private let llmModel: String

    init(
        transcriptionApiKey: String,
        transcriptionEndpoint: String,
        transcriptionModel: String,
        llmApiKey: String?,
        llmEndpoint: String,
        llmModel: String
    ) {
        self.transcriptionApiKey = transcriptionApiKey
        self.transcriptionEndpoint = transcriptionEndpoint
        self.transcriptionModel = transcriptionModel
        self.llmApiKey = llmApiKey
        self.llmEndpoint = llmEndpoint
        self.llmModel = llmModel
    }

    // MARK: - Transcription

    func transcribe(audioURL: URL, language: String?, prompt: String?) async throws -> String {
        print("[GroqService] 🎙️ Starting transcription...")
        print("[GroqService] Audio file: \(audioURL.path)")
        print("[GroqService] Language: \(language ?? "auto")")
        print("[GroqService] Endpoint: \(transcriptionEndpoint)")
        print("[GroqService] Model: \(transcriptionModel)")

        var request = URLRequest(url: URL(string: transcriptionEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(transcriptionApiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(transcriptionModel)\r\n".data(using: .utf8)!)

        // Add language if specified
        if let language = language, language != "auto" {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }

        // Add prompt if specified (for context/formatting)
        if let prompt = prompt, !prompt.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(prompt)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        print("[GroqService] 📤 Sending transcription request (\(audioData.count) bytes)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse
        }

        print("[GroqService] 📥 Response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[GroqService] ❌ Error response: \(errorMessage)")
            throw GroqError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = json?["text"] as? String else {
            throw GroqError.invalidResponse
        }

        print("[GroqService] ✅ Transcription completed: \(text.prefix(100))...")
        return text
    }

    // MARK: - LLM Post-Processing

    func fixText(_ text: String, rules: [String]) async throws -> String {
        // Check if LLM API key is available
        guard let apiKey = llmApiKey else {
            print("[GroqService] ⚠️ No LLM API key - skipping text correction")
            return text
        }

        print("[GroqService] 🤖 Starting LLM post-processing...")
        print("[GroqService] Original text: \(text.prefix(100))...")
        print("[GroqService] Rules count: \(rules.count)")
        print("[GroqService] LLM Endpoint: \(llmEndpoint)")
        print("[GroqService] LLM Model: \(llmModel)")

        // Build system prompt
        var systemPrompt = """
        You are a text correction assistant. Fix any transcription errors, improve punctuation, and format the text according to the rules provided.

        IMPORTANT: Only output the corrected text. Do not add any explanations, comments, or extra content.
        """

        if !rules.isEmpty {
            systemPrompt += "\n\nApply these rules:\n"
            for (index, rule) in rules.enumerated() {
                systemPrompt += "\(index + 1). \(rule)\n"
            }
        }

        let requestBody: [String: Any] = [
            "model": llmModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 1,
            "max_completion_tokens": 8192,
            "top_p": 1,
            "stop": NSNull() // null in JSON
        ]

        var request = URLRequest(url: URL(string: llmEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("[GroqService] 📤 Sending LLM request...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse
        }

        print("[GroqService] 📥 LLM response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[GroqService] ❌ LLM error response: \(errorMessage)")
            throw GroqError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GroqError.invalidResponse
        }

        print("[GroqService] ✅ LLM post-processing completed: \(content.prefix(100))...")
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Combined Workflow

    func transcribeAndFix(audioURL: URL, language: String?, prompt: String?, rules: [String]) async throws -> String {
        // Step 1: Transcribe
        let rawTranscription = try await transcribe(audioURL: audioURL, language: language, prompt: prompt)

        // Step 2: Fix with LLM (if rules are provided)
        if !rules.isEmpty {
            return try await fixText(rawTranscription, rules: rules)
        } else {
            return rawTranscription
        }
    }
}

enum GroqError: Error, LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Groq API"
        case .apiError(let statusCode, let message):
            return "Groq API error (\(statusCode)): \(message)"
        }
    }
}
