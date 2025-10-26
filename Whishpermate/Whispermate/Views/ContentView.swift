import SwiftUI
import AVFoundation
import AppKit

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var hotkeyManager = HotkeyManager()
    @StateObject private var historyManager = HistoryManager()
    @StateObject private var overlayManager = OverlayWindowManager()
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var transcriptionProviderManager = TranscriptionProviderManager()
    @StateObject private var llmProviderManager = LLMProviderManager()
    @StateObject private var promptRulesManager = PromptRulesManager()
    @State private var transcription = ""
    @State private var isProcessing = false
    @State private var showingAPIKeyAlert = false
    @State private var showOnboarding = false
    @State private var apiKey = ""
    @Environment(\.openWindow) private var openWindow
    @State private var errorMessage = ""
    @State private var recordingStartTime: Date?
    @State private var shouldAutoPaste = false
    @State private var isDragging = false
    @State private var windowPosition: CGPoint?
    @State private var isContinuousRecording = false

    var body: some View {
        ZStack {
            Color.clear  // Transparent background for entire window

            GeometryReader { geometry in
                // Outer container with rounded corners that expands/contracts
                VStack(spacing: 0) {
                // Top toolbar with contract and copy buttons
                HStack(spacing: 8) {
                    Spacer()

                    // Copy button
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(transcription, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help("Copy transcription")
                    .opacity(transcription.isEmpty ? 0 : 1)

                    // Contract button (only shown when NOT in overlay mode)
                    if !overlayManager.isOverlayMode {
                        Button(action: {
                            overlayManager.contractToOverlay()
                        }) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .help("Contract to overlay mode")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
                                if windowPosition == nil {
                                    windowPosition = window.frame.origin
                                }
                                let newOrigin = CGPoint(
                                    x: windowPosition!.x + value.translation.width,
                                    y: windowPosition!.y - value.translation.height
                                )
                                window.setFrameOrigin(newOrigin)
                            }
                        }
                        .onEnded { _ in
                            windowPosition = nil
                        }
                )

                // State-aware content area
                VStack(spacing: 0) {
                    // Main content area
                    ZStack {
                        if audioRecorder.isRecording {
                            // Recording state: Show waveform visualization (large)
                            AudioVisualizationView(audioLevel: audioRecorder.audioLevel, color: .accentColor)
                                .frame(height: 100)
                        } else if isProcessing {
                            // Transcribing state: Show spinner
                            VStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.large)
                                Text("Transcribing...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        } else if transcription.isEmpty {
                            // Idle state: Show instructions
                            VStack(spacing: 8) {
                                Image(systemName: "mic.circle")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.tertiary)
                                Text("Ready to record")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            // Result state: Show transcribed text
                            TextEditor(text: $transcription)
                                .font(.system(size: 14))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Hotkey hint (always visible at bottom)
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
                .padding(.horizontal, 16)
                .padding(.top, 0)
                .padding(.bottom, 8)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(width: 400)
            }
        }
        .frame(width: 400)
        .frame(height: 320)
        .background(Color.clear)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(
                onboardingManager: onboardingManager,
                hotkeyManager: hotkeyManager,
                promptRulesManager: promptRulesManager
            )
            .interactiveDismissDisabled(true)
        }
        .onChange(of: onboardingManager.showOnboarding) { newValue in
            showOnboarding = newValue
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
                print("[ContentView] 📊 Updating overlay audioLevel: \(newValue)")
                overlayManager.audioLevel = newValue
            }
        }
        .onAppear {
            // Check onboarding status first
            onboardingManager.checkOnboardingStatus()

            // Sync initial onboarding state
            if onboardingManager.showOnboarding {
                showOnboarding = true
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

            print("[ContentView LOG] ========================================")
            print("[ContentView LOG] onAppear - Setting up hotkey callbacks")
            print("[ContentView LOG] ========================================")

            // Hide overlay by default - it will show when hotkey is used
            overlayManager.hide()

            // Set up hotkey callbacks (auto-paste enabled for hotkey)
            hotkeyManager.onHotkeyPressed = { [self] in
                print("[ContentView LOG] 🎯 onHotkeyPressed callback triggered! 🎯")

                // Ignore hotkey during onboarding
                if onboardingManager.showOnboarding {
                    print("[ContentView LOG] ⚠️ Ignoring hotkey - onboarding in progress")
                    return
                }

                print("[ContentView LOG] shouldAutoPaste will be set to TRUE")
                print("[ContentView LOG] isRecording: \(audioRecorder.isRecording), isProcessing: \(isProcessing)")
                print("[ContentView LOG] Current mode: \(overlayManager.isOverlayMode ? "overlay" : "full")")
                shouldAutoPaste = true

                // Show appropriate UI based on current mode
                if overlayManager.isOverlayMode {
                    // In overlay mode - hide main window, show overlay
                    if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
                        window.setIsVisible(false)
                    }
                    overlayManager.show()
                } else {
                    // In full mode - show main window, hide overlay
                    overlayManager.hide()
                    if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
                        window.setIsVisible(true)
                        window.makeKeyAndOrderFront(nil)
                    }
                }

                if !audioRecorder.isRecording && !isProcessing {
                    print("[ContentView LOG] Starting recording...")
                    startRecording()
                } else {
                    print("[ContentView LOG] NOT starting recording (already recording or processing)")
                }
            }

            hotkeyManager.onHotkeyReleased = { [self] in
                print("[ContentView LOG] 🎯 onHotkeyReleased callback triggered! 🎯")

                // Ignore hotkey during onboarding
                if onboardingManager.showOnboarding {
                    print("[ContentView LOG] ⚠️ Ignoring hotkey release - onboarding in progress")
                    return
                }

                print("[ContentView LOG] isRecording: \(audioRecorder.isRecording)")
                if audioRecorder.isRecording && !isContinuousRecording {
                    print("[ContentView LOG] Stopping hold-to-record and transcribing...")
                    stopRecordingAndTranscribe()
                } else {
                    print("[ContentView LOG] NOT stopping recording (continuous mode or not recording)")
                }
            }

            hotkeyManager.onDoubleTap = { [self] in
                print("[ContentView LOG] 🎯🎯 onDoubleTap callback triggered! 🎯🎯")

                // Ignore hotkey during onboarding
                if onboardingManager.showOnboarding {
                    print("[ContentView LOG] ⚠️ Ignoring double-tap - onboarding in progress")
                    return
                }

                // Toggle continuous recording
                if isContinuousRecording && audioRecorder.isRecording {
                    print("[ContentView LOG] Double-tap: Stopping continuous recording")
                    isContinuousRecording = false
                    shouldAutoPaste = false
                    stopRecordingAndTranscribe()
                } else if !audioRecorder.isRecording && !isProcessing {
                    print("[ContentView LOG] Double-tap: Starting continuous recording")
                    isContinuousRecording = true
                    shouldAutoPaste = true

                    // Show appropriate UI based on current mode
                    if overlayManager.isOverlayMode {
                        if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
                            window.setIsVisible(false)
                        }
                        overlayManager.show()
                    } else {
                        overlayManager.hide()
                        if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
                            window.setIsVisible(true)
                            window.makeKeyAndOrderFront(nil)
                        }
                    }

                    startRecording()
                } else {
                    print("[ContentView LOG] Double-tap: Already recording or processing")
                }
            }

            print("[ContentView LOG] Hotkey callbacks configured!")

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

            // Set up app state observers for overlay management
            NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [self] _ in
                print("[ContentView LOG] 🌙 App went to background - showing overlay")
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
                print("[ContentView LOG] ☀️ App came to foreground - hiding overlay")
                overlayManager.hide()
                // Show main window when coming to foreground
                if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
                    window.setIsVisible(true)
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        .onDisappear {
            print("[ContentView LOG] 🧹 onDisappear - Cleaning up observers")

            // Remove notification observers to prevent leaks
            NotificationCenter.default.removeObserver(self, name: .showHistory, object: nil)
            NotificationCenter.default.removeObserver(self, name: .showSettings, object: nil)

            print("[ContentView LOG] ✅ Observer cleanup complete")
        }
    }

    private func handleRecordButton() {
        print("[LOG] handleRecordButton called - isRecording: \(audioRecorder.isRecording), isProcessing: \(isProcessing)")

        // Using button means we're in main window mode, not overlay mode
        overlayManager.isOverlayMode = false

        // Hide overlay when using button
        overlayManager.hide()

        // Show main window
        if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
            window.setIsVisible(true)
            window.makeKeyAndOrderFront(nil)
        }

        if audioRecorder.isRecording {
            print("[LOG] handleRecordButton: stopping recording")
            stopRecordingAndTranscribe()
        } else {
            print("[LOG] handleRecordButton: starting recording")
            startRecording()
        }
    }

    private func startRecording() {
        print("[ContentView LOG] 🎬 ========== START RECORDING ==========")
        errorMessage = ""
        transcription = ""
        recordingStartTime = Date()

        // Store the currently active app for pasting later
        PasteHelper.storePreviousApp()

        // Check for transcription API key
        guard resolvedTranscriptionApiKey() != nil else {
            errorMessage = "Please set your \(transcriptionProviderManager.selectedProvider.displayName) transcription API key"
            showingAPIKeyAlert = true
            print("[ContentView LOG] ❌ No transcription API key found")
            return
        }

        // Update overlay IMMEDIATELY on key down (only if in overlay mode)
        if overlayManager.isOverlayMode {
            overlayManager.updateState(isRecording: true, isProcessing: false)
        }

        print("[ContentView LOG] ℹ️ Starting file-based recording")
        audioRecorder.startRecording()
        print("[ContentView LOG] ========== START RECORDING COMPLETE ==========")
    }

    private func stopRecordingAndTranscribe() {
        print("[LOG] stopRecordingAndTranscribe called")

        // Check recording duration - skip if too short (< 0.3 seconds)
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print("[LOG] Recording duration: \(duration) seconds")

            if duration < 0.3 {
                print("[LOG] Recording too short (\(duration)s), skipping transcription")
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
            print("[LOG] stopRecordingAndTranscribe: failed to get audio URL")
            errorMessage = "Failed to save recording"
            if overlayManager.isOverlayMode {
                overlayManager.updateState(isRecording: false, isProcessing: false)
            }
            return
        }

        print("[LOG] stopRecordingAndTranscribe: got audio URL: \(audioURL)")

        // Check if audio file exists and has content
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            print("[LOG] Audio file size: \(fileSize) bytes")

            if fileSize < 1000 { // Less than 1KB (essentially empty)
                print("[LOG] Audio file too small (\(fileSize) bytes), skipping transcription")
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
            print("[LOG] Error checking audio file: \(error)")
            errorMessage = "Failed to verify recording"
            if overlayManager.isOverlayMode {
                overlayManager.updateState(isRecording: false, isProcessing: false)
            }
            return
        }

        // Get transcription API key
        guard let transcriptionApiKey = resolvedTranscriptionApiKey() else {
            print("[LOG] stopRecordingAndTranscribe: no transcription API key found")
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
                print("[LOG] Warning: LLM API key not found, skipping text correction")
            }
        }

        print("[LOG] stopRecordingAndTranscribe: starting transcription, shouldAutoPaste: \(shouldAutoPaste)")
        isProcessing = true

        // Update overlay - stopped recording, now processing (only if in overlay mode)
        if overlayManager.isOverlayMode {
            overlayManager.updateState(isRecording: false, isProcessing: true)
        }

        Task {
            do {
                let languageCode = languageManager.apiLanguageCode

                print("[LOG] Calling transcription API...")
                print("[LOG] Provider: \(transcriptionProviderManager.selectedProvider.displayName)")
                print("[LOG] Endpoint: \(transcriptionProviderManager.effectiveEndpoint)")
                print("[LOG] Model: \(transcriptionProviderManager.effectiveModel)")
                print("[LOG] Using language: \(languageCode ?? "auto-detect")")
                print("[LOG] Enabled rules count: \(enabledRules.count)")

                // Create unified OpenAI client for transcription
                // Note: We use transcription API key for transcription, and will create separate client for LLM if needed
                let transcriptionConfig = OpenAIClient.Configuration(
                    transcriptionEndpoint: transcriptionProviderManager.effectiveEndpoint,
                    transcriptionModel: transcriptionProviderManager.effectiveModel,
                    chatCompletionEndpoint: llmProviderManager.effectiveEndpoint,
                    chatCompletionModel: llmProviderManager.effectiveModel,
                    apiKey: transcriptionApiKey
                )

                let openAIClient = OpenAIClient(config: transcriptionConfig)

                // Transcribe first
                var result = try await openAIClient.transcribe(
                    audioURL: audioURL,
                    languageCode: languageCode,
                    prompt: nil
                )

                // Apply formatting rules if we have them and LLM key
                if !enabledRules.isEmpty, let llmKey = llmApiKey {
                    // Update config with LLM API key for chat completion
                    let llmConfig = OpenAIClient.Configuration(
                        transcriptionEndpoint: transcriptionProviderManager.effectiveEndpoint,
                        transcriptionModel: transcriptionProviderManager.effectiveModel,
                        chatCompletionEndpoint: llmProviderManager.effectiveEndpoint,
                        chatCompletionModel: llmProviderManager.effectiveModel,
                        apiKey: llmKey
                    )
                    openAIClient.updateConfig(llmConfig)
                    result = try await openAIClient.applyFormattingRules(transcription: result, rules: enabledRules)
                }

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
                        print("[LOG] Auto-pasting transcription result")
                        shouldAutoPaste = false

                        // Always attempt to paste - this will trigger the system to add us to Accessibility list
                        PasteHelper.copyAndPaste(result)

                        // After attempting paste, check if permission was granted
                        // Wait a moment for the paste to complete/fail
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let trusted = AXIsProcessTrusted()
                            print("[LOG] Post-paste permission check: \(trusted)")

                            if !trusted {
                                print("[LOG] ⚠️ Paste may have failed - accessibility permission not granted")

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
                        print("[LOG] Skipping auto-paste (shouldAutoPaste is false)")
                    }
                }
            } catch {
                print("[LOG] Transcription error: \(error.localizedDescription)")
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
}

#Preview {
    ContentView()
}
