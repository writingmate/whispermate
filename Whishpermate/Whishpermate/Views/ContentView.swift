import SwiftUI

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var hotkeyManager = HotkeyManager()
    @StateObject private var historyManager = HistoryManager()
    @StateObject private var overlayManager = OverlayWindowManager()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var apiProviderManager = APIProviderManager()
    @StateObject private var promptRulesManager = PromptRulesManager()
    @State private var transcription = ""
    @State private var isProcessing = false
    @State private var showingAPIKeyAlert = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var apiKey = ""
    @State private var errorMessage = ""
    @State private var recordingStartTime: Date?
    @State private var shouldAutoPaste = false
    @State private var showingAccessibilityAlert = false

    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            // Header with refined styling
            HStack {
                HStack(spacing: 0) {
                    Text("Whisper")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Mate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Toolbar buttons with hover effects
                HStack(spacing: 8) {
                    Button(action: {
                        showingHistory.toggle()
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("History")

                    Button(action: {
                        showingSettings.toggle()
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
            }
            .padding(.horizontal, max(20, geometry.size.width * 0.05))
            .padding(.vertical, 16)

            Divider()

            // Main Content with improved spacing
            VStack(spacing: 16) {
                // Transcription Display with refined card design
                ScrollView {
                    Text(transcription.isEmpty ? "Press record to start..." : transcription)
                        .font(.system(size: 14))
                        .foregroundStyle(transcription.isEmpty ? .tertiary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )

                // Status Messages with improved styling
                VStack(spacing: 8) {
                    // Recording Status
                    if audioRecorder.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text("Recording...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red)
                        }
                    }

                    // Processing Indicator
                    if isProcessing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.8)
                            Text("Transcribing...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Error Message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(minHeight: 24)
            }
            .padding(.horizontal, max(20, geometry.size.width * 0.05))
            .padding(.vertical, 16)

            Divider()

            // Record Button with refined Apple-style design
            Button(action: {
                print("[LOG] Button clicked")
                shouldAutoPaste = true
                handleRecordButton()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                    if audioRecorder.isRecording {
                        Text("Stop Recording")
                            .font(.system(size: 15, weight: .semibold))
                    } else {
                        if let hotkey = hotkeyManager.currentHotkey {
                            Text("Start Recording (\(hotkey.displayString))")
                                .font(.system(size: 15, weight: .semibold))
                        } else {
                            Text("Start Recording")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isProcessing ? Color(nsColor: .systemGray) : (audioRecorder.isRecording ? Color.red : Color.accentColor))
                )
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .padding(.horizontal, max(20, geometry.size.width * 0.05))
            .padding(.vertical, 16)
        }
        }
        .frame(minWidth: 400, maxWidth: 800, minHeight: 360, maxHeight: 600)
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                hotkeyManager: hotkeyManager,
                languageManager: languageManager,
                apiProviderManager: apiProviderManager,
                promptRulesManager: promptRulesManager
            )
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(historyManager: historyManager)
        }
        .alert("Enter Groq API Key", isPresented: $showingAPIKeyAlert) {
            TextField("API Key", text: $apiKey)
            Button("Save") {
                KeychainHelper.save(key: "groq_api_key", value: apiKey)
                apiKey = ""
            }
            Button("Cancel", role: .cancel) {
                apiKey = ""
            }
        } message: {
            Text("Your API key will be securely stored in Keychain")
        }
        .alert("Accessibility Permission Required", isPresented: $showingAccessibilityAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("WhisperMate needs Accessibility permissions to paste transcriptions into other apps.\n\nPlease enable WhisperMate in System Settings → Privacy & Security → Accessibility")
        }
        .onAppear {
            // Check for API key on launch based on selected provider
            let keyName = apiProviderManager.selectedProvider.apiKeyName
            if KeychainHelper.get(key: keyName) == nil {
                showingAPIKeyAlert = true
            }

            print("[ContentView LOG] ========================================")
            print("[ContentView LOG] onAppear - Setting up hotkey callbacks")
            print("[ContentView LOG] ========================================")

            // Check for Accessibility permissions
            let trusted = AXIsProcessTrusted()
            if !trusted {
                print("[ContentView LOG] ⚠️ Accessibility permissions NOT granted")
                // Show alert after a short delay to let the app settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingAccessibilityAlert = true
                }
            } else {
                print("[ContentView LOG] ✅ Accessibility permissions granted")
            }

            // Show overlay indicator (always visible)
            overlayManager.showAlways()

            // Set up hotkey callbacks (auto-paste enabled for hotkey)
            hotkeyManager.onHotkeyPressed = { [self] in
                print("[ContentView LOG] 🎯 onHotkeyPressed callback triggered! 🎯")
                print("[ContentView LOG] shouldAutoPaste will be set to TRUE")
                print("[ContentView LOG] isRecording: \(audioRecorder.isRecording), isProcessing: \(isProcessing)")
                shouldAutoPaste = true
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
        }
    }

    private func handleRecordButton() {
        print("[LOG] handleRecordButton called - isRecording: \(audioRecorder.isRecording), isProcessing: \(isProcessing)")
        if audioRecorder.isRecording {
            print("[LOG] handleRecordButton: stopping recording")
            stopRecordingAndTranscribe()
        } else {
            print("[LOG] handleRecordButton: starting recording")
            startRecording()
        }
    }

    private func startRecording() {
        print("[LOG] startRecording called")
        errorMessage = ""
        transcription = ""
        recordingStartTime = Date()

        // Store the currently active app for pasting later
        PasteHelper.storePreviousApp()

        audioRecorder.startRecording()
        print("[LOG] startRecording completed - audioRecorder.isRecording: \(audioRecorder.isRecording)")

        // Update overlay
        overlayManager.updateState(isRecording: audioRecorder.isRecording, isProcessing: isProcessing)
    }

    private func stopRecordingAndTranscribe() {
        print("[LOG] stopRecordingAndTranscribe called")
        guard let audioURL = audioRecorder.stopRecording() else {
            print("[LOG] stopRecordingAndTranscribe: failed to get audio URL")
            errorMessage = "Failed to save recording"
            return
        }

        print("[LOG] stopRecordingAndTranscribe: got audio URL: \(audioURL)")

        let keyName = apiProviderManager.selectedProvider.apiKeyName
        guard let apiKey = KeychainHelper.get(key: keyName) else {
            print("[LOG] stopRecordingAndTranscribe: no API key found")
            errorMessage = "Please set your \(apiProviderManager.selectedProvider.displayName) API key"
            showingAPIKeyAlert = true
            return
        }

        print("[LOG] stopRecordingAndTranscribe: starting transcription, shouldAutoPaste: \(shouldAutoPaste)")
        isProcessing = true

        // Update overlay - stopped recording, now processing
        overlayManager.updateState(isRecording: false, isProcessing: true)

        Task {
            do {
                let languageCode = languageManager.apiLanguageCode
                let prompt = promptRulesManager.combinedPrompt
                let provider = apiProviderManager.selectedProvider

                print("[LOG] Calling \(provider.displayName) API for transcription...")
                print("[LOG] Using language: \(languageCode ?? "auto-detect")")
                print("[LOG] Using prompt: \(prompt.isEmpty ? "none" : prompt)")

                let result: String
                switch provider {
                case .groq:
                    result = try await GroqAPIClient.transcribe(audioURL: audioURL, apiKey: apiKey, languageCode: languageCode)
                case .openai:
                    // gpt-4o-transcribe supports instruction-style prompts directly
                    result = try await OpenAIClient.transcribe(audioURL: audioURL, apiKey: apiKey, languageCode: languageCode, prompt: prompt.isEmpty ? nil : prompt)
                }

                print("[LOG] Transcription received: \(result)")
                await MainActor.run {
                    transcription = result
                    isProcessing = false
                    errorMessage = ""

                    // Update overlay - processing complete
                    overlayManager.updateState(isRecording: false, isProcessing: false)

                    // Calculate duration
                    let duration = recordingStartTime.map { Date().timeIntervalSince($0) }

                    // Save to history
                    let recording = Recording(transcription: result, duration: duration)
                    historyManager.addRecording(recording)

                    // Auto-paste if triggered by hold button
                    if shouldAutoPaste {
                        print("[LOG] Auto-pasting transcription result")
                        shouldAutoPaste = false
                        PasteHelper.copyAndPaste(result)
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

                    // Update overlay - processing failed
                    overlayManager.updateState(isRecording: false, isProcessing: false)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
