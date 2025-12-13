import Foundation
internal import Combine

// MARK: - Transcription Provider

enum TranscriptionProvider: String, CaseIterable, Identifiable {
    case parakeet // On-device (first for prominence)
    case groq
    case openai
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .parakeet: return "Offline (Parakeet)"
        case .groq: return "Cloud (Groq)"
        case .openai: return "Cloud (OpenAI)"
        case .custom: return "Cloud (AIDictation)"
        }
    }

    var description: String {
        switch self {
        case .parakeet: return "Private, offline, fast"
        case .groq: return "Whisper Large V3"
        case .openai: return "Whisper API"
        case .custom: return "Enhanced Whisper + LLM"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .parakeet: return "" // On-device, no endpoint
        case .groq: return "https://api.groq.com/openai/v1/audio/transcriptions"
        case .openai: return "https://api.openai.com/v1/audio/transcriptions"
        case .custom: return "https://new-git-fix-workspace-image-handling-and-api-28a97e-writingmate.vercel.app/api/openai/v1/audio/transcriptions"
        }
    }

    var defaultModel: String {
        switch self {
        case .parakeet: return "parakeet-tdt-0.6b-v3" // Multilingual
        case .groq: return "whisper-large-v3-turbo"
        case .openai: return "whisper-1"
        case .custom: return "gpt-4o-transcribe"
        }
    }

    var apiKeyName: String {
        return "\(rawValue)_transcription_api_key"
    }

    var isOnDevice: Bool {
        return self == .parakeet
    }

    var requiresAPIKey: Bool {
        return self != .parakeet
    }

    /// Returns all available providers
    static var availableProviders: [TranscriptionProvider] {
        return allCases
    }
}

// MARK: - Post-Processing Provider

enum PostProcessingProvider: String, CaseIterable, Identifiable {
    case aidictation // Use AIDictation cloud (no API key needed)
    case customLLM // Use user's own LLM provider

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aidictation: return "AIDictation"
        case .customLLM: return "Custom LLM"
        }
    }

    var description: String {
        switch self {
        case .aidictation: return "Cloud formatting, no API key required"
        case .customLLM: return "Use your own LLM provider"
        }
    }

    /// Default model for AIDictation post-processing
    static let aidictationModel = "openai/gpt-oss-20b"
}

class TranscriptionProviderManager: ObservableObject {
    @Published var selectedProvider: TranscriptionProvider = .custom
    @Published var customEndpoint: String = ""
    @Published var customModel: String = ""
    @Published var enableLLMPostProcessing: Bool = false
    @Published var postProcessingProvider: PostProcessingProvider = .aidictation

    private let providerKey = "selected_transcription_provider"
    private let endpointKey = "transcription_custom_endpoint"
    private let modelKey = "transcription_custom_model"
    private let llmPostProcessingKey = "enable_llm_post_processing"
    private let postProcessingProviderKey = "post_processing_provider"

    init() {
        loadSettings()
    }

    func loadSettings() {
        if let savedProvider = UserDefaults.standard.string(forKey: providerKey),
           let provider = TranscriptionProvider(rawValue: savedProvider)
        {
            selectedProvider = provider
        } else {
            // Default to custom provider if no saved preference
            selectedProvider = .custom
        }
        customEndpoint = UserDefaults.standard.string(forKey: endpointKey) ?? ""
        customModel = UserDefaults.standard.string(forKey: modelKey) ?? ""
        // Force disable LLM post-processing for now (settings hidden)
        enableLLMPostProcessing = false
        // enableLLMPostProcessing = UserDefaults.standard.bool(forKey: llmPostProcessingKey)
        if let savedPostProcessor = UserDefaults.standard.string(forKey: postProcessingProviderKey),
           let provider = PostProcessingProvider(rawValue: savedPostProcessor)
        {
            postProcessingProvider = provider
        }
        DebugLog.info("Loaded: \(selectedProvider.displayName), LLM post-processing: \(enableLLMPostProcessing), post-processor: \(postProcessingProvider.displayName)", context: "TranscriptionProviderManager")
    }

    func setProvider(_ provider: TranscriptionProvider) {
        selectedProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
        DebugLog.info("Set provider: \(provider.displayName)", context: "TranscriptionProviderManager")
    }

    func setLLMPostProcessing(_ enabled: Bool) {
        enableLLMPostProcessing = enabled
        UserDefaults.standard.set(enabled, forKey: llmPostProcessingKey)
        DebugLog.info("LLM post-processing: \(enabled)", context: "TranscriptionProviderManager")
    }

    func setPostProcessingProvider(_ provider: PostProcessingProvider) {
        postProcessingProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: postProcessingProviderKey)
        DebugLog.info("Post-processing provider: \(provider.displayName)", context: "TranscriptionProviderManager")
    }

    func saveCustomSettings(endpoint: String, model: String) {
        customEndpoint = endpoint
        customModel = model
        UserDefaults.standard.set(endpoint, forKey: endpointKey)
        UserDefaults.standard.set(model, forKey: modelKey)
    }

    var effectiveEndpoint: String {
        // For custom provider, check Secrets.plist first
        if selectedProvider == .custom {
            if let secretEndpoint = SecretsLoader.customTranscriptionEndpoint(), !secretEndpoint.isEmpty {
                return secretEndpoint
            }
        }

        if !customEndpoint.isEmpty {
            return customEndpoint
        }
        return selectedProvider.defaultEndpoint
    }

    var effectiveModel: String {
        // For custom provider, check Secrets.plist first
        if selectedProvider == .custom {
            if let secretModel = SecretsLoader.customTranscriptionModel(), !secretModel.isEmpty {
                return secretModel
            }
        }

        if !customModel.isEmpty {
            return customModel
        }
        return selectedProvider.defaultModel
    }
}

// MARK: - LLM Provider

enum LLMProvider: String, CaseIterable, Identifiable {
    case groq
    case openai
    case anthropic
    case custom

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
        case .groq: return "openai/gpt-oss-120b"
        case .openai: return "gpt-4o"
        case .anthropic: return "claude-3-5-sonnet-20241022"
        case .custom: return ""
        }
    }

    var apiKeyName: String {
        return "\(rawValue)_llm_api_key"
    }
}

/// Manages LLM provider selection for post-processing
class LLMProviderManager: ObservableObject {
    static let shared = LLMProviderManager()

    // MARK: - Keys

    private enum Keys {
        static let provider = "selected_llm_provider"
        static let endpoint = "llm_custom_endpoint"
        static let model = "llm_custom_model"
    }

    // MARK: - Published Properties

    @Published var selectedProvider: LLMProvider = .groq
    @Published var customEndpoint: String = ""
    @Published var customModel: String = ""

    // MARK: - Initialization

    private init() {
        loadSettings()
    }

    // MARK: - Public API

    func loadSettings() {
        if let savedProvider = UserDefaults.standard.string(forKey: Keys.provider),
           let provider = LLMProvider(rawValue: savedProvider)
        {
            selectedProvider = provider
        }
        customEndpoint = UserDefaults.standard.string(forKey: Keys.endpoint) ?? ""
        customModel = UserDefaults.standard.string(forKey: Keys.model) ?? ""
        DebugLog.info("Loaded: \(selectedProvider.displayName)", context: "LLMProviderManager")
    }

    func setProvider(_ provider: LLMProvider) {
        selectedProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: Keys.provider)
        DebugLog.info("Set provider: \(provider.displayName)", context: "LLMProviderManager")
    }

    func saveCustomSettings(endpoint: String, model: String) {
        customEndpoint = endpoint
        customModel = model
        UserDefaults.standard.set(endpoint, forKey: Keys.endpoint)
        UserDefaults.standard.set(model, forKey: Keys.model)
    }

    // MARK: - Computed Properties

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
