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

    enum RecordingMode {
        case dictation
        case command
    }

    // MARK: - Published State

    @Published var recordingState: RecordingState = .idle
    @Published var appContext: AppContext = .foreground
    @Published var transcriptionText: String = ""
    @Published var lastOutputText: String = ""  // Last text pasted to document (for command mode chaining)
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
    private var recordingMode: RecordingMode = .dictation

    // MARK: - Dependencies (singletons)

    private lazy var audioRecorder = AudioRecorder.shared
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
    /// - Parameters:
    ///   - continuous: Whether this is continuous recording mode
    ///   - isCommandMode: Whether this is command mode (set by startCommandRecording)
    func startRecording(continuous: Bool = false, isCommandMode: Bool = false) {
        DebugLog.info("🎬 AppState.startRecording(continuous: \(continuous), isCommandMode: \(isCommandMode))", context: "AppState")


        // Don't start if already recording
        guard recordingState == .idle else {
            DebugLog.info("⚠️ Already in state: \(recordingState)", context: "AppState")
            return
        }

        // Reset recording mode - command mode is only active when explicitly requested
        if !isCommandMode {
            recordingMode = .dictation
        }

        // Set state
        recordingState = .recording
        isContinuousRecording = continuous
        shouldAutoPaste = true // Always auto-paste when hotkey is triggered
        recordingStartTime = Date()

        DebugLog.info("Recording mode: \(recordingMode)", context: "AppState")

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
        ClipboardManager.storePreviousApp()

        // Start audio recording
        audioRecorder.startRecording()

        if audioRecorder.isRecording {
            DebugLog.info("✅ Recording started successfully", context: "AppState")
            if overlayManager.isOverlayMode {
                let isCommand = (recordingMode == .command)
                overlayManager.transition(to: .recording(isCommandMode: isCommand))
                DebugLog.info("Overlay transitioned to recording (command: \(isCommand))", context: "AppState")
            }
        } else {
            DebugLog.info("❌ Recording failed to start", context: "AppState")
            recordingState = .idle
            errorMessage = "Failed to start recording"
        }
    }

    /// Start recording in command mode - voice instruction to transform text
    func startCommandRecording() {
        DebugLog.info("🎬 AppState.startCommandRecording()", context: "AppState")
        DebugLog.info("🎯 Command mode activated", context: "AppState")
        recordingMode = .command
        // Capture target text (selected text or last dictation) before recording starts
        CommandModeManager.shared.prepareForCommand()
        DebugLog.info("🎯 Target text captured: '\(CommandModeManager.shared.targetText.prefix(100))...'", context: "AppState")
        startRecording(continuous: false, isCommandMode: true)
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
                recordingMode = .dictation
                _ = audioRecorder.stopRecording()

                if overlayManager.isOverlayMode {
                    overlayManager.transition(to: .hidden)
                }
                return
            }
        }

        // Stop audio recording
        guard let audioURL = audioRecorder.stopRecording() else {
            DebugLog.info("❌ Failed to get audio URL", context: "AppState")
            recordingState = .idle
            recordingMode = .dictation
            errorMessage = "Failed to save recording"
            if overlayManager.isOverlayMode {
                overlayManager.transition(to: .hidden)
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
                recordingMode = .dictation
                try? FileManager.default.removeItem(at: audioURL)
                if overlayManager.isOverlayMode {
                    overlayManager.transition(to: .hidden)
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
            let isCommand = (recordingMode == .command)
            overlayManager.transition(to: .processing(isCommandMode: isCommand))
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
                            overlayManager.transition(to: .hidden)
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
                            overlayManager.transition(to: .hidden)
                        }
                        return
                    }
                }

                // Build context components (used by all providers)
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

                // Get clipboard and screen context (only for dictation mode)
                let clipboardContent: String?
                let screenContextForTranscription: String?

                if self.recordingMode == .command {
                    clipboardContent = nil
                    screenContextForTranscription = nil
                    DebugLog.info("Command mode: transcribing voice instruction only", context: "AppState")
                } else {
                    clipboardContent = await MainActor.run {
                        NSPasteboard.general.string(forType: .string)
                    }
                    screenContextForTranscription = capturedScreenContext
                }

                // Transcribe using selected provider
                let result: String
                let provider = transcriptionProviderManager.selectedProvider
                DebugLog.info("Selected transcription provider: \(provider.displayName), isOnDevice: \(provider.isOnDevice)", context: "AppState")

                if provider == .custom {
                    // Custom (AIDictation): Server handles both transcription and formatting
                    DebugLog.info("Using Custom (AIDictation) provider - server handles formatting", context: "AppState")

                    guard let transcriptionApiKey = resolvedTranscriptionApiKey() else {
                        await MainActor.run {
                            self.recordingState = .idle
                            self.isProcessing = false
                            self.errorMessage = "Please set your transcription API key"
                        }
                        return
                    }

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

                    // Custom API handles everything server-side
                    result = try await client.transcribeAndFormat(
                        audioURL: audioURL,
                        prompt: nil,
                        formattingRules: promptComponents,
                        languageCodes: languageManager.apiLanguageCode,
                        appContext: capturedAppContext,
                        llmApiKey: nil,
                        clipboardContent: clipboardContent,
                        screenContext: screenContextForTranscription
                    )

                } else if provider.isOnDevice {
                    // Parakeet: Local transcription + optional LLM post-processing
                    DebugLog.info("Using on-device Parakeet transcription", context: "AppState")

                    let rawText = try await ParakeetTranscriptionService.shared.transcribe(audioURL: audioURL)

                    // Optional LLM post-processing
                    if transcriptionProviderManager.enableLLMPostProcessing && !promptComponents.isEmpty,
                       let llmApiKey = resolvedLLMApiKey() {
                        DebugLog.info("Applying LLM post-processing to Parakeet transcription", context: "AppState")

                        let config = OpenAIClient.Configuration(
                            transcriptionEndpoint: "",
                            transcriptionModel: "",
                            chatCompletionEndpoint: llmProviderManager.effectiveEndpoint,
                            chatCompletionModel: llmProviderManager.effectiveModel,
                            apiKey: llmApiKey
                        )

                        if openAIClient == nil {
                            openAIClient = OpenAIClient(config: config)
                        } else {
                            openAIClient?.updateConfig(config)
                        }

                        if let client = openAIClient {
                            result = try await client.applyFormattingRules(
                                transcription: rawText,
                                rules: promptComponents,
                                languageCodes: languageManager.apiLanguageCode,
                                appContext: capturedAppContext,
                                clipboardContent: clipboardContent
                            )
                        } else {
                            result = rawText
                        }
                    } else {
                        if transcriptionProviderManager.enableLLMPostProcessing && resolvedLLMApiKey() == nil {
                            DebugLog.warning("LLM post-processing enabled but no API key - using raw transcription", context: "AppState")
                        }
                        result = rawText
                    }

                } else {
                    // Groq/OpenAI: Cloud transcription + optional LLM post-processing
                    DebugLog.info("Using \(provider.displayName) cloud transcription", context: "AppState")

                    guard let transcriptionApiKey = resolvedTranscriptionApiKey() else {
                        await MainActor.run {
                            self.recordingState = .idle
                            self.isProcessing = false
                            self.errorMessage = "Please set your \(provider.displayName) API key"
                        }
                        return
                    }

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

                    // Stage 1: Pure transcription
                    let rawText = try await client.transcribe(audioURL: audioURL)

                    // Stage 2: Optional LLM post-processing
                    if transcriptionProviderManager.enableLLMPostProcessing && !promptComponents.isEmpty {
                        DebugLog.info("Applying LLM post-processing", context: "AppState")

                        let llmApiKey = resolvedLLMApiKey()
                        if llmApiKey != nil {
                            // Update client with LLM API key if different
                            let llmConfig = OpenAIClient.Configuration(
                                transcriptionEndpoint: transcriptionProviderManager.effectiveEndpoint,
                                transcriptionModel: transcriptionProviderManager.effectiveModel,
                                chatCompletionEndpoint: llmProviderManager.effectiveEndpoint,
                                chatCompletionModel: llmProviderManager.effectiveModel,
                                apiKey: llmApiKey!
                            )
                            client.updateConfig(llmConfig)

                            result = try await client.applyFormattingRules(
                                transcription: rawText,
                                rules: promptComponents,
                                languageCodes: languageManager.apiLanguageCode,
                                appContext: capturedAppContext,
                                clipboardContent: clipboardContent
                            )
                        } else {
                            DebugLog.warning("LLM post-processing enabled but no API key - using raw transcription", context: "AppState")
                            result = rawText
                        }
                    } else {
                        result = rawText
                    }
                }

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

                // Capture mode and target before resetting
                let wasCommandMode = self.recordingMode == .command
                let commandTargetText = CommandModeManager.shared.targetText

                // Update common state
                await MainActor.run {
                    self.recordingMode = .dictation // Reset recording mode
                    historyManager.addRecording(recording)
                    self.currentRecording = recording
                    self.transcriptionText = result  // Always store raw transcription
                    self.recordingState = .idle
                    self.isProcessing = false
                }

                // Notify recording completed
                NotificationCenter.default.post(name: .recordingCompleted, object: recording)

                // Dispatch to appropriate handler based on mode
                if wasCommandMode {
                    await processCommandResult(instruction: result, targetText: commandTargetText)
                } else {
                    await processDictationResult(transcription: result)
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
                        self.recordingMode = .dictation // Reset recording mode on error
                        CommandModeManager.shared.reset()
                    }

                    // Notify recording completed (even if failed)
                    NotificationCenter.default.post(name: .recordingCompleted, object: recording)
                }

                if overlayManager.isOverlayMode {
                    overlayManager.transition(to: .hidden)
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

    // MARK: - Dictation Result Processing

    /// Process dictation result: update state and paste transcribed text
    private func processDictationResult(transcription: String) async {
        DebugLog.info("Processing dictation result...", context: "AppState")

        // Update state
        await MainActor.run {
            self.transcriptionText = transcription
            self.lastOutputText = transcription
        }

        // Paste if needed
        if shouldAutoPaste {
            DebugLog.info("Auto-pasting dictation...", context: "AppState")
            await MainActor.run {
                self.recordingState = .pasting
            }
            ClipboardManager.copyAndPaste(transcription)
            await MainActor.run {
                self.recordingState = .idle
                self.overlayManager.transition(to: .hidden)
            }
        } else if overlayManager.isOverlayMode {
            // Not auto-pasting, just reset overlay state
            overlayManager.transition(to: overlayManager.hideIdleState ? .hidden : .idle)
        }
    }

    // MARK: - Command Result Processing

    /// Process command result: execute LLM instruction and paste result
    private func processCommandResult(instruction: String, targetText: String) async {
        DebugLog.info("Processing command: '\(instruction)'", context: "AppState")

        let targetSource = CommandModeManager.shared.targetSource
        let selectedTextLength = CommandModeManager.shared.selectedTextLength
        let hasTargetText = !targetText.isEmpty

        DebugLog.info("Command mode: source=\(targetSource), targetTextLength=\(targetText.count), selectedTextLength=\(selectedTextLength)", context: "AppState")

        // Build screen context: always include app info, add OCR if available
        var screenContextParts: [String] = []
        if let appContext = self.capturedAppContext {
            screenContextParts.append("App: \(appContext)")
        }
        if let ocrContext = self.capturedScreenContext {
            screenContextParts.append("Screen content:\n\(ocrContext)")
        }
        let screenContext: String? = screenContextParts.isEmpty ? nil : screenContextParts.joined(separator: "\n\n")

        // Build context rules (same as transcription)
        var contextRules: [String] = []
        if !dictionaryManager.transcriptionHints.isEmpty {
            contextRules.append("Vocabulary: \(dictionaryManager.transcriptionHints)")
        }
        if !shortcutManager.transcriptionHints.isEmpty {
            contextRules.append("Phrases: \(shortcutManager.transcriptionHints)")
        }
        if let instructions = dictionaryManager.formattingInstructions {
            contextRules.append(instructions)
        }
        if let instructions = shortcutManager.formattingInstructions {
            contextRules.append(instructions)
        }
        if let instructions = contextRulesManager.instructions(for: capturedAppBundleId, windowTitle: capturedWindowTitle) {
            contextRules.append(instructions)
        }

        // Execute the command (with or without target text)
        guard let resultText = await CommandModeManager.shared.executeInstruction(
            instruction,
            selectedText: targetText,
            screenContext: screenContext,
            contextRules: contextRules
        ) else {
            DebugLog.error("Command mode: execution failed", context: "AppState")
            await resetCommandModeState()
            return
        }

        DebugLog.info("Command mode: \(hasTargetText ? "transformation" : "generation") complete", context: "AppState")

        // Paste result
        await MainActor.run {
            self.recordingState = .pasting
        }

        // Only replace selected text if source was selectedText (not clipboard)
        if targetSource == .selectedText && selectedTextLength > 0 {
            // For selected text: move forward to end of selection, delete backwards, then paste
            DebugLog.info("Command mode: replacing \(selectedTextLength) chars of selected text", context: "AppState")
            ClipboardManager.moveForwardAndDelete(characterCount: selectedTextLength) {
                ClipboardManager.replaceSelectionAndPaste(resultText)
            }
        } else {
            // Clipboard source or no selection - just paste at cursor
            DebugLog.info("Command mode: pasting at cursor (source: \(targetSource))", context: "AppState")
            ClipboardManager.replaceSelectionAndPaste(resultText)
        }

        // Update state
        await MainActor.run {
            self.lastOutputText = resultText
            self.recordingState = .idle
        }

        // Reset command mode
        await resetCommandModeState()
    }

    /// Reset command mode state and hide overlay
    private func resetCommandModeState() async {
        await MainActor.run {
            self.overlayManager.transition(to: .hidden)
            CommandModeManager.shared.reset()
        }
    }
}
