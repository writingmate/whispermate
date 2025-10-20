import AVFoundation
import Foundation
internal import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    override init() {
        super.init()
        requestMicrophonePermission()
    }

    private func requestMicrophonePermission() {
        // Request microphone permission for macOS
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if !granted {
                    print("Microphone permission denied")
                }
            }
        case .denied, .restricted:
            print("Microphone permission denied or restricted")
        @unknown default:
            break
        }
    }

    func startRecording() {
        print("[AudioRecorder LOG] startRecording called - isRecording before: \(isRecording)")
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        recordingURL = tempDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.record()
            isRecording = true
            print("[AudioRecorder LOG] startRecording success - isRecording after: \(isRecording)")
        } catch {
            print("[AudioRecorder LOG] Failed to start recording: \(error)")
        }
    }

    func stopRecording() -> URL? {
        print("[AudioRecorder LOG] stopRecording called - isRecording before: \(isRecording)")
        audioRecorder?.stop()
        isRecording = false
        print("[AudioRecorder LOG] stopRecording completed - isRecording after: \(isRecording), recordingURL: \(String(describing: recordingURL))")
        return recordingURL
    }
}
