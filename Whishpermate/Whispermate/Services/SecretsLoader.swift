import Foundation

enum SecretsLoader {
    private static let secretsDictionary: NSDictionary? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dictionary = NSDictionary(contentsOf: url) else {
            return nil
        }
        return dictionary
    }()

    static func transcriptionKey(for provider: TranscriptionProvider) -> String? {
        switch provider {
        case .groq:
            return secretsDictionary?["GroqTranscriptionKey"] as? String
        case .openai, .custom:
            return nil
        }
    }

    static func llmKey(for provider: LLMProvider) -> String? {
        switch provider {
        case .groq:
            return secretsDictionary?["GroqLLMKey"] as? String
        case .openai, .anthropic, .custom:
            return nil
        }
    }
}
