import Foundation
internal import Combine

// MARK: - Transcription Provider

enum TranscriptionProvider: String, CaseIterable, Identifiable {
    case groq = "groq"
    case openai = "openai"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: return "Groq"
        case .openai: return "OpenAI"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .groq: return "Whisper Large V3"
        case .openai: return "Whisper API"
        case .custom: return "OpenAI-compatible API"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .groq: return "https://api.groq.com/openai/v1/audio/transcriptions"
        case .openai: return "https://api.openai.com/v1/audio/transcriptions"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .groq: return "whisper-large-v3"
        case .openai: return "whisper-1"
        case .custom: return ""
        }
    }

    var apiKeyName: String {
        return "\(rawValue)_transcription_api_key"
    }
}

class TranscriptionProviderManager: ObservableObject {
    @Published var selectedProvider: TranscriptionProvider = .groq
    @Published var customEndpoint: String = ""
    @Published var customModel: String = ""

    private let providerKey = "selected_transcription_provider"
    private let endpointKey = "transcription_custom_endpoint"
    private let modelKey = "transcription_custom_model"

    init() {
        loadSettings()
    }

    func loadSettings() {
        if let savedProvider = UserDefaults.standard.string(forKey: providerKey),
           let provider = TranscriptionProvider(rawValue: savedProvider) {
            selectedProvider = provider
        }
        customEndpoint = UserDefaults.standard.string(forKey: endpointKey) ?? ""
        customModel = UserDefaults.standard.string(forKey: modelKey) ?? ""
        print("[TranscriptionProviderManager] Loaded: \(selectedProvider.displayName)")
    }

    func setProvider(_ provider: TranscriptionProvider) {
        selectedProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
        print("[TranscriptionProviderManager] Set provider: \(provider.displayName)")
    }

    func saveCustomSettings(endpoint: String, model: String) {
        customEndpoint = endpoint
        customModel = model
        UserDefaults.standard.set(endpoint, forKey: endpointKey)
        UserDefaults.standard.set(model, forKey: modelKey)
    }

    var effectiveEndpoint: String {
        if !customEndpoint.isEmpty {
            return customEndpoint
        }
        return selectedProvider.defaultEndpoint
    }

    var effectiveModel: String {
        if !customModel.isEmpty {
            return customModel
        }
        return selectedProvider.defaultModel
    }
}

// MARK: - LLM Provider

enum LLMProvider: String, CaseIterable, Identifiable {
    case groq = "groq"
    case openai = "openai"
    case anthropic = "anthropic"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: return "Groq"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .groq: return "Fast LLM (GPT-OSS-20B)"
        case .openai: return "GPT-4o"
        case .anthropic: return "Claude"
        case .custom: return "OpenAI-compatible API"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .groq: return "https://api.groq.com/openai/v1/chat/completions"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .groq: return "openai/gpt-oss-20b"
        case .openai: return "gpt-4o"
        case .anthropic: return "claude-3-5-sonnet-20241022"
        case .custom: return ""
        }
    }

    var apiKeyName: String {
        return "\(rawValue)_llm_api_key"
    }
}

class LLMProviderManager: ObservableObject {
    @Published var selectedProvider: LLMProvider = .groq
    @Published var customEndpoint: String = ""
    @Published var customModel: String = ""

    private let providerKey = "selected_llm_provider"
    private let endpointKey = "llm_custom_endpoint"
    private let modelKey = "llm_custom_model"

    init() {
        loadSettings()
    }

    func loadSettings() {
        if let savedProvider = UserDefaults.standard.string(forKey: providerKey),
           let provider = LLMProvider(rawValue: savedProvider) {
            selectedProvider = provider
        }
        customEndpoint = UserDefaults.standard.string(forKey: endpointKey) ?? ""
        customModel = UserDefaults.standard.string(forKey: modelKey) ?? ""
        print("[LLMProviderManager] Loaded: \(selectedProvider.displayName)")
    }

    func setProvider(_ provider: LLMProvider) {
        selectedProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
        print("[LLMProviderManager] Set provider: \(provider.displayName)")
    }

    func saveCustomSettings(endpoint: String, model: String) {
        customEndpoint = endpoint
        customModel = model
        UserDefaults.standard.set(endpoint, forKey: endpointKey)
        UserDefaults.standard.set(model, forKey: modelKey)
    }

    var effectiveEndpoint: String {
        if !customEndpoint.isEmpty {
            return customEndpoint
        }
        return selectedProvider.defaultEndpoint
    }

    var effectiveModel: String {
        if !customModel.isEmpty {
            return customModel
        }
        return selectedProvider.defaultModel
    }
}

// MARK: - Legacy API Provider (for backwards compatibility during migration)

class APIProviderManager: ObservableObject {
    @Published var selectedProvider: TranscriptionProvider = .groq

    init() {
        // This is now just a wrapper for backwards compatibility
        selectedProvider = .groq
    }
}
