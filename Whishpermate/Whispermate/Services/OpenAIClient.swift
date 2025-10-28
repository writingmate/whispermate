import Foundation

enum OpenAIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case encodingError
}

/// Unified OpenAI-compatible client that works with Groq, OpenAI, and any OpenAI-compatible API
/// Single client configured once and used everywhere
class OpenAIClient {
    // Custom URLSession with 5 second timeout - fail fast
    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0  // 5 seconds max
        config.timeoutIntervalForResource = 5.0  // 5 seconds max
        return URLSession(configuration: config)
    }()

    // MARK: - Configuration

    struct Configuration {
        var transcriptionEndpoint: String
        var transcriptionModel: String
        var chatCompletionEndpoint: String
        var chatCompletionModel: String
        var apiKey: String
        var customHeaders: [String: String]

        init(
            transcriptionEndpoint: String = "",
            transcriptionModel: String = "",
            chatCompletionEndpoint: String = "",
            chatCompletionModel: String = "",
            apiKey: String = "",
            customHeaders: [String: String] = [:]
        ) {
            self.transcriptionEndpoint = transcriptionEndpoint
            self.transcriptionModel = transcriptionModel
            self.chatCompletionEndpoint = chatCompletionEndpoint
            self.chatCompletionModel = chatCompletionModel
            self.apiKey = apiKey
            self.customHeaders = customHeaders
        }
    }

    private var config: Configuration

    init(config: Configuration) {
        self.config = config
        DebugLog.info("Initialized", context: "OpenAIClient")
        DebugLog.api("Transcription endpoint: \(config.transcriptionEndpoint)")
        DebugLog.api("Chat endpoint: \(config.chatCompletionEndpoint)")
    }

    /// Update configuration (useful for switching providers or updating settings)
    func updateConfig(_ newConfig: Configuration) {
        config = newConfig
        DebugLog.info("Configuration updated", context: "OpenAIClient")
    }

    // MARK: - Transcription

    func transcribe(
        audioURL: URL,
        prompt: String? = nil,
        model: String? = nil
    ) async throws -> String {
        let effectiveModel = model ?? config.transcriptionModel

        guard let url = URL(string: config.transcriptionEndpoint) else {
            throw OpenAIError.invalidURL
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        DebugLog.api("Starting transcription", endpoint: config.transcriptionEndpoint)
        DebugLog.info("Model: \(effectiveModel), Language: auto-detect", context: "OpenAIClient")

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Add custom headers
        for (key, value) in config.customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Read audio file data
        let audioData = try Data(contentsOf: audioURL)
        DebugLog.info("Audio file size: \(audioData.count) bytes", context: "OpenAIClient")

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
        body.append("\(effectiveModel)\r\n".data(using: .utf8)!)

        // Add temperature parameter (optional - set to 0 for deterministic results)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
        body.append("0\r\n".data(using: .utf8)!)

        // Add prompt parameter (optional)
        if let prompt = prompt, !prompt.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(prompt)\r\n".data(using: .utf8)!)
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
            let (data, response) = try await Self.urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }

            DebugLog.api("Response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                DebugLog.error("API Error: \(errorMessage)", context: "OpenAIClient")
                throw OpenAIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }

            // Parse response (text format)
            guard let text = String(data: data, encoding: .utf8) else {
                throw OpenAIError.invalidResponse
            }

            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            DebugLog.info("Transcription successful in \(String(format: "%.2f", duration))s", context: "OpenAIClient")
            print("⏱️ [Transcription] \(String(format: "%.2f", duration))s - \(effectiveModel)")

            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as OpenAIError {
            throw error
        } catch {
            DebugLog.error("Network error: \(error)", context: "OpenAIClient")
            throw OpenAIError.networkError(error)
        }
    }

    // MARK: - Chat Completion

    func chatCompletion(
        messages: [[String: String]],
        temperature: Double = 0.0,
        maxTokens: Int = 1000,
        model: String? = nil
    ) async throws -> String {
        let effectiveModel = model ?? config.chatCompletionModel

        guard let url = URL(string: config.chatCompletionEndpoint) else {
            throw OpenAIError.invalidURL
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        DebugLog.api("Chat completion request", endpoint: config.chatCompletionEndpoint)
        DebugLog.info("Model: \(effectiveModel)", context: "OpenAIClient")

        // Build the request payload
        let payload: [String: Any] = [
            "model": effectiveModel,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw OpenAIError.encodingError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add custom headers
        for (key, value) in config.customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = jsonData

        // Send request
        do {
            let (data, response) = try await Self.urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }

            DebugLog.api("Response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                DebugLog.error("API Error: \(errorMessage)", context: "OpenAIClient")
                throw OpenAIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }

            // Parse response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw OpenAIError.invalidResponse
            }

            let result = content.trimmingCharacters(in: .whitespacesAndNewlines)

            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            DebugLog.info("Chat completion successful in \(String(format: "%.2f", duration))s", context: "OpenAIClient")
            print("⏱️ [Chat Completion] \(String(format: "%.2f", duration))s - \(effectiveModel)")

            return result
        } catch let error as OpenAIError {
            throw error
        } catch {
            DebugLog.error("Network error: \(error)", context: "OpenAIClient")
            throw OpenAIError.networkError(error)
        }
    }

    // MARK: - Combined Workflow

    /// Transcribe audio and optionally apply formatting rules
    func transcribeAndFormat(
        audioURL: URL,
        prompt: String? = nil,
        formattingRules: [String] = [],
        languageCodes: String? = nil,
        appContext: String? = nil,
        llmApiKey: String? = nil
    ) async throws -> String {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Step 1: Transcribe
        let rawTranscription = try await transcribe(
            audioURL: audioURL,
            prompt: prompt
        )

        // Check if transcription is empty
        let trimmed = rawTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DebugLog.warning("Empty transcription - skipping formatting", context: "OpenAIClient")
            return rawTranscription
        }

        // Step 2: Apply formatting rules (if any)
        guard !formattingRules.isEmpty else {
            return rawTranscription
        }

        // Switch to LLM API key if provided
        if let llmKey = llmApiKey {
            var newConfig = config
            newConfig.apiKey = llmKey
            updateConfig(newConfig)
        }

        let result = try await applyFormattingRules(transcription: rawTranscription, rules: formattingRules, languageCodes: languageCodes, appContext: appContext)

        let endTime = CFAbsoluteTimeGetCurrent()
        let totalDuration = endTime - startTime
        DebugLog.info("Transcribe & format completed in \(String(format: "%.2f", totalDuration))s", context: "OpenAIClient")
        print("⏱️ [Total Pipeline] \(String(format: "%.2f", totalDuration))s")

        return result
    }

    /// Apply formatting rules to transcription using chat completion
    func applyFormattingRules(transcription: String, rules: [String], languageCodes: String? = nil, appContext: String? = nil) async throws -> String {
        // Check if transcription is empty or whitespace-only
        let trimmedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscription.isEmpty else {
            DebugLog.warning("Empty transcription - skipping formatting rules", context: "OpenAIClient")
            return transcription
        }

        // Build the system prompt
        var systemPrompt = """
        You are a text correction assistant. Fix any transcription errors, improve punctuation, and format the text according to the rules provided.

        IMPORTANT: Only output the corrected text. Do not add any explanations, comments, or extra content.
        """

        if let appContext = appContext {
            systemPrompt += "\n\nContext: The user is currently in \(appContext). Consider this context when formatting the text."
        }

        if let languageCodes = languageCodes {
            systemPrompt += "\n\nThe text may contain content in the following languages: \(languageCodes). Preserve the original language(s) when correcting."
        }

        if !rules.isEmpty {
            systemPrompt += "\n\nApply these rules:\n"
            for (index, rule) in rules.enumerated() {
                systemPrompt += "\(index + 1). \(rule)\n"
            }
        }

        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": transcription]
        ]

        return try await chatCompletion(messages: messages)
    }
}
