import Foundation
internal import Combine

enum APIProvider: String, CaseIterable, Identifiable {
    case groq = "groq"
    case openai = "openai"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: return "Groq (Fast)"
        case .openai: return "OpenAI (Accurate)"
        }
    }

    var description: String {
        switch self {
        case .groq: return "Faster transcription with whisper-large-v3"
        case .openai: return "Official OpenAI Whisper API with prompt support"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .groq: return true
        case .openai: return true
        }
    }

    var apiKeyName: String {
        switch self {
        case .groq: return "groq_api_key"
        case .openai: return "openai_api_key"
        }
    }
}

class APIProviderManager: ObservableObject {
    @Published var selectedProvider: APIProvider = .groq

    private let userDefaultsKey = "selected_api_provider"

    init() {
        loadProvider()
    }

    func loadProvider() {
        if let savedProvider = UserDefaults.standard.string(forKey: userDefaultsKey),
           let provider = APIProvider(rawValue: savedProvider) {
            selectedProvider = provider
            print("[APIProviderManager LOG] Loaded provider: \(provider.displayName)")
        } else {
            print("[APIProviderManager LOG] No saved provider, using default: Groq")
        }
    }

    func setProvider(_ provider: APIProvider) {
        selectedProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: userDefaultsKey)
        print("[APIProviderManager LOG] Set provider: \(provider.displayName)")
    }
}
