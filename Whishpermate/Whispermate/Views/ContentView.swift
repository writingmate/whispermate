import SwiftUI
import AVFoundation
import AppKit

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var historyManager = HistoryManager()
    @ObservedObject private var overlayManager = OverlayWindowManager.shared
    @ObservedObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var transcriptionProviderManager = TranscriptionProviderManager()
    @StateObject private var llmProviderManager = LLMProviderManager()
    @ObservedObject private var promptRulesManager = PromptRulesManager.shared
    @StateObject private var vadSettingsManager = VADSettingsManager()
    @State private var transcription = ""
    @State private var isProcessing = false
    @State private var showingAPIKeyAlert = false
    @State private var apiKey = ""
    @Environment(\.openWindow) private var openWindow
    @State private var errorMessage = ""
    @State private var recordingStartTime: Date?
    @State private var shouldAutoPaste = false
    @State private var isContinuousRecording = false
    @State private var capturedAppContext: String?
    @State private var showCopiedNotification = false
    @State private var isHoveringWindow = false
    @State private var hasCheckedOnboarding = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content VStack
            VStack(spacing: 0) {
                // Titlebar spacer
                Color(nsColor: .windowBackgroundColor)
                    .frame(height: 32)

                // Content area - expands to fill space
                ZStack {
                    if audioRecorder.isRecording {
                        AudioVisualizationView(audioLevel: audioRecorder.audioLevel, color: .accentColor)
                            .frame(height: 100)
                    } else if isProcessing {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Transcribing...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    } else if transcription.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "mic.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                            Text("Ready to record")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        TextEditor(text: $transcription)
                            .font(.system(size: 14))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)

                // Hotkey hint - fixed at bottom
                HStack {
                    Spacer()
                    if let hotkey = hotkeyManager.currentHotkey {
                        Text("Press \(hotkey.displayString) to record")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Set a hotkey in settings")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            .frame(width: 400)
            .background(Color(nsColor: .windowBackgroundColor))
            .onHover { hovering in
                isHoveringWindow = hovering
                if let window = NSApplication.shared.windows.first(where: { $0.identifier == WindowIdentifiers.main }) {
                    window.standardWindowButton(.closeButton)?.alphaValue = hovering ? 1.0 : 0.0
                    window.standardWindowButton(.miniaturizeButton)?.alphaValue = hovering ? 1.0 : 0.0
                    window.standardWindowButton(.zoomButton)?.alphaValue = hovering ? 1.0 : 0.0
                }
            }

            // Copy button overlay
            Button(action: copyTranscription) {
                Group {
                    if #available(macOS 14.0, *) {
                        Image(systemName: showCopiedNotification ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundStyle(showCopiedNotification ? Color(nsColor: .systemGreen) : .secondary)
                            .frame(width: 20, height: 20)
                            .contentTransition(.symbolEffect(.replace))
                    } else {
                        Image(systemName: showCopiedNotification ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundStyle(showCopiedNotification ? Color(nsColor: .systemGreen) : .secondary)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(showCopiedNotification ? "Copied!" : "Copy transcription")
            .opacity(transcription.isEmpty ? 0 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showCopiedNotification)
            .padding(.top, 6)
            .padding(.trailing, 6)
        }
        .ignoresSafeArea(.all, edges: .top)
        .onChange(of: onboardingManager.showOnboarding) { newValue in
            DebugLog.info("Onboarding state changed to \(newValue)", context: "ContentView")

            if newValue {
                // Hide main window before opening onboarding
                if let mainWindow = NSApplication.shared.windows.first(where: { $0.identifier == WindowIdentifiers.main }) {
                    DebugLog.info("Hiding main window before opening onboarding", context: "ContentView")
                    mainWindow.setIsVisible(false)
                }

                // Open onboarding window
                DebugLog.info("Opening onboarding window", context: "ContentView")
                openWindow(id: "onboarding")
            }
            // Note: Window closing is handled by the onboardingComplete notification
        }
        .alert("Enter API Key", isPresented: $showingAPIKeyAlert) {
            TextField("API Key", text: $apiKey)
            Button("Save") {
                let keyName = transcriptionProviderManager.selectedProvider.apiKeyName
                KeychainHelper.save(key: keyName, value: apiKey)
                apiKey = ""
            }
            Button("Cancel", role: .cancel) {
                apiKey = ""
            }
        } message: {
            Text("Your API key will be securely stored in Keychain")
        }
        .onChange(of: audioRecorder.audioLevel) { newValue in
            // Update overlay with audio level (ensure main thread)
            DispatchQueue.main.async {
                DebugLog.info("📊 Updating overlay audioLevel: \(newValue)", context: "ContentView")
                overlayManager.audioLevel = newValue
            }
        }
        .onAppear {
            DebugLog.info("ContentView onAppear - checking onboarding status", context: "ContentView")

            // Only check onboarding status once on first launch
            if !hasCheckedOnboarding {
                onboardingManager.checkOnboardingStatus()
                hasCheckedOnboarding = true
                DebugLog.info("Initial onboarding state: \(onboardingManager.showOnboarding)", context: "ContentView")
            } else {
                DebugLog.info("Skipping onboarding check (already checked)", context: "ContentView")
            }

            // Set up CMD+C keyboard shortcut handler
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                guard event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" else {
                    return event
                }

                // Debug: Log event window information
                if let eventWindow = event.window {
                    DebugLog.info("CMD+C - event.window identifier: \(eventWindow.identifier?.rawValue ?? "nil"), title: '\(eventWindow.title)'", context: "ContentView")
                } else {
                    DebugLog.info("CMD+C - event.window is nil", context: "ContentView")
                }

                // Check which window received this event
                guard let eventWindow = event.window,
                      eventWindow.identifier == WindowIdentifiers.main else {
                    DebugLog.info("CMD+C not from main window, ignoring", context: "ContentView")
                    return event
                }

                DebugLog.info("CMD+C pressed in main ContentView window - attempting copy", context: "ContentView")

                if !transcription.isEmpty {
                    copyTranscription()
                    DebugLog.info("Transcription copied successfully", context: "ContentView")
                    return nil  // Prevent event propagation to avoid beep
                } else {
                    DebugLog.info("No transcription to copy", context: "ContentView")
                }

                return event
            }

            // Migrate old keychain items if needed (for smooth upgrade)
            let transcriptionProvider = transcriptionProviderManager.selectedProvider
            let llmProvider = llmProviderManager.selectedProvider
            let transcriptionKeyName = transcriptionProvider.apiKeyName
            let llmKeyName = llmProvider.apiKeyName

            if SecretsLoader.transcriptionKey(for: transcriptionProvider) == nil {
                KeychainHelper.migrateIfNeeded(key: transcriptionKeyName)
            }

            if SecretsLoader.llmKey(for: llmProvider) == nil {
                KeychainHelper.migrateIfNeeded(key: llmKeyName)
            }

            // Check for API keys on launch (only prompt when no bundled key exists)
            if resolvedTranscriptionApiKey() == nil && !onboardingManager.showOnboarding {
                showingAPIKeyAlert = true
            }

            // Note: Accessibility permissions are now handled by onboarding
            // Old code commented out - handled by OnboardingManager now

            DebugLog.info("========================================", context: "ContentView")
            DebugLog.info("onAppear - Setting up hotkey callbacks", context: "ContentView")
            DebugLog.info("========================================", context: "ContentView")

            // Hide overlay by default - it will show when hotkey is used
            overlayManager.hide()

            // Set up hotkey callbacks (auto-paste enabled for hotkey)
            hotkeyManager.onHotkeyPressed = { [self] in
                DebugLog.info("🎯 onHotkeyPressed callback triggered! 🎯", context: "ContentView")

                // Ignore hotkey during onboarding
                if onboardingManager.showOnboarding {
                    DebugLog.info("⚠️ Ignoring hotkey - onboarding in progress", context: "ContentView")
                    return
                }

                // Only auto-paste when in overlay mode (app is in background)
                // When main window is visible, just display the transcription without pasting
                if overlayManager.isOverlayMode {
                    DebugLog.info("Overlay mode active - will auto-paste", context: "ContentView")
                    shouldAutoPaste = true
                } else {
                    DebugLog.info("Main window active - will NOT auto-paste", context: "ContentView")
                    shouldAutoPaste = false
                }

                DebugLog.info("isRecording: \(audioRecorder.isRecording), isProcessing: \(isProcessing)", context: "ContentView")

                // Just start recording - don't change window visibility
                // The app foreground/background state determines overlay vs main window
                if !audioRecorder.isRecording && !isProcessing {
                    DebugLog.info("Starting recording...", context: "ContentView")
                    startRecording()
                } else {
                    DebugLog.info("NOT starting recording (already recording or processing)", context: "ContentView")
                }
            }

            hotkeyManager.onHotkeyReleased = { [self] in
                DebugLog.info("🎯 onHotkeyReleased callback triggered! 🎯", context: "ContentView")

                // Ignore hotkey during onboarding
                if onboardingManager.showOnboarding {
                    DebugLog.info("⚠️ Ignoring hotkey release - onboarding in progress", context: "ContentView")
                    return
                }

                DebugLog.info("isRecording: \(audioRecorder.isRecording)", context: "ContentView")
                if audioRecorder.isRecording && !isContinuousRecording {
                    DebugLog.info("Stopping hold-to-record and transcribing...", context: "ContentView")
                    stopRecordingAndTranscribe()
                } else {
                    DebugLog.info("NOT stopping recording (continuous mode or not recording)", context: "ContentView")
                }
            }

            hotkeyManager.onDoubleTap = { [self] in
                DebugLog.info("🎯🎯 onDoubleTap callback triggered! 🎯🎯", context: "ContentView")

                // Ignore hotkey during onboarding
                if onboardingManager.showOnboarding {
                    DebugLog.info("⚠️ Ignoring double-tap - onboarding in progress", context: "ContentView")
                    return
                }

                // Toggle continuous recording
                if isContinuousRecording && audioRecorder.isRecording {
                    DebugLog.info("Double-tap: Stopping continuous recording", context: "ContentView")
                    isContinuousRecording = false
                    shouldAutoPaste = false
                    stopRecordingAndTranscribe()
                } else if !audioRecorder.isRecording && !isProcessing {
                    DebugLog.info("Double-tap: Starting continuous recording", context: "ContentView")
                    isContinuousRecording = true

                    // Only auto-paste when in overlay mode
                    if overlayManager.isOverlayMode {
                        DebugLog.info("Overlay mode active - will auto-paste continuous recording", context: "ContentView")
                        shouldAutoPaste = true
                    } else {
                        DebugLog.info("Main window active - will NOT auto-paste continuous recording", context: "ContentView")
                        shouldAutoPaste = false
                    }

                    // Just start recording - don't change window visibility
                    startRecording()
                } else {
                    DebugLog.info("Double-tap: Already recording or processing", context: "ContentView")
                }
            }

            DebugLog.info("Hotkey callbacks configured!", context: "ContentView")

            // Set up notification observers for menu bar actions
            NotificationCenter.default.addObserver(
                forName: .showHistory,
                object: nil,
                queue: .main
            ) { [self] _ in
                openWindow(id: "history")
            }

            NotificationCenter.default.addObserver(
                forName: .showSettings,
                object: nil,
                queue: .main
            ) { [self] _ in
                openWindow(id: "settings")
            }

            NotificationCenter.default.addObserver(
                forName: .showOnboarding,
                object: nil,
                queue: .main
            ) { [self] _ in
                onboardingManager.reopenOnboarding()
            }

            NotificationCenter.default.addObserver(
                forName: .onboardingComplete,
                object: nil,
                queue: .main
            ) { _ in
                DebugLog.info("Received onboardingComplete notification", context: "ContentView")

                // Close onboarding window
                let windows = NSApplication.shared.windows
                DebugLog.info("Looking for onboarding window to close. Total windows: \(windows.count)", context: "ContentView")

                for (index, window) in windows.enumerated() {
                    DebugLog.info("Window \(index): title='\(window.title)', id=\(window.identifier?.rawValue ?? "nil")", context: "ContentView")
                }

                if let onboardingWindow = windows.first(where: {
                    $0.title == "Welcome to Whispermate" || $0.identifier?.rawValue == "onboarding"
                }) {
                    DebugLog.info("Found onboarding window, closing it", context: "ContentView")
                    onboardingWindow.close()
                } else {
                    DebugLog.info("⚠️ Could not find onboarding window to close", context: "ContentView")
                }

                // Show and activate main window
                if let mainWindow = NSApplication.shared.windows.first(where: { $0.identifier == WindowIdentifiers.main }) {
                    DebugLog.info("Found main window, showing and activating", context: "ContentView")
                    mainWindow.setIsVisible(true)
                    mainWindow.makeKeyAndOrderFront(nil)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } else {
                    DebugLog.info("⚠️ Could not find main window", context: "ContentView")
                }
            }

            // Set up app state observers for overlay management
            NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [self] _ in
                DebugLog.info("🌙 App went to background - showing overlay", context: "ContentView")
                overlayManager.isOverlayMode = true
                overlayManager.show()
                // Hide main window when going to background
                if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
                    window.setIsVisible(false)
                }
            }

            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [self] _ in
                DebugLog.info("☀️ App came to foreground - hiding overlay", context: "ContentView")
                overlayManager.isOverlayMode = false
                overlayManager.hide()

                // Don't show main window if onboarding is active
                if onboardingManager.showOnboarding {
                    DebugLog.info("Onboarding active - keeping main window hidden", context: "ContentView")
                    return
                }

                // Show main window when coming to foreground
                if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
                    window.setIsVisible(true)
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        .onDisappear {
            DebugLog.info("🧹 onDisappear - Cleaning up observers", context: "ContentView")

            // Remove notification observers to prevent leaks
            NotificationCenter.default.removeObserver(self, name: .showHistory, object: nil)
            NotificationCenter.default.removeObserver(self, name: .showSettings, object: nil)
            NotificationCenter.default.removeObserver(self, name: .showOnboarding, object: nil)

            DebugLog.info("✅ Observer cleanup complete", context: "ContentView")
        }
    }

    private func handleRecordButton() {
        DebugLog.info("handleRecordButton called - isRecording: \(audioRecorder.isRecording), isProcessing: \(isProcessing)", context: "ContentView")

        // Button is only used in main window (when app is in foreground)
        // No need to manage overlay mode here

        if audioRecorder.isRecording {
            DebugLog.info("handleRecordButton: stopping recording", context: "ContentView")
            stopRecordingAndTranscribe()
        } else {
            DebugLog.info("handleRecordButton: starting recording", context: "ContentView")
            startRecording()
        }
    }

    private func startRecording() {
        DebugLog.info("🎬 ========== START RECORDING ==========", context: "ContentView")
        errorMessage = ""
        transcription = ""
        recordingStartTime = Date()

        // Capture app context (app name and window title) before recording
        if let context = AppContextHelper.getCurrentAppContext() {
            capturedAppContext = context.description
            DebugLog.info("Captured app context: \(context.description)", context: "ContentView")
        } else {
            capturedAppContext = nil
        }

        // Store the currently active app for pasting later
        PasteHelper.storePreviousApp()

        // Check for transcription API key
        guard resolvedTranscriptionApiKey() != nil else {
            errorMessage = "Please set your \(transcriptionProviderManager.selectedProvider.displayName) transcription API key"
            showingAPIKeyAlert = true
            DebugLog.info("❌ No transcription API key found", context: "ContentView")
            return
        }

        // Update overlay IMMEDIATELY on key down (only if in overlay mode)
        if overlayManager.isOverlayMode {
            overlayManager.updateState(isRecording: true, isProcessing: false)
        }

        DebugLog.info("ℹ️ Starting file-based recording", context: "ContentView")
        audioRecorder.startRecording()
        DebugLog.info("========== START RECORDING COMPLETE ==========", context: "ContentView")
    }

    private func stopRecordingAndTranscribe() {
        DebugLog.info("stopRecordingAndTranscribe called", context: "ContentView")

        // Check recording duration - skip if too short (< 0.3 seconds)
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            DebugLog.info("Recording duration: \(duration) seconds", context: "ContentView")

            if duration < 0.3 {
                DebugLog.info("Recording too short (\(duration)s), skipping transcription", context: "ContentView")
                errorMessage = ""
                shouldAutoPaste = false
                recordingStartTime = nil
                _ = audioRecorder.stopRecording()

                // Update overlay - back to idle (only if in overlay mode)
                if overlayManager.isOverlayMode {
                    overlayManager.updateState(isRecording: false, isProcessing: false)
                }
                return
            }
        }

        // Stop recording and get audio file
        guard let audioURL = audioRecorder.stopRecording() else {
            DebugLog.info("stopRecordingAndTranscribe: failed to get audio URL", context: "ContentView")
            errorMessage = "Failed to save recording"
            if overlayManager.isOverlayMode {
                overlayManager.updateState(isRecording: false, isProcessing: false)
            }
            return
        }

        DebugLog.info("stopRecordingAndTranscribe: got audio URL: \(audioURL)", context: "ContentView")

        // Check if audio file exists and has content
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            DebugLog.info("Audio file size: \(fileSize) bytes", context: "ContentView")

            if fileSize < 1000 { // Less than 1KB (essentially empty)
                DebugLog.info("Audio file too small (\(fileSize) bytes), skipping transcription", context: "ContentView")
                errorMessage = "No audio detected"
                shouldAutoPaste = false
                if overlayManager.isOverlayMode {
                    overlayManager.updateState(isRecording: false, isProcessing: false)
                }

                // Clean up the empty file
                try? FileManager.default.removeItem(at: audioURL)
                return
            }
        } catch {
            DebugLog.info("Error checking audio file: \(error)", context: "ContentView")
            errorMessage = "Failed to verify recording"
            if overlayManager.isOverlayMode {
                overlayManager.updateState(isRecording: false, isProcessing: false)
            }
            return
        }

        // VAD Gatekeeper: Check for speech before making HTTP request
        if vadSettingsManager.vadEnabled {
            DebugLog.info("🎤 VAD enabled - analyzing audio for speech...", context: "ContentView")

            // Show brief processing state during VAD analysis
            isProcessing = true
            if overlayManager.isOverlayMode {
                overlayManager.updateState(isRecording: false, isProcessing: true)
            }

            Task {
                do {
                    let hasSpeech = try await VoiceActivityDetector.hasSpeech(
                        in: audioURL,
                        settings: vadSettingsManager
                    )

                    await MainActor.run {
                        if !hasSpeech {
                            DebugLog.info("🔇 No speech detected - skipping transcription", context: "ContentView")
                            errorMessage = "No speech detected"
                            shouldAutoPaste = false
                            isProcessing = false

                            if overlayManager.isOverlayMode {
                                overlayManager.updateState(isRecording: false, isProcessing: false)
                            }

                            // Clean up the audio file
                            try? FileManager.default.removeItem(at: audioURL)
                            return
                        }

                        DebugLog.info("✅ Speech detected - proceeding with transcription", context: "ContentView")
                        // Continue with transcription
                        continueWithTranscription(audioURL: audioURL)
                    }
                } catch {
                    DebugLog.info("⚠️ VAD error: \(error.localizedDescription), proceeding with transcription anyway", context: "ContentView")
                    await MainActor.run {
                        // If VAD fails, continue with transcription rather than blocking
                        continueWithTranscription(audioURL: audioURL)
                    }
                }
            }
            return
        }

        // Continue with transcription (no VAD check or VAD is disabled)
        continueWithTranscription(audioURL: audioURL)
    }

    private func continueWithTranscription(audioURL: URL) {
        // Get transcription API key
        guard let transcriptionApiKey = resolvedTranscriptionApiKey() else {
            DebugLog.info("continueWithTranscription: no transcription API key found", context: "ContentView")
            errorMessage = "Please set your \(transcriptionProviderManager.selectedProvider.displayName) transcription API key"
            showingAPIKeyAlert = true
            if overlayManager.isOverlayMode {
                overlayManager.updateState(isRecording: false, isProcessing: false)
            }
            return
        }

        // Get LLM API key (optional - only needed if rules are enabled)
        let enabledRules = promptRulesManager.rules.filter { $0.isEnabled }.map { $0.text }
        var llmApiKey: String? = nil
        if !enabledRules.isEmpty {
            llmApiKey = resolvedLLMApiKey()
            if llmApiKey == nil {
                DebugLog.info("Warning: LLM API key not found, skipping text correction", context: "ContentView")
            }
        }

        DebugLog.info("continueWithTranscription: starting transcription, shouldAutoPaste: \(shouldAutoPaste)", context: "ContentView")
        isProcessing = true

        // Update overlay - stopped recording, now processing (only if in overlay mode)
        if overlayManager.isOverlayMode {
            overlayManager.updateState(isRecording: false, isProcessing: true)
        }

        Task {
            do {
                let languageCode = languageManager.apiLanguageCode

                DebugLog.info("Calling transcription API...", context: "ContentView")
                DebugLog.info("Provider: \(transcriptionProviderManager.selectedProvider.displayName)", context: "ContentView")
                DebugLog.info("Endpoint: \(transcriptionProviderManager.effectiveEndpoint)", context: "ContentView")
                DebugLog.info("Model: \(transcriptionProviderManager.effectiveModel)", context: "ContentView")
                DebugLog.info("Using language: \(languageCode ?? "auto-detect")", context: "ContentView")
                DebugLog.info("App context: \(capturedAppContext ?? "none")", context: "ContentView")
                DebugLog.info("Enabled rules count: \(enabledRules.count)", context: "ContentView")

                // Create unified OpenAI client with both endpoints configured
                let config = OpenAIClient.Configuration(
                    transcriptionEndpoint: transcriptionProviderManager.effectiveEndpoint,
                    transcriptionModel: transcriptionProviderManager.effectiveModel,
                    chatCompletionEndpoint: llmProviderManager.effectiveEndpoint,
                    chatCompletionModel: llmProviderManager.effectiveModel,
                    apiKey: transcriptionApiKey
                )

                let openAIClient = OpenAIClient(config: config)

                // Use transcribeAndFormat to handle both steps with proper timing
                let result = try await openAIClient.transcribeAndFormat(
                    audioURL: audioURL,
                    prompt: nil,
                    formattingRules: enabledRules,
                    languageCodes: languageCode,
                    appContext: capturedAppContext,
                    llmApiKey: llmApiKey
                )

                DebugLog.sensitive("Transcription received: \(result)", context: "ContentView")
                await MainActor.run {
                    transcription = result
                    isProcessing = false
                    errorMessage = ""

                    // Update overlay - processing complete (only if in overlay mode)
                    if overlayManager.isOverlayMode {
                        overlayManager.updateState(isRecording: false, isProcessing: false)
                    }

                    // Calculate duration
                    let duration = recordingStartTime.map { Date().timeIntervalSince($0) }

                    // Save to history
                    let recording = Recording(transcription: result, duration: duration)
                    historyManager.addRecording(recording)

                    // Auto-paste if triggered by hotkey (but not during onboarding)
                    if shouldAutoPaste && !onboardingManager.showOnboarding {
                        DebugLog.info("Auto-pasting transcription result", context: "ContentView")
                        shouldAutoPaste = false

                        // Always attempt to paste - this will trigger the system to add us to Accessibility list
                        PasteHelper.copyAndPaste(result)

                        // After attempting paste, check if permission was granted
                        // Wait a moment for the paste to complete/fail
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let trusted = AXIsProcessTrusted()
                            DebugLog.info("Post-paste permission check: \(trusted)", context: "ContentView")

                            if !trusted {
                                DebugLog.info("⚠️ Paste may have failed - accessibility permission not granted", context: "ContentView")

                                // Show alert to help user enable permission
                                let alert = NSAlert()
                                alert.messageText = "Enable Auto-Paste"
                                alert.informativeText = "WhisperMate has been added to Accessibility settings but needs to be enabled.\n\nYour transcription is in the clipboard.\n\nTo enable auto-paste:\n1. Open System Settings (button below)\n2. Go to Privacy & Security > Accessibility\n3. Find WhisperMate in the list\n4. Toggle it ON"
                                alert.alertStyle = .informational
                                alert.addButton(withTitle: "Open System Settings")
                                alert.addButton(withTitle: "OK")

                                let response = alert.runModal()
                                if response == .alertFirstButtonReturn {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                            }
                        }
                    } else {
                        DebugLog.info("Skipping auto-paste (shouldAutoPaste is false)", context: "ContentView")
                    }
                }
            } catch {
                DebugLog.info("Transcription error: \(error.localizedDescription)", context: "ContentView")
                await MainActor.run {
                    transcription = ""
                    isProcessing = false
                    errorMessage = "Transcription failed: \(error.localizedDescription)"
                    shouldAutoPaste = false

                    // Update overlay - processing failed (only if in overlay mode)
                    if overlayManager.isOverlayMode {
                        overlayManager.updateState(isRecording: false, isProcessing: false)
                    }
                }
            }
        }
    }

    private func resolvedTranscriptionApiKey() -> String? {
        let provider = transcriptionProviderManager.selectedProvider
        if let storedKey = KeychainHelper.get(key: provider.apiKeyName), !storedKey.isEmpty {
            DebugLog.sensitive("Using keychain transcription key for provider: \(provider.displayName)", context: "ContentView")
            return storedKey
        }
        if let bundledKey = SecretsLoader.transcriptionKey(for: provider), !bundledKey.isEmpty {
            DebugLog.sensitive("Using bundled transcription key for provider: \(provider.displayName)", context: "ContentView")
            return bundledKey
        }
        DebugLog.warning("No transcription key found for provider: \(provider.displayName)", context: "ContentView")
        return nil
    }

    private func resolvedLLMApiKey() -> String? {
        let provider = llmProviderManager.selectedProvider
        if let storedKey = KeychainHelper.get(key: provider.apiKeyName), !storedKey.isEmpty {
            DebugLog.sensitive("Using keychain LLM key for provider: \(provider.displayName)", context: "ContentView")
            return storedKey
        }
        if let bundledKey = SecretsLoader.llmKey(for: provider), !bundledKey.isEmpty {
            DebugLog.sensitive("Using bundled LLM key for provider: \(provider.displayName)", context: "ContentView")
            return bundledKey
        }
        DebugLog.warning("No LLM key found for provider: \(provider.displayName)", context: "ContentView")
        return nil
    }

    // MARK: - Copy Function
    func copyTranscription() {
        guard !transcription.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcription, forType: .string)
        DebugLog.info("Transcription copied via button", context: "ContentView")

        // Show copied notification
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showCopiedNotification = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedNotification = false
            }
        }
    }
}

#Preview {
    ContentView()
}
