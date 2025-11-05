import Foundation

public enum SecretsLoader {
    private static let secretsDictionary: NSDictionary? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dictionary = NSDictionary(contentsOf: url) else {
            return nil
        }
        return dictionary
    }()

    public static func transcriptionKey(for provider: TranscriptionProvider) -> String? {
        switch provider {
        case .groq:
            return secretsDictionary?["GroqTranscriptionKey"] as? String
        case .custom:
            return secretsDictionary?["CustomTranscriptionKey"] as? String
        case .openai:
            return nil
        }
    }

    public static func customTranscriptionEndpoint() -> String? {
        return secretsDictionary?["CustomTranscriptionEndpoint"] as? String
    }

    public static func customTranscriptionModel() -> String? {
        return secretsDictionary?["CustomTranscriptionModel"] as? String
    }

    public static func llmKey(for provider: LLMProvider) -> String? {
        switch provider {
        case .groq:
            return secretsDictionary?["GroqLLMKey"] as? String
        case .openai, .anthropic, .custom:
            return nil
        }
    }
}