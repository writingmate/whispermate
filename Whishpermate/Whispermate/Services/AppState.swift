import Foundation
import SwiftUI
internal import Combine
import AVFoundation
import WhisperMateShared

/// Central application state - single source of truth for app state
/// Recording works completely independently of view lifecycle
class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - State Enums

    enum RecordingState {
        case idle
        case recording
        case transcribing
        case pasting
    }

    enum AppContext {
        case foreground
        case background
    }

    // MARK: - Published State

    @Published var recordingState: RecordingState = .idle
    @Published var appContext: AppContext = .foreground
    @Published var transcriptionText: String = ""
    @Published var errorMessage: String = ""
    @Published var currentRecording: Recording?
    @Published var isProcessing: Bool = false

    // MARK: - Private State

    private var shouldAutoPaste = false
    private var isContinuousRecording = false
    private var recordingStartTime: Date?
    private var capturedAppContext: String?
    private var capturedAppBundleId: String?
    private var capturedWindowTitle: String?
    private var capturedScreenContext: String?

    // MARK: - Dependencies (singletons)

    private let audioRecorder = AudioRecorder.shared
    private let historyManager = HistoryManager.shared
    private let overlayManager = OverlayWindowManager.shared
    private let vadSettingsManager = VADSettingsManager.shared
    private let onboardingManager = OnboardingManager.shared
    private let transcriptionProviderManager = TranscriptionProviderManager()
    private let llmProviderManager = LLMProviderManager()
    private let dictionaryManager = DictionaryManager.shared
    private let contextRulesManager = ContextRulesManager.shared
    private let shortcutManager = ShortcutManager.shared
    private let languageManager = LanguageManager()
    private let screenCaptureManager = ScreenCaptureManager.shared

    private var openAIClient: OpenAIClient?

    private init() {
        // Set up app state observers
        setupAppStateObservers()
    }

    // MARK: - Public API

    /// Start recording audio
    func startRecording(continuous: Bool = false) {
        DebugLog.info("🎬 AppState.startRecording(continuous: \(continuous))", context: "AppState")

        // Ignore if onboarding is active
        guard !onboardingManager.showOnboarding else {
            DebugLog.info("⚠️ Ignoring - onboarding in progress", context: "AppState")
            return
        }

        // Don't start if already recording
        guard recordingState == .idle else {
            DebugLog.info("⚠️ Already in state: \(recordingState)", context: "AppState")
            return
        }

        // Set state
        recordingState = .recording
        isContinuousRecording = continuous
        shouldAutoPaste = true // Always auto-paste when hotkey is triggered
        recordingStartTime = Date()

        // Clear previous state
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = ""
            self?.transcriptionText = ""
        }

        // Notify that recording started
        NotificationCenter.default.post(name: .recordingStarted, object: nil)

        // Capture app context for tone/style customization
        if let context = AppContextHelper.getCurrentAppContext() {
            capturedAppContext = context.description
            capturedAppBundleId = context.bundleId
            capturedWindowTitle = context.windowTitle
            DebugLog.info("Captured app context: \(context.description)", context: "AppState")
        }

        // Capture screen context if enabled
        capturedScreenContext = nil
        if screenCaptureManager.includeScreenContext {
            Task {
                if let screenContext = await screenCaptureManager.captureAndExtractText() {
                    await MainActor.run {
                        self.capturedScreenContext = screenContext
                        DebugLog.info("Captured screen context", context: "AppState")
                    }
                }
            }
        }

        // Store previous app for pasting
        PasteHelper.storePreviousApp()

        // Start audio recording
        audioRecorder.startRecording()

        if audioRecorder.isRecording {
            DebugLog.info("✅ Recording started successfully", context: "AppState")
            if overlayManager.isOverlayMode {
                overlayManager.updateState(isRecording: true, isProcessing: false)
            }
        } else {
            DebugLog.info("❌ Recording failed to start", context: "AppState")
            recordingState = .idle
            errorMessage = "Failed to start recording"
        }
    }

    /// Stop recording and begin transcription
    func stopRecording() {
        DebugLog.info("🛑 AppState.stopRecording()", context: "AppState")

        guard recordingState == .recording else {
            DebugLog.info("⚠️ Not recording, current state: \(recordingState)", context: "AppState")
            return
        }

        // Check recording duration
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)

            if duration < 0.3 {
                DebugLog.info("Recording too short (\(duration)s), skipping", context: "AppState")
                recordingState = .idle
                shouldAutoPaste = false
                recordingStartTime = nil
                _ = audioRecorder.stopRecording()

                if overlayManager.isOverlayMode {
                    overlayManager.updateState(isRecording: false, isProcessing: false)
                }
                return
            }
        }

        // Stop audio recording
        guard let audioURL = audioRecorder.stopRecording() else {
            DebugLog.info("❌ Failed to get audio URL", context: "AppState")
            recordingState = .idle
            errorMessage = "Failed to save recording"
            if overlayManager.isOverlayMode {
                overlayManager.updateState(isRecording: false, isProcessing: false)
            }
            return
        }

        // Check file size
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0

            if fileSize < 1000 {
                DebugLog.info("Audio file too small (\(fileSize) bytes)", context: "AppState")
                recordingState = .idle
                shouldAutoPaste = false
                try? FileManager.default.removeItem(at: audioURL)
                if overlayManager.isOverlayMode {
                    overlayManager.updateState(isRecording: false, isProcessing: false)
                }
                return
            }
        } catch {
            DebugLog.info("Error checking file: \(error)", context: "AppState")
        }

        // Begin transcription
        transcribe(audioURL: audioURL)
    }

    /// Toggle continuous recording mode
    func toggleContinuousRecording() {
        DebugLog.info("🔄 AppState.toggleContinuousRecording()", context: "AppState")

        guard !onboardingManager.showOnboarding else { return }

        if isContinuousRecording, recordingState == .recording {
            // Stop continuous recording
            isContinuousRecording = false
            shouldAutoPaste = false
            stopRecording()
        } else if recordingState == .idle {
            // Start continuous recording
            startRecording(continuous: true)
        }
    }

    // MARK: - Private Methods

    private func setupAppStateObservers() {
        // Listen for app going to background/foreground
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.appContext = .background
            DebugLog.info("App went to background", context: "AppState")
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.appContext = .foreground
            DebugLog.info("App came to foreground", context: "AppState")
        }
    }

    private func transcribe(audioURL: URL) {
        DebugLog.info("📝 AppState.transcribe()", context: "AppState")

        recordingState = .transcribing
        isProcessing = true

        if overlayManager.isOverlayMode {
            overlayManager.updateState(isRecording: false, isProcessing: true)
        }

        Task {
            do {
                // Check word limit for authenticated users
                if AuthManager.shared.isAuthenticated {
                    let (canTranscribe, reason) = AuthManager.shared.checkCanTranscribe()
                    if !canTranscribe {
                        DebugLog.info("⚠️ Word limit reached", context: "AppState")
                        await MainActor.run {
                            self.recordingState = .idle
                            self.isProcessing = false
                            self.errorMessage = reason ?? "Word limit reached"
                        }
                        try? FileManager.default.removeItem(at: audioURL)
                        if overlayManager.isOverlayMode {
                            overlayManager.updateState(isRecording: false, isProcessing: false)
                        }

                        // Show upgrade modal
                        await MainActor.run {
                            SubscriptionManager.shared.showUpgradeModal = true
                        }
                        return
                    }
                }

                // VAD check first
                if vadSettingsManager.vadEnabled {
                    DebugLog.info("🎤 VAD check...", context: "AppState")

                    let hasSpeech = try await VoiceActivityDetector.hasSpeech(
                        in: audioURL,
                        settings: vadSettingsManager
                    )

                    if !hasSpeech {
                        DebugLog.info("🔇 No speech detected", context: "AppState")
                        await MainActor.run {
                            self.recordingState = .idle
                            self.isProcessing = false
                            self.shouldAutoPaste = false
                        }
                        try? FileManager.default.removeItem(at: audioURL)
                        if overlayManager.isOverlayMode {
                            overlayManager.updateState(isRecording: false, isProcessing: false)
                        }
                        return
                    }
                }

                // Get API key
                guard let transcriptionApiKey = resolvedTranscriptionApiKey() else {
                    await MainActor.run {
                        self.recordingState = .idle
                        self.isProcessing = false
                        self.errorMessage = "Please set your transcription API key"
                    }
                    return
                }

                // Build formatting rules
                var promptComponents: [String] = []

                if !dictionaryManager.transcriptionHints.isEmpty {
                    promptComponents.append("Vocabulary: \(dictionaryManager.transcriptionHints)")
                }
                if !shortcutManager.transcriptionHints.isEmpty {
                    promptComponents.append("Phrases: \(shortcutManager.transcriptionHints)")
                }
                if let instructions = dictionaryManager.formattingInstructions {
                    promptComponents.append(instructions)
                }
                if let instructions = shortcutManager.formattingInstructions {
                    promptComponents.append(instructions)
                }
                if let instructions = contextRulesManager.instructions(for: capturedAppBundleId, windowTitle: capturedWindowTitle) {
                    promptComponents.append(instructions)
                }

                let llmApiKey = !promptComponents.isEmpty ? resolvedLLMApiKey() : nil

                // Create/update OpenAI client
                let config = OpenAIClient.Configuration(
                    transcriptionEndpoint: transcriptionProviderManager.effectiveEndpoint,
                    transcriptionModel: transcriptionProviderManager.effectiveModel,
                    chatCompletionEndpoint: llmProviderManager.effectiveEndpoint,
                    chatCompletionModel: llmProviderManager.effectiveModel,
                    apiKey: transcriptionApiKey
                )

                if openAIClient == nil {
                    openAIClient = OpenAIClient(config: config)
                } else {
                    openAIClient?.updateConfig(config)
                }

                guard let client = openAIClient else {
                    throw NSError(domain: "AppState", code: -1)
                }

                // Read clipboard content if available
                let clipboardContent = await MainActor.run {
                    NSPasteboard.general.string(forType: .string)
                }

                if let clipboardContent = clipboardContent, !clipboardContent.isEmpty {
                    DebugLog.info("Clipboard content detected: \(clipboardContent.prefix(50))...", context: "AppState")
                }

                // Transcribe
                let result = try await client.transcribeAndFormat(
                    audioURL: audioURL,
                    prompt: nil,
                    formattingRules: promptComponents,
                    languageCodes: languageManager.apiLanguageCode,
                    appContext: capturedAppContext,
                    llmApiKey: llmApiKey,
                    clipboardContent: clipboardContent,
                    screenContext: capturedScreenContext
                )

                // Success - save to history
                let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

                // Move audio file to persistent storage
                guard let persistentURL = historyManager.copyAudioToPersistentStorage(from: audioURL) else {
                    DebugLog.error("Failed to save audio file", context: "AppState")
                    return
                }

                // Count words in transcription
                let wordCount = result.split(separator: " ").count

                // Update user's word count if authenticated
                if AuthManager.shared.isAuthenticated {
                    do {
                        _ = try await AuthManager.shared.updateWordCount(wordsToAdd: wordCount)
                        print("✅ Updated word count: +\(wordCount) words")
                    } catch {
                        print("❌ Failed to update word count: \(error.localizedDescription)")
                        // Don't fail transcription if word count update fails
                    }
                }

                var recording = Recording(
                    audioFileURL: persistentURL,
                    transcription: result,
                    status: .success,
                    duration: duration
                )
                recording.wordCount = wordCount

                await MainActor.run {
                    historyManager.addRecording(recording)
                    self.currentRecording = recording
                    self.transcriptionText = result
                    self.recordingState = .idle
                    self.isProcessing = false
                }

                // Notify recording completed
                NotificationCenter.default.post(name: .recordingCompleted, object: recording)

                // Auto-paste if needed
                if shouldAutoPaste && !onboardingManager.showOnboarding {
                    DebugLog.info("Auto-pasting...", context: "AppState")
                    await MainActor.run {
                        self.recordingState = .pasting
                    }
                    PasteHelper.copyAndPaste(result)
                    await MainActor.run {
                        self.recordingState = .idle
                    }
                }

                if overlayManager.isOverlayMode {
                    overlayManager.updateState(isRecording: false, isProcessing: false)
                }

            } catch {
                DebugLog.info("❌ Transcription error: \(error)", context: "AppState")

                // Save failed recording
                let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

                if let persistentURL = historyManager.copyAudioToPersistentStorage(from: audioURL) {
                    let recording = Recording(
                        audioFileURL: persistentURL,
                        transcription: nil,
                        status: .failed,
                        errorMessage: error.localizedDescription,
                        duration: duration
                    )

                    await MainActor.run {
                        historyManager.addRecording(recording)
                        self.errorMessage = error.localizedDescription
                        self.recordingState = .idle
                        self.isProcessing = false
                    }

                    // Notify recording completed (even if failed)
                    NotificationCenter.default.post(name: .recordingCompleted, object: recording)
                }

                if overlayManager.isOverlayMode {
                    overlayManager.updateState(isRecording: false, isProcessing: false)
                }
            }

            // Reset state
            shouldAutoPaste = false
            recordingStartTime = nil
        }
    }

    private func resolvedTranscriptionApiKey() -> String? {
        let provider = transcriptionProviderManager.selectedProvider

        // Check Secrets.plist first
        if let secretKey = SecretsLoader.transcriptionKey(for: provider), !secretKey.isEmpty {
            return secretKey
        }

        // Then check keychain
        if let storedKey = KeychainHelper.get(key: provider.apiKeyName), !storedKey.isEmpty {
            return storedKey
        }

        // Fallback: try legacy "openai_api_key" for backward compatibility
        if let legacyKey = KeychainHelper.get(key: "openai_api_key"), !legacyKey.isEmpty {
            DebugLog.info("Using legacy openai_api_key", context: "AppState")
            return legacyKey
        }

        return nil
    }

    private func resolvedLLMApiKey() -> String? {
        let provider = llmProviderManager.selectedProvider

        // Check Secrets.plist first
        if let secretKey = SecretsLoader.llmKey(for: provider), !secretKey.isEmpty {
            return secretKey
        }

        // Then check keychain
        if let storedKey = KeychainHelper.get(key: provider.apiKeyName), !storedKey.isEmpty {
            return storedKey
        }

        return nil
    }
}
