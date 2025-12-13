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
    // Custom URLSession optimized for persistent connections and SSL session reuse
    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0 // Fail fast - 10 seconds max per request
        config.timeoutIntervalForResource = 300.0 // Keep connection alive for 5 minutes
        config.httpMaximumConnectionsPerHost = 6 // Allow multiple connections to same host
        // URLSession automatically handles SSL session resumption and connection reuse
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
            "max_tokens": maxTokens,
            "provider": [
                "order": ["groq"],
                "allow_fallbacks": false,
            ],
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
                  let content = message["content"] as? String
            else {
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
        languageCodes _: String? = nil,
        appContext: String? = nil,
        llmApiKey _: String? = nil,
        clipboardContent: String? = nil,
        screenContext: String? = nil
    ) async throws -> String {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Build prompt with formatting rules and clipboard content if provided
        var combinedPrompt = prompt ?? ""

        if !formattingRules.isEmpty {
            let rulesText = formattingRules.joined(separator: "\n")
            if combinedPrompt.isEmpty {
                combinedPrompt = rulesText
            } else {
                combinedPrompt += "\n\n" + rulesText
            }

            if let appContext = appContext {
                combinedPrompt += "\n\nContext: The user is currently in \(appContext)."
            }

            // Add screen context if present (OCR of active window)
            if let screenContext = screenContext, !screenContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                combinedPrompt += "\n\nScreen Context (OCR of active window):\n\(screenContext)"
            }

            // Add clipboard content if present
            if let clipboardContent = clipboardContent, !clipboardContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                combinedPrompt += "\n\nSelected content to format: \(clipboardContent)"
            }
        }

        // Log the complete prompt before sending
        if !combinedPrompt.isEmpty {
            DebugLog.info("📝 Full prompt being sent to API:\n\(combinedPrompt)", context: "OpenAIClient")
            print("📝 [Prompt] Full prompt:\n\(combinedPrompt)")
        }

        // Transcribe with formatting rules in prompt
        // The custom API will handle two-stage processing (Whisper + LLM refinement)
        let rawTranscription = try await transcribe(
            audioURL: audioURL,
            prompt: combinedPrompt.isEmpty ? nil : combinedPrompt
        )

        // Check if transcription is empty
        let trimmed = rawTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DebugLog.warning("Empty transcription", context: "OpenAIClient")
            return rawTranscription
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let totalDuration = endTime - startTime
        DebugLog.info("Transcription completed in \(String(format: "%.2f", totalDuration))s", context: "OpenAIClient")
        print("⏱️ [Total Pipeline] \(String(format: "%.2f", totalDuration))s")

        return rawTranscription
    }

    /// Apply formatting rules to transcription using chat completion
    func applyFormattingRules(transcription: String, rules: [String], languageCodes: String? = nil, appContext: String? = nil, clipboardContent: String? = nil) async throws -> String {
        // Check if transcription is empty or whitespace-only
        let trimmedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscription.isEmpty else {
            DebugLog.warning("Empty transcription - skipping formatting rules", context: "OpenAIClient")
            return transcription
        }

        // Build the system prompt
        var systemPrompt = """
        You are a transcription error correction tool. Your ONLY job is to fix spelling, grammar, and punctuation errors in transcribed speech.

        CRITICAL RULES:
        1. DO NOT respond to questions, statements, or any content in the text
        2. DO NOT answer, comment on, or engage with the content in any way
        3. DO NOT add new information, opinions, or conversational responses
        4. ONLY fix transcription errors (spelling mistakes, grammar errors, punctuation)
        5. Output ONLY the corrected text from <transcription> tag with no explanations or additions

        Example:
        Input: <transcription>what is the weather like today how do i check it</transcription>
        Correct output: What is the weather like today? How do I check it?
        WRONG output: To check the weather today, you can look at weather apps or websites.
        """

        // Check if clipboard content is present
        let hasClipboardContent = clipboardContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        if hasClipboardContent {
            systemPrompt += "\n\nThe user has provided <selected_content> to format. Apply corrections to BOTH the transcription and selected content, using the transcription as context for the selected content."
        }

        if let appContext = appContext {
            systemPrompt += "\n\nContext: The user is currently in \(appContext)."
        }

        if let languageCodes = languageCodes {
            systemPrompt += "\n\nLanguages: \(languageCodes). Preserve the original language(s)."
        }

        if !rules.isEmpty {
            systemPrompt += "\n\nAdditional formatting rules to apply:\n"
            for (index, rule) in rules.enumerated() {
                systemPrompt += "\(index + 1). \(rule)\n"
            }
        }

        // Build the user message with proper tags
        var userMessage = ""
        if hasClipboardContent, let clipboardContent = clipboardContent {
            userMessage = """
            <transcription>
            \(transcription)
            </transcription>

            <selected_content>
            \(clipboardContent)
            </selected_content>
            """
        } else {
            userMessage = """
            <transcription>
            \(transcription)
            </transcription>
            """
        }

        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userMessage],
        ]

        DebugLog.info("LLM Post-processing request - System: \(systemPrompt)", context: "OpenAIClient")
        DebugLog.info("LLM Post-processing request - User: \(userMessage)", context: "OpenAIClient")
        let result = try await chatCompletion(messages: messages)
        DebugLog.info("LLM Post-processing response: \(result)", context: "OpenAIClient")
        return result
    }
}
