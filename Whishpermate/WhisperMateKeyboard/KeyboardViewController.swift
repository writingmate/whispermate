import UIKit
import AVFoundation
import Combine
import WhisperMateShared

class KeyboardViewController: UIInputViewController {

    // MARK: - Properties
    private var audioRecorder: AudioRecorder!
    private var openAIClient: OpenAIClient!
    private var recordButton: UIButton!
    private var recordingIndicator: UIView!
    private var statusLabel: UILabel!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAudioRecorder()
        setupOpenAIClient()
        setupUI()
    }

    // MARK: - Setup

    private func setupAudioRecorder() {
        audioRecorder = AudioRecorder()

        // Observe recording state
        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.updateRecordingState(isRecording)
            }
            .store(in: &cancellables)

        // Observe audio levels for visualization
        audioRecorder.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.updateAudioLevel(level)
            }
            .store(in: &cancellables)
    }

    private func setupOpenAIClient() {
        // Try keychain first, then fall back to Secrets.plist
        let apiKey = KeychainHelper.get(key: "custom_transcription_api_key") ?? SecretsLoader.transcriptionKey(for: .custom)
        let endpoint = SecretsLoader.customTranscriptionEndpoint() ?? "https://writingmate.ai/api/openai/v1/audio/transcriptions"
        let model = SecretsLoader.customTranscriptionModel() ?? "gpt-4o-transcribe"

        guard let apiKey = apiKey else {
            DebugLog.info("No API key found", context: "KeyboardViewController")
            return
        }

        let config = OpenAIClient.Configuration(
            transcriptionEndpoint: endpoint,
            transcriptionModel: model,
            chatCompletionEndpoint: "",
            chatCompletionModel: "",
            apiKey: apiKey
        )

        openAIClient = OpenAIClient(config: config)
    }

    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        // Create record button
        recordButton = UIButton(type: .system)
        recordButton.setTitle("🎙️ Tap to Record", for: .normal)
        recordButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        recordButton.backgroundColor = UIColor.systemBlue
        recordButton.setTitleColor(.white, for: .normal)
        recordButton.layer.cornerRadius = 8
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        view.addSubview(recordButton)

        // Create recording indicator
        recordingIndicator = UIView()
        recordingIndicator.backgroundColor = UIColor.systemRed
        recordingIndicator.layer.cornerRadius = 6
        recordingIndicator.translatesAutoresizingMaskIntoConstraints = false
        recordingIndicator.isHidden = true
        view.addSubview(recordingIndicator)

        // Create status label
        statusLabel = UILabel()
        statusLabel.text = ""
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textColor = UIColor.secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        // Layout constraints
        NSLayoutConstraint.activate([
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            recordButton.widthAnchor.constraint(equalToConstant: 200),
            recordButton.heightAnchor.constraint(equalToConstant: 44),

            recordingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordingIndicator.topAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: 12),
            recordingIndicator.widthAnchor.constraint(equalToConstant: 12),
            recordingIndicator.heightAnchor.constraint(equalToConstant: 12),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: recordingIndicator.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    // MARK: - Actions

    @objc private func recordButtonTapped() {
        if audioRecorder.isRecording {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        // Request microphone permission if needed
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.audioRecorder.startRecording()
                } else {
                    self?.showError("Microphone permission denied. Please enable it in Settings.")
                }
            }
        }
    }

    private func stopRecordingAndTranscribe() {
        guard let recordingURL = audioRecorder.stopRecording() else {
            showError("Failed to stop recording")
            return
        }

        statusLabel.text = "Transcribing..."

        Task {
            do {
                let transcription = try await openAIClient.transcribe(audioURL: recordingURL)

                // Insert transcription into text field
                await MainActor.run {
                    self.textDocumentProxy.insertText(transcription)
                    self.statusLabel.text = "✓ Transcribed"

                    // Save to history
                    let historyManager = HistoryManager()
                    let recording = Recording(transcription: transcription)
                    historyManager.addRecording(recording)

                    // Clear status after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.statusLabel.text = ""
                    }
                }

                // Delete audio file after successful transcription
                try? FileManager.default.removeItem(at: recordingURL)
            } catch {
                await MainActor.run {
                    self.showError("Transcription failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - UI Updates

    private func updateRecordingState(_ isRecording: Bool) {
        if isRecording {
            recordButton.setTitle("⏹️ Stop Recording", for: .normal)
            recordButton.backgroundColor = UIColor.systemRed
            recordingIndicator.isHidden = false
            statusLabel.text = "Recording..."
        } else {
            recordButton.setTitle("🎙️ Tap to Record", for: .normal)
            recordButton.backgroundColor = UIColor.systemBlue
            recordingIndicator.isHidden = true
        }
    }

    private func updateAudioLevel(_ level: Float) {
        // Animate recording indicator based on audio level
        if audioRecorder.isRecording {
            let scale = 1.0 + CGFloat(level) * 0.5
            UIView.animate(withDuration: 0.05) {
                self.recordingIndicator.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
        }
    }

    private func showError(_ message: String) {
        statusLabel.text = "❌ \(message)"
        statusLabel.textColor = UIColor.systemRed

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.statusLabel.text = ""
            self.statusLabel.textColor = UIColor.secondaryLabel
        }
    }

    // MARK: - Memory Management

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Keyboard extensions have strict memory limits (~40MB)
        // Clean up if needed
        DebugLog.info("Memory warning received", context: "KeyboardViewController")
    }
}
