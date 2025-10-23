import SwiftUI
import AVFoundation
import AppKit

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var hotkeyManager = HotkeyManager()
    @StateObject private var historyManager = HistoryManager()
    @StateObject private var overlayManager = OverlayWindowManager()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var transcriptionProviderManager = TranscriptionProviderManager()
    @StateObject private var llmProviderManager = LLMProviderManager()
    @StateObject private var promptRulesManager = PromptRulesManager()
    @State private var transcription = ""
    @State private var isTranscriptVisible = false
    @State private var isProcessing = false
    @State private var showingAPIKeyAlert = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var apiKey = ""
    @State private var errorMessage = ""
    @State private var recordingStartTime: Date?
    @State private var shouldAutoPaste = false
    @State private var isDragging = false
    @State private var windowPosition: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Main Content - text area (always present for smooth animation)
                VStack(spacing: 0) {
                    // Top toolbar with contract and copy buttons
                    HStack {
                        // Contract button (only shown when NOT in overlay mode)
                        if !overlayManager.isOverlayMode {
                            Button(action: {
                                overlayManager.contractToOverlay()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                                        .font(.system(size: 10))
                                    Text("Contract")
                                        .font(.system(size: 11))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        // Copy button
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(transcription, forType: .string)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                Text("Copy")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(transcription.isEmpty ? 0 : 1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    // Text editor with padding
                    TextEditor(text: $transcription)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: isTranscriptVisible ? 280 : 0)
                .background(Color(nsColor: .textBackgroundColor))
                .opacity(isTranscriptVisible ? 1 : 0)

                // Record Button with refined Apple-style design (stays at bottom)
                Button(action: {
                    print("[LOG] Button clicked")
                    shouldAutoPaste = true
                    handleRecordButton()
                }) {
                    if audioRecorder.isRecording {
                        // Show visualization when recording
                        AudioVisualizationView(audioLevel: audioRecorder.audioLevel)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.9))
                            )
                    } else {
                        // Show normal button content when not recording
                        HStack(spacing: 8) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                            if let hotkey = hotkeyManager.currentHotkey {
                                Text("Start Recording (\(hotkey.displayString))")
                                    .font(.system(size: 15, weight: .semibold))
                            } else {
                                Text("Start Recording")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isProcessing ? Color(nsColor: .systemGray) : Color.accentColor)
                        )
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
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
            }
            .frame(width: 400)
        }
        .frame(width: 400)
        .frame(height: isTranscriptVisible ? 360 : 40)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isTranscriptVisible)
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                hotkeyManager: hotkeyManager,
                languageManager: languageManager,
                transcriptionProviderManager: transcriptionProviderManager,
                llmProviderManager: llmProviderManager,
                promptRulesManager: promptRulesManager
            )
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(historyManager: historyManager)
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
        .onChange(of: audioRecorder.audioLevel) { oldValue, newValue in
            // Update overlay with audio level (ensure main thread)
            DispatchQueue.main.async {
                print("[ContentView] 📊 Updating overlay audioLevel: \(oldValue) -> \(newValue)")
                overlayManager.audioLevel = newValue
            }
        }
        .onAppear {
            isTranscriptVisible = !transcription.isEmpty

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
            if resolvedTranscriptionApiKey() == nil {
                showingAPIKeyAlert = true
            }

            // Request accessibility permissions explicitly on first launch
            // This ensures the app appears in System Settings > Accessibility
            print("[ContentView LOG] Requesting accessibility permissions...")

            // First, attempt to create a CGEvent - this triggers macOS to add us to the Accessibility list
            if let source = CGEventSource(stateID: .hidSystemState) {
                // Create a benign event (we won't post it, just creating it is enough)
                let _ = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
                print("[ContentView LOG] Created test CGEvent to trigger Accessibility registration")
            }

            // Now request permission with prompt
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
            let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
            print("[ContentView LOG] Accessibility permission: \(trusted)")

            print("[ContentView LOG] ========================================")
            print("[ContentView LOG] onAppear - Setting up hotkey callbacks")
            print("[ContentView LOG] ========================================")

            // Hide overlay by default - it will show when hotkey is used
            overlayManager.hide()

            // Set up hotkey callbacks (auto-paste enabled for hotkey)
            hotkeyManager.onHotkeyPressed = { [self] in
                print("[ContentView LOG] 🎯 onHotkeyPressed callback triggered! 🎯")
                print("[ContentView LOG] shouldAutoPaste will be set to TRUE")
                print("[ContentView LOG] isRecording: \(audioRecorder.isRecording), isProcessing: \(isProcessing)")
                shouldAutoPaste = true
                overlayManager.isOverlayMode = true

                // Hide main window when using hotkey
                if let window = NSApplication.shared.windows.first(where: { $0.level == .normal }) {
                    window.orderOut(nil)
                }

                // Show overlay when using hotkey
                overlayManager.show()

                if !audioRecorder.isRecording && !isProcessing {
                    print("[ContentView LOG] Starting recording...")
                    startRecording()
                } else {
                    print("[ContentView LOG] NOT starting recording (already recording or processing)")
                }
            }

            hotkeyManager.onHotkeyReleased = { [self] in
                print("[ContentView LOG] 🎯 onHotkeyReleased callback triggered! 🎯")
                print("[ContentView LOG] isRecording: \(audioRecorder.isRecording)")
                if audioRecorder.isRecording {
                    print("[ContentView LOG] Stopping recording and transcribing...")
                    stopRecordingAndTranscribe()
                } else {
                    print("[ContentView LOG] NOT stopping recording (not currently recording)")
                }
            }

            print("[ContentView LOG] Hotkey callbacks configured!")

            // Set up notification observers for menu bar actions
            NotificationCenter.default.addObserver(
                forName: .showHistory,
                object: nil,
                queue: .main
            ) { [self] _ in
                showingHistory = true
            }

            NotificationCenter.default.addObserver(
                forName: .showSettings,
                object: nil,
                queue: .main
            ) { [self] _ in
                showingSettings = true
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
            window.orderFront(nil)
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isTranscriptVisible = false
            transcription = ""
        }
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

                let groqService = GroqService(
                    transcriptionApiKey: transcriptionApiKey,
                    transcriptionEndpoint: transcriptionProviderManager.effectiveEndpoint,
                    transcriptionModel: transcriptionProviderManager.effectiveModel,
                    llmApiKey: llmApiKey,
                    llmEndpoint: llmProviderManager.effectiveEndpoint,
                    llmModel: llmProviderManager.effectiveModel
                )

                let result = try await groqService.transcribeAndFix(
                    audioURL: audioURL,
                    language: languageCode,
                    prompt: nil,
                    rules: enabledRules
                )

                print("[LOG] Transcription received: \(result)")
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        transcription = result
                        isTranscriptVisible = !result.isEmpty && !overlayManager.isOverlayMode  // Only show in main window if not in overlay mode
                    }
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

                    // Auto-paste if triggered by hotkey
                    if shouldAutoPaste {
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        transcription = ""
                        isTranscriptVisible = false
                    }
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
            print("[ContentView LOG] Using keychain transcription key for provider: \(provider.displayName)")
            return storedKey
        }
        if let bundledKey = SecretsLoader.transcriptionKey(for: provider), !bundledKey.isEmpty {
            print("[ContentView LOG] Using bundled transcription key for provider: \(provider.displayName)")
            return bundledKey
        }
        print("[ContentView LOG] No transcription key found for provider: \(provider.displayName)")
        return nil
    }

    private func resolvedLLMApiKey() -> String? {
        let provider = llmProviderManager.selectedProvider
        if let storedKey = KeychainHelper.get(key: provider.apiKeyName), !storedKey.isEmpty {
            print("[ContentView LOG] Using keychain LLM key for provider: \(provider.displayName)")
            return storedKey
        }
        if let bundledKey = SecretsLoader.llmKey(for: provider), !bundledKey.isEmpty {
            print("[ContentView LOG] Using bundled LLM key for provider: \(provider.displayName)")
            return bundledKey
        }
        print("[ContentView LOG] No LLM key found for provider: \(provider.displayName)")
        return nil
    }
}

#Preview {
    ContentView()
}
